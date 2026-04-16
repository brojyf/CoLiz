package expense

import (
	"context"
	"errors"

	"github.com/brojyf/CoLiz/internal/domain"
	txinfra "github.com/brojyf/CoLiz/internal/infra/tx"
	"github.com/brojyf/CoLiz/internal/repo"
	expenserepo "github.com/brojyf/CoLiz/internal/repo/expense"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

type Service interface {
	GetOverview(ctx context.Context, uid string) ([]domain.Group, []string, []string, error)
	GetDetail(ctx context.Context, uid, expenseID string) (*domain.Expense, error)
	Create(ctx context.Context, ex *domain.Expense, uid string) (*domain.Expense, error)
	GetBalance(ctx context.Context, uid, groupID string) (*domain.Group, string, string, error)
	GetTransactionPlan(ctx context.Context, uid, groupID string) (*domain.GroupTransactionPlan, error)
	ApplyTransactionPlan(ctx context.Context, uid, groupID string) (*domain.GroupTransactionPlan, error)
	GetGroup(ctx context.Context, uid, groupID string) ([]domain.Expense, []string, []string, []domain.User, error)
	Update(ctx context.Context, uid, expenseID string, ex *domain.Expense) (*domain.Expense, error)
	Delete(ctx context.Context, uid, expenseID string) error
}

type service struct {
	repo expenserepo.Repo
	tx   *txinfra.Transactor
}

func NewService(r expenserepo.Repo, t *txinfra.Transactor) Service {
	return &service{repo: r, tx: t}
}

func (s *service) GetBalance(ctx context.Context, uid, groupID string) (*domain.Group, string, string, error) {
	if err := validateUUIDv7(uid); err != nil {
		return nil, "", "", svc.ErrInvalidInput
	}
	if err := validateUUIDv7(groupID); err != nil {
		return nil, "", "", svc.ErrInvalidInput
	}

	group, lent, borrow, err := s.repo.GetGroupExpense(ctx, uid, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, "", "", err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, "", "", svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, "", "", svc.ErrNotFound
		default:
			logx.Error(ctx, "expense.getBalance", err)
			return nil, "", "", svc.ErrInternal
		}
	}

	return group, lent, borrow, nil
}

func (s *service) GetGroup(ctx context.Context, uid, groupID string) ([]domain.Expense, []string, []string, []domain.User, error) {
	if err := validateUUIDv7(uid); err != nil {
		return nil, nil, nil, nil, svc.ErrInvalidInput
	}
	if err := validateUUIDv7(groupID); err != nil {
		return nil, nil, nil, nil, svc.ErrInvalidInput
	}

	expenses, lentAmounts, borrowAmounts, users, err := s.repo.GetGroupExpenseHistory(ctx, groupID, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, nil, nil, err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, nil, nil, nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, nil, nil, nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "expense.getGroup", err)
			return nil, nil, nil, nil, svc.ErrInternal
		}
	}

	return expenses, lentAmounts, borrowAmounts, users, nil
}
