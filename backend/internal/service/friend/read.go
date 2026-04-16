package friend

import (
	"context"
	"errors"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

func (s *service) GetFriends(ctx context.Context, uid string) ([]domain.User, error) {
	friends, err := s.repo.GetFriends(ctx, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "friends.getFriends", err)
			return nil, svc.ErrInternal
		}
	}
	return friends, nil
}

func (s *service) GetFriend(ctx context.Context, userID, friendID string) (*domain.User, error) {
	friend, err := s.repo.GetFriend(ctx, userID, friendID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "friends.getFriend", err)
			return nil, svc.ErrInternal
		}
	}

	return friend, nil
}

func (s *service) GetRequests(ctx context.Context, userID string) ([]domain.FriendRequest, error) {
	reqs, err := s.repo.GetRequests(ctx, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			logx.Error(ctx, "friends.getRequests", err)
			return nil, svc.ErrInternal
		}
	}
	return reqs, nil
}
