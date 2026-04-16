package friend

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/frpol"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (r *repoStore) Delete(ctx context.Context, userID, friendID string) error {
	const deleteQ = `
		DELETE FROM friendships
		WHERE user_low = LEAST(?, ?)
		  AND user_high = GREATEST(?, ?)
		  AND NOT EXISTS (
		    SELECT 1
		    FROM group_members gm_self
		    JOIN group_members gm_friend
		      ON gm_friend.group_id = gm_self.group_id
		     AND gm_friend.user_id = ?
		    WHERE gm_self.user_id = ?
		  )
	`

	res, err := r.db.ExecContext(ctx, deleteQ, userID, friendID, userID, friendID, friendID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case repo.IsConflict(err):
			return repo.NewError(repo.ErrConflict, err)
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
	if affected < 1 {
		return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
	}

	return nil
}

func (r *repoStore) SendRequest(ctx context.Context, p *domain.FriendRequest) error {
	const pendingStatus = frpol.Pending
	const canceledStatus = frpol.Canceled
	const expireQ = `
		UPDATE friend_requests
		SET status = ?
		WHERE status = ?
		  AND expired_at IS NOT NULL
		  AND expired_at <= NOW()
		  AND (
		    (from_user = ? AND to_user = ?)
			OR
			(from_user = ? AND to_user = ?)
		  )
	`
	if _, err := r.db.ExecContext(ctx, expireQ, canceledStatus, pendingStatus, p.From, p.To, p.To, p.From); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	const q = `
		INSERT INTO friend_requests (id, from_user, to_user, message, status, expired_at)
		SELECT ?, ?, ?, ?, ?, ?
		FROM DUAL
		WHERE ? <> ? 										-- cannot request to self
		  AND EXISTS (
		    SELECT 1 FROM users u WHERE u.user_id = ?		-- from user exists
		  )
		  AND EXISTS (
		    SELECT 1 FROM users u WHERE u.user_id = ?		-- to user exists
		  )
		  AND NOT EXISTS (
		    SELECT 1
		    FROM friendships f								-- cannot be friends
		    WHERE f.user_low = LEAST(?, ?)
		      AND f.user_high = GREATEST(?, ?)
		  )
		  AND NOT EXISTS (
		    SELECT 1
		    FROM friend_requests fr							-- cannot have pending requests
		    WHERE fr.status = 0
			  AND (fr.expired_at IS NULL OR fr.expired_at > NOW())
			  AND (
			    (fr.from_user = ? AND fr.to_user = ?)
				OR
				(fr.from_user = ? AND fr.to_user = ?)
			  )
		  )
	`

	res, err := r.db.ExecContext(
		ctx,
		q,
		p.ID, p.From, p.To, p.Msg, pendingStatus, p.ExpiredAt,
		p.From, p.To,
		p.From,
		p.To,
		p.From, p.To, p.From, p.To,
		p.From, p.To, p.To, p.From,
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

	affected, err := res.RowsAffected()
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	if affected == 0 {
		return r.classifySendRequestFailure(ctx, p.From, p.To)
	}

	return nil
}

func (r *repoStore) AcceptRequest(ctx context.Context, requestID, userID string) error {
	const pendingStatus = frpol.Pending

	const updateQ = `
		UPDATE friend_requests
		SET status = 1
		WHERE id = ?
		  AND to_user = ?
		  AND status = ?
		  AND (expired_at IS NULL OR expired_at > NOW())
	`
	const getRequestStateQ = `
		SELECT to_user, status, expired_at
		FROM friend_requests
		WHERE id = ?
		LIMIT 1
	`
	const getUsersQ = `
		SELECT from_user, to_user
		FROM friend_requests
		WHERE id = ?
		LIMIT 1
	`
	const createFriendshipQ = `
		INSERT IGNORE INTO friendships (user_low, user_high)
		VALUES (LEAST(?, ?), GREATEST(?, ?))
	`

	res, err := r.db.ExecContext(ctx, updateQ, requestID, userID, pendingStatus)
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
		var toUser string
		var status int
		var expiredAt sql.NullTime
		err = r.db.QueryRowContext(ctx, getRequestStateQ, requestID).Scan(&toUser, &status, &expiredAt)
		if err != nil {
			if ctxx.IsCtxError(err) {
				return err
			}
			if errors.Is(err, sql.ErrNoRows) {
				return repo.NewError(repo.ErrNotFound, err)
			}
			return repo.NewError(repo.ErrInternal, err)
		}

		if toUser != userID {
			return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
		}
		if expiredAt.Valid && !expiredAt.Time.After(time.Now()) {
			return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
		}
		if status != pendingStatus {
			return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
		}

		return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
	}

	var fromUser, toUser string
	err = r.db.QueryRowContext(ctx, getUsersQ, requestID).Scan(&fromUser, &toUser)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		if errors.Is(err, sql.ErrNoRows) {
			return repo.NewError(repo.ErrNotFound, err)
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	_, err = r.db.ExecContext(ctx, createFriendshipQ, fromUser, toUser, fromUser, toUser)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	return nil
}

func (r *repoStore) DeclineRequest(ctx context.Context, requestID, userID string) error {
	const updateQ = `
		UPDATE friend_requests
		SET status = ?
		WHERE id = ?
		  AND to_user = ?
		  AND status = ?
		  AND (expired_at IS NULL OR expired_at > NOW())
	`
	const getRequestStateQ = `
		SELECT to_user, status, expired_at
		FROM friend_requests
		WHERE id = ?
		LIMIT 1
	`

	res, err := r.db.ExecContext(ctx, updateQ, frpol.Rejected, requestID, userID, frpol.Pending)
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
		var toUser string
		var status int
		var expiredAt sql.NullTime
		err = r.db.QueryRowContext(ctx, getRequestStateQ, requestID).Scan(&toUser, &status, &expiredAt)
		if err != nil {
			switch {
			case ctxx.IsCtxError(err):
				return err
			case errors.Is(err, sql.ErrNoRows):
				return repo.NewError(repo.ErrNotFound, err)
			default:
				return repo.NewError(repo.ErrInternal, err)
			}
		}

		if toUser != userID {
			return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
		}
		if expiredAt.Valid && !expiredAt.Time.After(time.Now()) {
			return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
		}
		if status != frpol.Pending {
			return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
		}

		return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
	}

	return nil
}

