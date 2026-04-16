package expense

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/expol"
	"github.com/brojyf/CoLiz/internal/repo"
	expenserepo "github.com/brojyf/CoLiz/internal/repo/expense"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
)

func (s *service) Create(ctx context.Context, ex *domain.Expense, uid string) (*domain.Expense, error) {
	if ex == nil {
		logx.Info(ctx, "expense.create.invalid", "expense payload is nil")
		return nil, svc.ErrInvalidInput
	}
	amountCents, _, err := parseAmountToCents(ex.Amount)
	if err != nil {
		logx.Info(ctx, "expense.create.invalid_amount", fmt.Sprintf("amount=%q err=%v", ex.Amount, err))
		return nil, svc.ErrInvalidInput
	}
	participantIDs := participantIDs(ex.Participants)
	isTransaction := ex.Category == expol.CategoryTransaction

	expense, err := buildCreateExpense(uid, ex, isTransaction)
	if err != nil {
		logx.Error(ctx, "expense.create.id", err)
		return nil, svc.ErrInternal
	}

	detail, err := s.createAndLoadDetail(ctx, uid, expense, ex.Participants, amountCents, participantIDs)
	if err != nil {
		return nil, err
	}
	detail.Participants = reorderParticipants(detail.Participants, participantIDs)
	return detail, nil
}

func (s *service) Delete(ctx context.Context, uid, expenseID string) error {
	err := s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		detail, err := store.GetDetail(ctx, expenseID, uid)
		if err != nil {
			return err
		}
		if err := store.LockGroup(ctx, uid, detail.GroupID); err != nil {
			return err
		}
		return store.Delete(ctx, expenseID, uid)
	})
	if err != nil {
		return mapTxError(ctx, "expense.delete.tx", err)
	}

	return nil
}

func (s *service) Update(ctx context.Context, uid, expenseID string, ex *domain.Expense) (*domain.Expense, error) {
	if ex == nil {
		logx.Info(ctx, "expense.update.invalid", "expense payload is nil")
		return nil, svc.ErrInvalidInput
	}

	existing, err := s.getExpenseDetail(ctx, uid, expenseID)
	if err != nil {
		return nil, err
	}

	ex.GroupID = existing.GroupID
	amountCents, _, err := parseAmountToCents(ex.Amount)
	if err != nil {
		logx.Info(ctx, "expense.update.invalid_amount", fmt.Sprintf("expense_id=%q amount=%q err=%v", expenseID, ex.Amount, err))
		return nil, svc.ErrInvalidInput
	}
	participantIDs := participantIDs(ex.Participants)
	isTransaction := ex.Category == expol.CategoryTransaction

	detail, err := s.updateAndLoadDetail(ctx, uid, expenseID, ex, amountCents, participantIDs, isTransaction)
	if err != nil {
		return nil, err
	}
	detail.Participants = reorderParticipants(detail.Participants, participantIDs)
	return detail, nil
}

func (s *service) getExpenseDetail(ctx context.Context, uid, expenseID string) (*domain.Expense, error) {
	detail, err := s.repo.GetDetail(ctx, expenseID, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "expense.update.detail", err)
			return nil, svc.ErrInternal
		}
	}
	return detail, nil
}

func (s *service) validateParticipantsInGroup(
	ctx context.Context,
	groupID, uid, paidBy string,
	participantIDs []string,
	isTransaction bool,
	errorLogKey string,
) error {
	return s.validateParticipantsInGroupWithRepo(ctx, s.repo, groupID, uid, paidBy, participantIDs, isTransaction, errorLogKey)
}

