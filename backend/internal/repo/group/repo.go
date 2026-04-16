package group

import (
	"context"
	"database/sql"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
)

type Repo interface {
	BeginTx(tx *sql.Tx) Repo
	Create(ctx context.Context, p *domain.Group) (*domain.Group, error)
	Get(ctx context.Context, uid string) ([]domain.Group, error)
	GetDetail(ctx context.Context, groupID, userID string) (*domain.Group, error)
	GetMembers(ctx context.Context, groupID string) ([]domain.User, error)

	GetByID(ctx context.Context, groupID string) (*domain.Group, error)
	Invite(ctx context.Context, groupID, inviterID, inviteeID string) error
	UpdateName(ctx context.Context, groupID, userID, name string) error
	CanLeave(ctx context.Context, groupID, userID string) (bool, error)
	Leave(ctx context.Context, groupID, userID string) error
	CanDelete(ctx context.Context, groupID string) (bool, error)
	Delete(ctx context.Context, groupID, ownerID string) error
	UpdateAvatarMeta(ctx context.Context, groupID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error
}

type repoStore struct {
	db repo.DBTX
}

func NewRepo(db repo.DBTX) Repo {
	return repoStore{db: db}
}

func (s repoStore) BeginTx(tx *sql.Tx) Repo {
	return repoStore{db: tx}
}
