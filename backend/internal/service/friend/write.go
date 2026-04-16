package friend

import (
	"context"
	"database/sql"
	"errors"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

func (s *service) Delete(ctx context.Context, userID, friendID string) error {
	err := s.repo.Delete(ctx, userID, friendID)
	if err != nil {
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
			logx.Error(ctx, "friends.delete", err)
			return svc.ErrInternal
		}
	}

	return nil
}

func (s *service) SendRequest(ctx context.Context, req *domain.FriendRequest) error {
	friendReq, err := domain.NewFriendRequest(
		domain.WithNewFriendRequestID(),
		domain.WithFromUser(req.From),
		domain.WithToUser(req.To),
		domain.WithFriendRequestMessage(req.Msg),
		domain.WithFriendRequestTTL(s.cfg.RequestTTL),
	)
	if err != nil {
		return svc.ErrInternal
	}

	err = s.repo.SendRequest(ctx, friendReq)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrInvalidInput):
			return svc.ErrInvalidInput
		case errors.Is(err, repo.ErrNotFound):
			return svc.ErrNotFound
		case errors.Is(err, repo.ErrConflict):
			return svc.ErrConflict
		default:
			logx.Error(ctx, "friends.request", err)
			return svc.ErrInternal
		}
	}

	return nil
}

func (s *service) Accept(ctx context.Context, requestID, userID string) error {
	err := s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		return store.AcceptRequest(ctx, requestID, userID)
	})

	if err != nil {
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
			logx.Error(ctx, "friends.accept", err)
			return svc.ErrInternal
		}
	}

	return nil
}

func (s *service) Decline(ctx context.Context, requestID, userID string) error {
	err := s.repo.DeclineRequest(ctx, requestID, userID)
	if err != nil {
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
			logx.Error(ctx, "friends.reject", err)
			return svc.ErrInternal
		}
	}

	return nil
}

func (s *service) CancelRequest(ctx context.Context, requestID, userID string) error {
	err := s.repo.CancelRequest(ctx, requestID, userID)
	if err != nil {
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
			logx.Error(ctx, "friends.cancel", err)
			return svc.ErrInternal
		}
	}

	return nil
}