func (s *service) validateParticipantsInGroupWithRepo(
	ctx context.Context,
	store expenserepo.Repo,
	groupID, uid, paidBy string,
	participantIDs []string,
	isTransaction bool,
	errorLogKey string,
) error {
	memberIDs, err := store.GetGroupMemberIDs(ctx, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrNotFound):
			return svc.ErrNotFound
		default:
			logx.Error(ctx, errorLogKey, err)
			return svc.ErrInternal
		}
	}

	if _, ok := memberIDs[uid]; !ok {
		logx.Info(ctx, errorLogKey, fmt.Sprintf("requester_not_in_group uid=%q group_id=%q", uid, groupID))
		return svc.ErrUnauthorized
	}
	if _, ok := memberIDs[paidBy]; !ok {
		logx.Info(ctx, errorLogKey, fmt.Sprintf("payer_not_in_group paid_by=%q group_id=%q", paidBy, groupID))
		return svc.ErrInvalidInput
	}

	seen := make(map[string]struct{}, len(participantIDs))
	for _, participantID := range participantIDs {
		if _, ok := seen[participantID]; ok {
			logx.Info(ctx, errorLogKey, fmt.Sprintf("duplicate_participant participant_id=%q group_id=%q", participantID, groupID))
			return svc.ErrInvalidInput
		}
		seen[participantID] = struct{}{}
		if _, ok := memberIDs[participantID]; !ok {
			logx.Info(ctx, errorLogKey, fmt.Sprintf("participant_not_in_group participant_id=%q group_id=%q", participantID, groupID))
			return svc.ErrInvalidInput
		}
		if isTransaction && participantID == paidBy {
			logx.Info(ctx, errorLogKey, fmt.Sprintf("transaction_participant_matches_payer user_id=%q group_id=%q", participantID, groupID))
			return svc.ErrInvalidInput
		}
	}
	return nil
}

func buildCreateExpense(uid string, ex *domain.Expense, isTransaction bool) (*domain.Expense, error) {
	expenseID, err := uuidx.NewV7()
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	occurredAt := now
	if ex.OccurredAt != nil {
		occurredAt = ex.OccurredAt.UTC()
	}

	return &domain.Expense{
		ID:            expenseID,
		GroupID:       ex.GroupID,
		Name:          ex.Name,
		Category:      ex.Category,
		Amount:        ex.Amount,
		PaidBy:        ex.PaidBy,
		SplitMethod:   ex.SplitMethod,
		Note:          ex.Note,
		CreatedBy:     uid,
		OccurredAt:    &occurredAt,
		CreatedAt:     now,
		UpdatedAt:     now,
		IsTransaction: isTransaction,
	}, nil
}

func buildUpdatedExpense(existing *domain.Expense, ex *domain.Expense, isTransaction bool) *domain.Expense {
	occurredAt := time.Now().UTC()
	if existing.OccurredAt != nil {
		occurredAt = existing.OccurredAt.UTC()
	}
	if ex.OccurredAt != nil {
		occurredAt = ex.OccurredAt.UTC()
	}

	return &domain.Expense{
		ID:            existing.ID,
		GroupID:       existing.GroupID,
		Name:          ex.Name,
		Category:      ex.Category,
		Amount:        ex.Amount,
		PaidBy:        ex.PaidBy,
		SplitMethod:   ex.SplitMethod,
		Note:          ex.Note,
		CreatedBy:     existing.CreatedBy,
		OccurredAt:    &occurredAt,
		CreatedAt:     existing.CreatedAt,
		UpdatedAt:     time.Now().UTC(),
		IsTransaction: isTransaction,
	}
}

func (s *service) createAndLoadDetail(
	ctx context.Context,
	uid string,
	expense *domain.Expense,
	participants []domain.Participant,
	amountCents int64,
	participantIDs []string,
) (*domain.Expense, error) {
	var detail *domain.Expense
	err := s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		if err := store.LockGroup(ctx, uid, expense.GroupID); err != nil {
			return err
		}
		if err := s.validateParticipantsInGroupWithRepo(
			ctx,
			store,
			expense.GroupID,
			uid,
			expense.PaidBy,
			participantIDs,
			expense.IsTransaction,
			"expense.create.members",
		); err != nil {
			return err
		}
		splits, err := buildSplits(expense.ID, expense.GroupID, expense.SplitMethod, participants, amountCents)
		if err != nil {
			logx.Info(ctx, "expense.create.invalid_splits", fmt.Sprintf("split_method=%q err=%v", expense.SplitMethod, err))
			return svc.ErrInvalidInput
		}
		if err := store.Create(ctx, expense, splits); err != nil {
			return err
		}
		var innerErr error
		detail, innerErr = store.GetDetail(ctx, expense.ID, uid)
		return innerErr
	})
	if err != nil {
		return nil, mapTxError(ctx, "expense.create.tx", err)
	}
	return detail, nil
}

