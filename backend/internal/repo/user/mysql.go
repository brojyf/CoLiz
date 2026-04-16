package user

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

type mySQLStore struct {
	db repo.DBTX
}

func newMySQLStore(db repo.DBTX) *mySQLStore {
	return &mySQLStore{db: db}
}

func (d *mySQLStore) getUserByID(ctx context.Context, userID string) (*domain.User, error) {
	const query = `
		SELECT user_id, username, email, avatar_version, avatar_updated_at
		FROM users
		WHERE user_id = ?
	`

	var (
		uid           string
		username      string
		email         string
		avatarVersion uint32
		avatarUpdated sql.NullTime
	)

	err := d.db.QueryRowContext(ctx, query, userID).Scan(
		&uid,
		&username,
		&email,
		&avatarVersion,
		&avatarUpdated,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, sql.ErrNoRows):
			return nil, repo.NewError(repo.ErrNotFound, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	opts := []domain.UserOption{
		domain.WithUserID(uid),
		domain.WithUsername(username),
		domain.WithEmail(email),
		domain.WithAvatarVersion(avatarVersion),
	}
	if avatarUpdated.Valid {
		opts = append(opts, domain.WithAvatarUpdatedAt(avatarUpdated.Time))
	}

	user := domain.NewUser(opts...)
	return user, nil
}

func (d *mySQLStore) updateAvatarMeta(ctx context.Context, userID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error {
	const query = `
		UPDATE users
		SET avatar_version = ?, avatar_updated_at = ?
		WHERE user_id = ? AND avatar_version = ?
	`

	res, err := d.db.ExecContext(ctx, query, nextVersion, updatedAt, userID, currentVersion)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	affected, err := res.RowsAffected()
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}
	if affected == 0 {
		var exists int
		err := d.db.QueryRowContext(ctx, "SELECT 1 FROM users WHERE user_id = ?", userID).Scan(&exists)
		switch {
		case err == nil:
			return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, sql.ErrNoRows):
			return repo.NewError(repo.ErrNotFound, err)
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	return nil
}

func (d *mySQLStore) updateUsername(ctx context.Context, userID, username string) error {
	const query = `
		UPDATE users
		SET username = ?
		WHERE user_id = ?
	`

	res, err := d.db.ExecContext(ctx, query, username, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	affected, err := res.RowsAffected()
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}
	if affected == 0 {
		return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	}

	return nil
}

func (d *mySQLStore) getUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	const q = `
	SELECT u.username, u.user_id, u.email, u.avatar_version
	FROM users u
	WHERE u.email = ?
	`

	var (
		username      string
		userID        string
		userEmail     string
		avatarVersion uint32
	)
	err := d.db.QueryRowContext(ctx, q, email).Scan(&username, &userID, &userEmail, &avatarVersion)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsNoRows(err):
			return nil, repo.NewError(repo.ErrNotFound, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	user := domain.NewUser(
		domain.WithUserID(userID),
		domain.WithUsername(username),
		domain.WithEmail(userEmail),
		domain.WithAvatarVersion(avatarVersion),
	)

	return user, nil
}
