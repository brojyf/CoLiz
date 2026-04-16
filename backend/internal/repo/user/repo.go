package user

import (
	"context"
	"database/sql"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
)

type Repo interface {
	GetUserByEmail(ctx context.Context, email string) (*domain.User, error)
	GetUserByID(ctx context.Context, userID string) (*domain.User, error)
	UpdateUsername(ctx context.Context, userID, username string) error
	UpdateAvatarMeta(ctx context.Context, userID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error
}

type repoStore struct {
	db *mySQLStore
}

func NewRepo(db *sql.DB) Repo {
	return &repoStore{
		db: newMySQLStore(db),
	}
}

func (r *repoStore) GetUserByID(ctx context.Context, userID string) (*domain.User, error) {
	return r.db.getUserByID(ctx, userID)
}

func (r *repoStore) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	return r.db.getUserByEmail(ctx, email)
}

func (r *repoStore) UpdateAvatarMeta(ctx context.Context, userID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error {
	return r.db.updateAvatarMeta(ctx, userID, currentVersion, nextVersion, updatedAt)
}

func (r *repoStore) UpdateUsername(ctx context.Context, userID, username string) error {
	return r.db.updateUsername(ctx, userID, username)
}