func (s *service) updateAndLoadDetail(
	ctx context.Context,
	uid, expenseID string,
	ex *domain.Expense,
	amountCents int64,
	participantIDs []string,
	isTransaction bool,
) (*domain.Expense, error) {
	var detail *domain.Expense
	err := s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		existing, err := store.GetDetail(ctx, expenseID, uid)
		if err != nil {
			return err
		}
		if err := store.LockGroup(ctx, uid, existing.GroupID); err != nil {
			return err
		}
		existing, err = store.GetDetail(ctx, expenseID, uid)
		if err != nil {
			return err
		}
		if err := s.validateParticipantsInGroupWithRepo(
			ctx,
			store,
			existing.GroupID,
			uid,
			ex.PaidBy,
			participantIDs,
			isTransaction,
			"expense.update.members",
		); err != nil {
			return err
		}
		expense := buildUpdatedExpense(existing, ex, isTransaction)
		splits, err := buildSplits(existing.ID, existing.GroupID, expense.SplitMethod, ex.Participants, amountCents)
		if err != nil {
			logx.Info(ctx, "expense.update.invalid_splits", fmt.Sprintf("expense_id=%q split_method=%q err=%v", expenseID, ex.SplitMethod, err))
			return svc.ErrInvalidInput
		}
		if err := store.Update(ctx, uid, expense, splits); err != nil {
			return err
		}
		var innerErr error
		detail, innerErr = store.GetDetail(ctx, expense.ID, uid)
		return innerErr
	})
	if err != nil {
		return nil, mapTxError(ctx, "expense.update.tx", err)
	}
	return detail, nil
}

func mapTxError(ctx context.Context, logKey string, err error) error {
	switch {
	case ctxx.IsCtxError(err):
		return err
	case errors.Is(err, repo.ErrUnauthorized):
		return svc.ErrUnauthorized
	case errors.Is(err, repo.ErrNotFound):
		return svc.ErrNotFound
	case errors.Is(err, repo.ErrConflict):
		return svc.ErrConflict
	default:
		logx.Error(ctx, logKey, err)
		return svc.ErrInternal
	}
}

// Helper methods
func participantIDs(participants []domain.Participant) []string {
	ids := make([]string, 0, len(participants))
	for _, participant := range participants {
		ids = append(ids, participant.UserID)
	}
	return ids
}

func parseAmountToCents(raw string) (int64, string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return 0, "", errors.New("amount is required")
	}
	if strings.HasPrefix(value, "-") || strings.HasPrefix(value, "+") {
		return 0, "", errors.New("amount must be unsigned")
	}

	parts := strings.Split(value, ".")
	if len(parts) > 2 {
		return 0, "", errors.New("amount has too many decimal separators")
	}

	intPart := parts[0]
	if intPart == "" {
		return 0, "", errors.New("amount integer part is required")
	}
	for _, ch := range intPart {
		if ch < '0' || ch > '9' {
			return 0, "", errors.New("amount integer part is invalid")
		}
	}
	if len(intPart) > 8 {
		return 0, "", errors.New("amount exceeds maximum")
	}

	fracPart := ""
	if len(parts) == 2 {
		fracPart = parts[1]
		if fracPart == "" || len(fracPart) > 2 {
			return 0, "", errors.New("amount decimal part is invalid")
		}
		for _, ch := range fracPart {
			if ch < '0' || ch > '9' {
				return 0, "", errors.New("amount decimal part is invalid")
			}
		}
	}

	intValue, err := strconv.ParseInt(intPart, 10, 64)
	if err != nil {
		return 0, "", err
	}
	if intValue > 99999999 {
		return 0, "", errors.New("amount exceeds maximum")
	}

	for len(fracPart) < 2 {
		fracPart += "0"
	}
	fracValue, err := strconv.ParseInt(fracPart, 10, 64)
	if err != nil {
		return 0, "", err
	}

	cents := intValue*100 + fracValue
	if cents <= 0 {
		return 0, "", errors.New("amount must be positive")
	}
	if cents > 9999999999 {
		return 0, "", errors.New("amount exceeds maximum")
	}

	return cents, formatCents(cents), nil
}

