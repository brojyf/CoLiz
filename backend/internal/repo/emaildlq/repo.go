package emaildlq

import (
	"context"
	"database/sql"
)

type Repo interface {
	SaveFailedOTPEmail(ctx context.Context, codeID, email, scene string, attempts int, lastErr string) error
}

type repoStore struct {
	db *mySQLStore
}

func NewRepo(db *sql.DB) Repo {
	return &repoStore{
		db: newMySQLStore(db),
	}
}

func (r *repoStore) SaveFailedOTPEmail(ctx context.Context, codeID, email, scene string, attempts int, lastErr string) error {
	return r.db.saveFailedOTPEmail(ctx, codeID, email, scene, attempts, lastErr)
}
