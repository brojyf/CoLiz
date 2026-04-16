package device

import (
	"context"
	"database/sql"
	"strings"
	"time"
)

type DeviceToken struct {
	UserID    string
	Token     string
	UpdatedAt time.Time
}

type Repo interface {
	Upsert(ctx context.Context, userID, token string) error
	GetByUserIDs(ctx context.Context, userIDs []string) ([]DeviceToken, error)
	Delete(ctx context.Context, userID string) error
}

type repo struct {
	db *sql.DB
}

func NewRepo(db *sql.DB) Repo {
	return &repo{db: db}
}

func (r *repo) Upsert(ctx context.Context, userID, token string) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO device_tokens (user_id, token, updated_at)
		 VALUES (?, ?, NOW())
		 ON DUPLICATE KEY UPDATE token = VALUES(token), updated_at = NOW()`,
		userID, token,
	)
	return err
}

func (r *repo) GetByUserIDs(ctx context.Context, userIDs []string) ([]DeviceToken, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}
	placeholders := strings.Repeat("?,", len(userIDs))
	placeholders = placeholders[:len(placeholders)-1]
	args := make([]any, len(userIDs))
	for i, id := range userIDs {
		args[i] = id
	}
	rows, err := r.db.QueryContext(ctx,
		`SELECT user_id, token, updated_at FROM device_tokens WHERE user_id IN (`+placeholders+`)`,
		args...,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []DeviceToken
	for rows.Next() {
		var dt DeviceToken
		if err := rows.Scan(&dt.UserID, &dt.Token, &dt.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, dt)
	}
	return out, rows.Err()
}

func (r *repo) Delete(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM device_tokens WHERE user_id = ?`, userID)
	return err
}