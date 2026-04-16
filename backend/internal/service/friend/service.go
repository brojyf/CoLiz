package friend

import (
	"context"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	txinfra "github.com/brojyf/CoLiz/internal/infra/tx"
	"github.com/brojyf/CoLiz/internal/repo/friend"
)

type Service interface {
	GetFriends(ctx context.Context, uid string) ([]domain.User, error)
	GetFriend(ctx context.Context, userID, friendID string) (*domain.User, error)
	Delete(ctx context.Context, userID, friendID string) error
	SendRequest(ctx context.Context, req *domain.FriendRequest) error
	GetRequests(ctx context.Context, userID string) ([]domain.FriendRequest, error)
	Accept(ctx context.Context, requestID, userID string) error
	Decline(ctx context.Context, requestID, userID string) error
	CancelRequest(ctx context.Context, requestID, userID string) error
}

type Config struct {
	RequestTTL time.Duration
}

type service struct {
	cfg  Config
	repo friend.Repo
	tx   *txinfra.Transactor
}

func NewService(c Config, r friend.Repo, tx *txinfra.Transactor) Service {
	return &service{cfg: c, repo: r, tx: tx}
}
