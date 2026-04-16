package expense

import (
	"context"
	"errors"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

func (s *service) GetOverview(ctx context.Context, uid string) ([]domain.Group, []string, []string, error) {
	groups, lent, borrow, err := s.repo.GetOverview(ctx, uid)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return nil, nil, nil, err
		}
		logx.Error(ctx, "expense.get", err)
		return nil, nil, nil, svc.ErrInternal
	}
	return groups, lent, borrow, nil
}

func (s *service) GetDetail(ctx context.Context, uid, expenseID string) (*domain.Expense, error) {
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
			logx.Error(ctx, "expense.getDetail", err)
			return nil, svc.ErrInternal
		}
	}

	return detail, nil
}
