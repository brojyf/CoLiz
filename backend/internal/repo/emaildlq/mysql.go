package emaildlq

import (
	"context"

	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

type mySQLStore struct {
	db repo.DBTX
}

func newMySQLStore(db repo.DBTX) *mySQLStore {
	return &mySQLStore{db: db}
}

func (d *mySQLStore) saveFailedOTPEmail(ctx context.Context, codeID, email, scene string, attempts int, lastErr string) error {
	const query = `
		INSERT INTO email_dlq (
		  code_id, email, scene, attempts, status, last_error
		) VALUES (?, ?, ?, ?, 'failed', ?)
	`

	_, err := d.db.ExecContext(
		ctx,
		query,
		codeID,
		email,
		scene,
		attempts,
		lastErr,
	)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	return nil
}
