package expense

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/expol"
	"github.com/brojyf/CoLiz/internal/repo"
	expenserepo "github.com/brojyf/CoLiz/internal/repo/expense"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

func (s *service) GetTransactionPlan(ctx context.Context, uid, groupID string) (*domain.GroupTransactionPlan, error) {
	if err := validateUUIDv7(uid); err != nil {
		return nil, svc.ErrInvalidInput
	}
	if err := validateUUIDv7(groupID); err != nil {
		return nil, svc.ErrInvalidInput
	}

	plan, err := s.transactionPlanWithRepo(ctx, s.repo, uid, groupID)
	if err != nil {
		return nil, err
	}

	return plan, nil
}

func (s *service) ApplyTransactionPlan(ctx context.Context, uid, groupID string) (*domain.GroupTransactionPlan, error) {
	if err := validateUUIDv7(uid); err != nil {
		return nil, svc.ErrInvalidInput
	}
	if err := validateUUIDv7(groupID); err != nil {
		return nil, svc.ErrInvalidInput
	}

	var plan *domain.GroupTransactionPlan
	err := s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		if lockErr := store.LockGroup(ctx, uid, groupID); lockErr != nil {
			return lockErr
		}

		var innerErr error
		plan, innerErr = s.transactionPlanWithRepo(ctx, store, uid, groupID)
		if innerErr != nil {
			return innerErr
		}

		for _, transfer := range plan.Transfers {
			expense, splits, buildErr := buildTransactionExpense(uid, groupID, transfer)
			if buildErr != nil {
				logx.Error(ctx, "expense.transactionPlan.build", buildErr)
				return svc.ErrInternal
			}
			if createErr := store.Create(ctx, expense, splits); createErr != nil {
				return createErr
			}
		}

		return nil
	})
	if err != nil {
		return nil, mapTransactionPlanError(ctx, err)
	}

	return plan, nil
}

func (s *service) transactionPlanWithRepo(
	ctx context.Context,
	store expenserepo.Repo,
	uid, groupID string,
) (*domain.GroupTransactionPlan, error) {
	group, balances, err := store.GetGroupMemberBalances(ctx, uid, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "expense.transactionPlan.members", err)
			return nil, svc.ErrInternal
		}
	}

	transfers, err := buildTransactionTransfers(balances)
	if err != nil {
		logx.Error(ctx, "expense.transactionPlan.build", err)
		return nil, svc.ErrInternal
	}

	return &domain.GroupTransactionPlan{
		Group:     *group,
		Transfers: transfers,
	}, nil
}

type transferNode struct {
	User  domain.User
	Cents int64
}

func buildTransactionTransfers(balances []domain.MemberNetBalance) ([]domain.TransactionTransfer, error) {
	creditors := make([]transferNode, 0)
	debtors := make([]transferNode, 0)

	for _, balance := range balances {
		raw := strings.TrimSpace(balance.NetAmount)
		if raw == "" || raw == "0" || raw == "0.0" || raw == "0.00" || raw == "-0" || raw == "-0.0" || raw == "-0.00" {
			continue
		}

		cents, _, err := parseAmountToCents(raw)
		if err == nil {
			creditors = append(creditors, transferNode{User: balance.User, Cents: cents})
			continue
		}

		if len(raw) > 0 && raw[0] == '-' {
			cents, _, err = parseAmountToCents(raw[1:])
			if err != nil {
				return nil, err
			}
			debtors = append(debtors, transferNode{User: balance.User, Cents: cents})
		}
	}

	transfers := make([]domain.TransactionTransfer, 0)
	debtorIdx := 0
	creditorIdx := 0
	for debtorIdx < len(debtors) && creditorIdx < len(creditors) {
		amount := debtors[debtorIdx].Cents
		if creditors[creditorIdx].Cents < amount {
			amount = creditors[creditorIdx].Cents
		}

		transfers = append(transfers, domain.TransactionTransfer{
			FromUser: debtors[debtorIdx].User,
			ToUser:   creditors[creditorIdx].User,
			Amount:   formatCents(amount),
		})

		debtors[debtorIdx].Cents -= amount
		creditors[creditorIdx].Cents -= amount

		if debtors[debtorIdx].Cents == 0 {
			debtorIdx++
		}
		if creditors[creditorIdx].Cents == 0 {
			creditorIdx++
		}
	}

	if debtorIdx != len(debtors) || creditorIdx != len(creditors) {
		return nil, errors.New("unable to fully resolve group balances")
	}

	return transfers, nil
}

func buildTransactionExpense(
	createdBy, groupID string,
	transfer domain.TransactionTransfer,
) (*domain.Expense, []domain.ExpenseSplit, error) {
	amount := transfer.Amount
	base := &domain.Expense{
		GroupID:     groupID,
		Name:        expol.TransactionExpenseName,
		Category:    expol.CategoryTransaction,
		Amount:      amount,
		PaidBy:      transfer.FromUser.ID,
		SplitMethod: expol.SplitFixed,
		Participants: []domain.Participant{
			{
				UserID:      transfer.ToUser.ID,
				FixedAmount: &amount,
			},
		},
	}

	expense, err := buildCreateExpense(createdBy, base, true)
	if err != nil {
		return nil, nil, err
	}

	amountCents, _, err := parseAmountToCents(amount)
	if err != nil {
		return nil, nil, err
	}

	splits, err := buildSplits(expense.ID, groupID, expense.SplitMethod, base.Participants, amountCents)
	if err != nil {
		return nil, nil, err
	}

	return expense, splits, nil
}

func mapTransactionPlanError(ctx context.Context, err error) error {
	switch {
	case ctxx.IsCtxError(err):
		return err
	case errors.Is(err, svc.ErrInvalidInput),
		errors.Is(err, svc.ErrUnauthorized),
		errors.Is(err, svc.ErrNotFound),
		errors.Is(err, svc.ErrConflict),
		errors.Is(err, svc.ErrInternal):
		return err
	case errors.Is(err, repo.ErrUnauthorized),
		errors.Is(err, repo.ErrNotFound),
		errors.Is(err, repo.ErrConflict):
		return mapTxError(ctx, "expense.transactionPlan.tx", err)
	default:
		logx.Error(ctx, "expense.transactionPlan.tx", err)
		return svc.ErrInternal
	}
}