func (r *repoStore) CancelRequest(ctx context.Context, requestID, userID string) error {
	const updateQ = `
		UPDATE friend_requests
		SET status = ?
		WHERE id = ?
		  AND from_user = ?
		  AND status = ?
		  AND (expired_at IS NULL OR expired_at > NOW())
	`
	const getRequestStateQ = `
		SELECT from_user, status, expired_at
		FROM friend_requests
		WHERE id = ?
		LIMIT 1
	`

	res, err := r.db.ExecContext(ctx, updateQ, frpol.Canceled, requestID, userID, frpol.Pending)
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
		var fromUser string
		var status int
		var expiredAt sql.NullTime
		err = r.db.QueryRowContext(ctx, getRequestStateQ, requestID).Scan(&fromUser, &status, &expiredAt)
		if err != nil {
			switch {
			case ctxx.IsCtxError(err):
				return err
			case repo.IsNoRows(err):
				return repo.NewError(repo.ErrNotFound, err)
			default:
				return repo.NewError(repo.ErrInternal, err)
			}
		}

		if fromUser != userID {
			return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
		}
		if expiredAt.Valid && !expiredAt.Time.After(time.Now()) {
			return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
		}
		if status != frpol.Pending {
			return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
		}

		return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
	}

	return nil
}

func (r *repoStore) classifySendRequestFailure(ctx context.Context, fromUser, toUser string) error {
	if fromUser == toUser {
		return repo.NewError(repo.ErrInvalidInput, nil)
	}

	if err := existsUser(ctx, r.db, toUser); err != nil {
		if errors.Is(err, repo.ErrNotFound) {
			return err
		}
		return err
	}

	isFriend, err := r.friendshipExists(ctx, fromUser, toUser)
	if err != nil {
		return err
	}
	if isFriend {
		return repo.NewError(repo.ErrConflict, nil)
	}

	hasPending, err := r.pendingRequestExists(ctx, fromUser, toUser)
	if err != nil {
		return err
	}
	if hasPending {
		return repo.NewError(repo.ErrConflict, nil)
	}

	return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
}

func (r *repoStore) friendshipExists(ctx context.Context, userID, friendID string) (bool, error) {
	const q = `
		SELECT 1
		FROM friendships
		WHERE user_low = LEAST(?, ?)
		  AND user_high = GREATEST(?, ?)
		LIMIT 1
	`

	var exists int
	err := r.db.QueryRowContext(ctx, q, userID, friendID, userID, friendID).Scan(&exists)
	if err == nil {
		return true, nil
	}
	switch {
	case ctxx.IsCtxError(err):
		return false, err
	case repo.IsNoRows(err):
		return false, nil
	default:
		return false, repo.NewError(repo.ErrInternal, err)
	}
}

func (r *repoStore) pendingRequestExists(ctx context.Context, fromUser, toUser string) (bool, error) {
	const q = `
		SELECT 1
		FROM friend_requests
		WHERE status = ?
		  AND (expired_at IS NULL OR expired_at > NOW())
		  AND (
		    (from_user = ? AND to_user = ?)
			OR
			(from_user = ? AND to_user = ?)
		  )
		LIMIT 1
	`

	var exists int
	err := r.db.QueryRowContext(ctx, q, frpol.Pending, fromUser, toUser, toUser, fromUser).Scan(&exists)
	if err == nil {
		return true, nil
	}
	switch {
	case ctxx.IsCtxError(err):
		return false, err
	case repo.IsNoRows(err):
		return false, nil
	default:
		return false, repo.NewError(repo.ErrInternal, err)
	}
}
