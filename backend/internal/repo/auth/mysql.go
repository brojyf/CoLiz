package auth

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

func (d *mySQLStore) createUser(ctx context.Context, p *domain.User) error {
	const query = `
		INSERT INTO users (
		  user_id, username, email, password_hash, device_id,
		  rtk_hash, rtk_pepper_version, rtk_expired_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`

	_, err := d.db.ExecContext(
		ctx,
		query,
		p.ID,
		p.Username,
		p.Email,
		p.PasswordHash,
		p.DeviceID,
		p.RTK.Hash,
		p.RTK.PepperVersion,
		p.RTK.ExpireAt,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case repo.IsDuplicateEntry(err):
			return repo.NewError(repo.ErrConflict, err)
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	return nil
}

func (d *mySQLStore) resetPassword(ctx context.Context, user *domain.User) (string, error) {
	const q1 = `
		SELECT user_id
		FROM users
		WHERE email = ?
	`
	const q2 = `
		UPDATE users
		SET 
		  password_hash = ?, device_id = ?,
		  rtk_hash = ?, rtk_pepper_version = ?, 
		  rtk_expired_at = ?, rtk_revoked_at = NULL
		WHERE email = ?
	`

	err := d.db.QueryRowContext(ctx, q1, user.Email).Scan(&user.ID)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return "", err
		}
		if errors.Is(err, sql.ErrNoRows) {
			return "", repo.ErrNotFound
		}
		return "", repo.NewError(repo.ErrInternal, err)
	}

	res, err := d.db.ExecContext(
		ctx,
		q2,
		user.PasswordHash, user.DeviceID,
		user.RTK.Hash, user.RTK.PepperVersion,
		user.RTK.ExpireAt,
		user.Email,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return "", err
		default:
			return "", repo.NewError(repo.ErrInternal, err)
		}
	}

	n, err := res.RowsAffected()
	if err != nil {
		return "", repo.NewError(repo.ErrInternal, err)
	}
	if n == 0 {
		return "", repo.ErrNotFound
	}

	return user.ID, nil
}

func (d *mySQLStore) getUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	const query = `
		SELECT user_id, email, password_hash
		FROM users
		WHERE email = ?
	`

	var uid, userEmail, passwordHash string
	err := d.db.QueryRowContext(ctx, query, email).Scan(
		&uid,
		&userEmail,
		&passwordHash,
	)

	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsNoRows(err):
			return nil, repo.ErrNotFound
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	user := domain.NewUser(
		domain.WithUserID(uid),
		domain.WithEmail(userEmail),
		domain.WithPasswordHash(passwordHash),
	)

	return user, nil
}

func (d *mySQLStore) updateLogin(ctx context.Context, user *domain.User) error {
	const query = `
		UPDATE users
		SET rtk_hash = ?, rtk_pepper_version = ?, rtk_expired_at = ?, device_id = ?, rtk_revoked_at = NULL
		WHERE user_id = ?
	`

	_, err := d.db.ExecContext(
		ctx,
		query,
		user.RTK.Hash,
		user.RTK.PepperVersion,
		user.RTK.ExpireAt,
		user.DeviceID,
		user.ID,
	)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	return nil
}

func (d *mySQLStore) getUserByRTKHash(ctx context.Context, v, h string) (*domain.User, error) {
	const query = `
		SELECT 
		  user_id, email, device_id, rtk_pepper_version, 
		  rtk_expired_at, rtk_revoked_at
		FROM users
		WHERE rtk_hash = ? AND rtk_pepper_version = ?
		  AND device_id IS NOT NULL
		  AND rtk_revoked_at IS NULL
	`

	var (
		uid           string
		userEmail     string
		deviceID      sql.NullString
		pepperVersion string
		expireAt      time.Time
		revokedAt     *time.Time
	)
	err := d.db.QueryRowContext(ctx, query, h, v).Scan(
		&uid,
		&userEmail,
		&deviceID,
		&pepperVersion,
		&expireAt,
		&revokedAt,
	)

	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsNoRows(err):
			return nil, repo.ErrNotFound
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	user := domain.NewUser(
		domain.WithUserID(uid),
		domain.WithEmail(userEmail),
		domain.WithDeviceID(deviceID.String),
		domain.WithRTK(h, pepperVersion, expireAt),
		domain.WithRTKRevokedAt(revokedAt),
	)

	return user, nil
}

func (d *mySQLStore) updateRTKHashByUID(ctx context.Context, user *domain.User) error {
	const query = `
		UPDATE users
		SET rtk_hash = ?, rtk_pepper_version = ?, rtk_expired_at = ?
		WHERE user_id = ?
	`

	_, err := d.db.ExecContext(
		ctx,
		query,
		user.RTK.Hash,
		user.RTK.PepperVersion,
		user.RTK.ExpireAt,
		user.ID,
	)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	return nil
}

func (d *mySQLStore) revokeRTKAndDID(ctx context.Context, uid string) error {
	const q = `
	    UPDATE users
		SET rtk_revoked_at = NOW(), device_id = NULL
		WHERE user_id = ?
	`

	_, err := d.db.ExecContext(ctx, q, uid)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	return nil
}

func (d *mySQLStore) getUserByUID(ctx context.Context, user *domain.User) (*domain.User, error) {
	const query = `
		SELECT password_hash, device_id
		FROM users
		WHERE user_id = ?
	`

	err := d.db.QueryRowContext(ctx, query, user.ID).Scan(
		&user.PasswordHash,
		&user.DeviceID,
	)

	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsNoRows(err):
			return nil, repo.ErrNotFound
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return user, nil
}

func (d *mySQLStore) updatePassword(ctx context.Context, user *domain.User) error {
	const query = `
		UPDATE users
		SET password_hash = ?, rtk_hash = ?, rtk_pepper_version = ?, 
		  rtk_expired_at = ?, rtk_revoked_at = NULL
		WHERE user_id = ?
	`

	_, err := d.db.ExecContext(
		ctx,
		query,
		user.PasswordHash,
		user.RTK.Hash,
		user.RTK.PepperVersion,
		user.RTK.ExpireAt,
		user.ID,
	)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	return nil
}

// MiddlewareThrottler
func (d *mySQLStore) didMatchUID(ctx context.Context, did, uid string) error {
	const query = `
		SELECT 1
		FROM users
		WHERE user_id = ? AND device_id = ?
		LIMIT 1
	`

	var ok int
	err := d.db.QueryRowContext(ctx, query, uid, did).Scan(&ok)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case repo.IsNoRows(err):
			return repo.ErrUnauthorized
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	return nil
}
