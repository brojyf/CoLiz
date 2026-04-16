package friend

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
)

type Repo interface {
	BeginTx(tx *sql.Tx) Repo
	GetFriends(ctx context.Context, userID string) ([]domain.User, error)
	GetFriend(ctx context.Context, userID, friendID string) (*domain.User, error)
	Delete(ctx context.Context, userID, friendID string) error
	SendRequest(ctx context.Context, p *domain.FriendRequest) error
	GetRequests(ctx context.Context, userID string) ([]domain.FriendRequest, error)
	AcceptRequest(ctx context.Context, requestID, userID string) error
	DeclineRequest(ctx context.Context, requestID, userID string) error
	CancelRequest(ctx context.Context, requestID, userID string) error
}

type repoStore struct {
	db repo.DBTX
}

func NewRepo(db repo.DBTX) Repo {
	return &repoStore{db: db}
}

func (s *repoStore) BeginTx(tx *sql.Tx) Repo {
	return &repoStore{db: tx}
}
