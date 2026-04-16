package tx

import (
	"context"
	"database/sql"
)

type Transactor struct {
	db *sql.DB
}

func NewTransactor(db *sql.DB) *Transactor {
	return &Transactor{db: db}
}

func (t *Transactor) WithinTx(
	ctx context.Context,
	fn func(ctx context.Context, tx *sql.Tx) error,
) error {
	tx, err := t.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	if err := fn(ctx, tx); err != nil {
		return err
	}
	return tx.Commit()
}
