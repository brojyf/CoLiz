package friend

import (
	"context"
	"database/sql"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (r *repoStore) GetFriends(ctx context.Context, userID string) ([]domain.User, error) {
	const q = `
		SELECT u.user_id, u.username, u.email, u.avatar_version
		FROM friendships f
		JOIN users u ON u.user_id = f.user_high
		WHERE f.user_low = ?

		UNION ALL

		SELECT u.user_id, u.username, u.email, u.avatar_version
		FROM friendships f
		JOIN users u ON u.user_id = f.user_low
		WHERE f.user_high = ?

		ORDER BY username ASC, user_id ASC
	`

	rows, err := r.db.QueryContext(ctx, q, userID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	friends := make([]domain.User, 0)
	for rows.Next() {
		var (
			id            string
			username      string
			email         string
			avatarVersion uint32
		)
		if err := rows.Scan(&id, &username, &email, &avatarVersion); err != nil {
			return nil, repo.NewError(repo.ErrInternal, err)
		}
		friends = append(friends, newUser(id, username, email, avatarVersion))
	}
	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return friends, nil
}

func (r *repoStore) GetFriend(ctx context.Context, userID, friendID string) (*domain.User, error) {
	const q = `
		SELECT u.user_id, u.username, u.email, u.avatar_version, u.avatar_updated_at, f.created_at
		FROM users u
		JOIN friendships f
		  ON f.user_low = LEAST(?, ?)
		 AND f.user_high = GREATEST(?, ?)
		WHERE u.user_id = ?
		LIMIT 1
	`

	var (
		id            string
		username      string
		email         string
		avatarVersion uint32
		avatarUpdated sql.NullTime
		friendSince   time.Time
	)

	err := r.db.QueryRowContext(ctx, q, userID, friendID, userID, friendID, friendID).Scan(
		&id,
		&username,
		&email,
		&avatarVersion,
		&avatarUpdated,
		&friendSince,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsNoRows(err) :
			localError := existsUser(ctx, r.db, friendID)
			if localError != nil { return nil, localError}
			return nil, repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	mutualGroups, groupsErr := r.getMutualGroups(ctx, userID, friendID)
	if groupsErr != nil {
		return nil, groupsErr
	}

	opts := []domain.UserOption{
		domain.WithUserID(id),
		domain.WithUsername(username),
		domain.WithEmail(email),
		domain.WithAvatarVersion(avatarVersion),
		domain.WithFriendSince(friendSince),
		domain.WithMutualGroups(mutualGroups),
	}
	if avatarUpdated.Valid {
		opts = append(opts, domain.WithAvatarUpdatedAt(avatarUpdated.Time))
	}

	user := domain.NewUser(opts...)
	return user, nil
}

func (r *repoStore) GetRequests(ctx context.Context, userID string) ([]domain.FriendRequest, error) {
	const q = `
		SELECT
			fr.id,
			fr.from_user,
			uf.username,
			uf.avatar_version,
			fr.to_user,
			ut.username,
			ut.avatar_version,
			fr.message,
			fr.status,
			fr.created_at,
			fr.expired_at
		FROM friend_requests fr
		JOIN users uf ON uf.user_id = fr.from_user
		JOIN users ut ON ut.user_id = fr.to_user
		WHERE (fr.from_user = ? OR fr.to_user = ?)
		  AND fr.status IN (0, 2)
		  AND (fr.expired_at IS NULL OR fr.expired_at > NOW())
		ORDER BY fr.created_at DESC, fr.id DESC
	`

	rows, err := r.db.QueryContext(ctx, q, userID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	reqs := make([]domain.FriendRequest, 0)
	for rows.Next() {
		var (
			id                string
			fromUser          string
			fromName          string
			fromAvatarVersion uint32
			toUser            string
			toName            string
			toAvatarVersion   uint32
			msg               string
			status            int
			createdAt         time.Time
			expiredAt         sql.NullTime
		)
		if err := rows.Scan(
			&id,
			&fromUser,
			&fromName,
			&fromAvatarVersion,
			&toUser,
			&toName,
			&toAvatarVersion,
			&msg,
			&status,
			&createdAt,
			&expiredAt,
		); err != nil {
			return nil, repo.NewError(repo.ErrInternal, err)
		}

		opts := []domain.FriendRequestOption{
			domain.WithFriendRequestID(id),
			domain.WithFromUser(fromUser),
			domain.WithFromUsername(fromName),
			domain.WithFromAvatarVersion(fromAvatarVersion),
			domain.WithToUser(toUser),
			domain.WithToUsername(toName),
			domain.WithToAvatarVersion(toAvatarVersion),
			domain.WithFriendRequestMessage(msg),
			domain.WithFriendRequestStatus(status),
			domain.WithFriendRequestCreatedAt(createdAt),
		}
		if expiredAt.Valid {
			opts = append(opts, domain.WithFriendRequestExpiredAt(expiredAt.Time))
		}

		fr, err := domain.NewFriendRequest(opts...)
		if err != nil {
			return nil, repo.NewError(repo.ErrInternal, err)
		}

		reqs = append(reqs, *fr)
	}
	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return reqs, nil
}

// Helper funcitons
func newUser(id, username, email string, avatarVersion uint32) domain.User {
	return *domain.NewUser(
		domain.WithUserID(id),
		domain.WithUsername(username),
		domain.WithEmail(email),
		domain.WithAvatarVersion(avatarVersion),
	)
}

func existsUser(ctx context.Context, db repo.DBTX, userID string) error {
	const q = `
		SELECT 1
		FROM users
		WHERE user_id = ?
		LIMIT 1
	`

	var exists int
	err := db.QueryRowContext(ctx, q, userID).Scan(&exists)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case repo.IsNoRows(err):
			return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	return nil
}

func (r *repoStore) getMutualGroups(ctx context.Context, userID, friendID string) ([]domain.Group, error) {
	const q = `
		SELECT g.id, g.name, g.owner, g.avatar_version, g.avatar_updated_at, g.created_at
		FROM ` + "`groups`" + ` g
		JOIN group_members gm_self
		  ON gm_self.group_id = g.id
		 AND gm_self.user_id = ?
		JOIN group_members gm_friend
		  ON gm_friend.group_id = g.id
		 AND gm_friend.user_id = ?
		ORDER BY g.name ASC, g.id ASC
	`

	rows, err := r.db.QueryContext(ctx, q, userID, friendID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	groups := make([]domain.Group, 0)
	for rows.Next() {
		var (
			id            string
			name          string
			owner         string
			avatarVersion uint32
			avatarUpdated sql.NullTime
			createdAt     time.Time
		)

		if err := rows.Scan(&id, &name, &owner, &avatarVersion, &avatarUpdated, &createdAt); err != nil {
			if ctxx.IsCtxError(err) { return nil, err }
			return nil, repo.NewError(repo.ErrInternal, err)
		}

		opts := []domain.GroupOption{
			domain.WithGroupID(id),
			domain.WithGroupName(name),
			domain.WithGroupOwner(owner),
			domain.WithGroupAvatarVersion(avatarVersion),
			domain.WithGroupCreatedAt(createdAt),
		}
		if avatarUpdated.Valid {
			opts = append(opts, domain.WithGroupAvatarUpdatedAt(avatarUpdated.Time))
		}

		group, buildErr := domain.NewGroup(opts...)
		if buildErr != nil {
			return nil, repo.NewError(repo.ErrInternal, buildErr)
		}
		groups = append(groups, *group)
	}

	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return groups, nil
}