func buildEqualSplits(expenseID, groupID string, participantIDs []string, totalCents int64) []domain.ExpenseSplit {
	count := int64(len(participantIDs))
	base := totalCents / count
	remainder := totalCents % count

	splits := make([]domain.ExpenseSplit, 0, len(participantIDs))
	for idx, participantID := range participantIDs {
		share := base
		if int64(idx) < remainder {
			share++
		}
		splits = append(splits, domain.ExpenseSplit{
			ExpenseID: expenseID,
			GroupID:   groupID,
			UserID:    participantID,
			Amount:    formatCents(share),
		})
	}
	return splits
}

func buildSplits(
	expenseID, groupID, splitMethod string,
	participants []domain.Participant,
	totalCents int64,
) ([]domain.ExpenseSplit, error) {
	switch splitMethod {
	case expol.SplitEqual:
		participantIDs := make([]string, 0, len(participants))
		for _, participant := range participants {
			if hasValue(participant.FixedAmount) {
				return nil, errors.New("equal split does not accept fixed amount")
			}
			participantIDs = append(participantIDs, participant.UserID)
		}
		return buildEqualSplits(expenseID, groupID, participantIDs, totalCents), nil
	case expol.SplitFixed:
		return buildFixedSplits(expenseID, groupID, participants, totalCents)
	default:
		return nil, errors.New("unsupported split method")
	}
}

func buildFixedSplits(
	expenseID, groupID string,
	participants []domain.Participant,
	totalCents int64,
) ([]domain.ExpenseSplit, error) {
	splits := make([]domain.ExpenseSplit, 0, len(participants))
	var sumCents int64

	for _, participant := range participants {
		if !hasValue(participant.FixedAmount) {
			return nil, errors.New("fixed split requires fixed amount only")
		}
		fixedCents, fixedAmount, err := parseAmountToCents(*participant.FixedAmount)
		if err != nil {
			return nil, err
		}
		sumCents += fixedCents
		fixed := fixedAmount
		splits = append(splits, domain.ExpenseSplit{
			ExpenseID:   expenseID,
			GroupID:     groupID,
			UserID:      participant.UserID,
			Amount:      fixedAmount,
			FixedAmount: &fixed,
		})
	}

	if sumCents != totalCents {
		return nil, errors.New("fixed amount total mismatch")
	}

	return splits, nil
}

func reorderParticipants(participants []domain.Participant, requestOrder []string) []domain.Participant {
	byUserID := make(map[string]domain.Participant, len(participants))
	for _, participant := range participants {
		byUserID[participant.UserID] = participant
	}

	ordered := make([]domain.Participant, 0, len(participants))
	used := make(map[string]struct{}, len(participants))
	for _, userID := range requestOrder {
		participant, ok := byUserID[userID]
		if !ok {
			continue
		}
		ordered = append(ordered, participant)
		used[userID] = struct{}{}
	}
	for _, participant := range participants {
		if _, ok := used[participant.UserID]; ok {
			continue
		}
		ordered = append(ordered, participant)
	}
	return ordered
}

func formatCents(cents int64) string {
	return fmt.Sprintf("%d.%02d", cents/100, cents%100)
}

func hasValue(value *string) bool {
	return value != nil && strings.TrimSpace(*value) != ""
}
