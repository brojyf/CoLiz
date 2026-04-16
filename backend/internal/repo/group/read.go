package group

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s repoStore) Get(ctx context.Context, uid string) ([]domain.Group, error) {
	const getGroupsQ = "" +
		"SELECT g.`id`, g.`name`, g.`owner`, g.`avatar_version`, g.`avatar_updated_at`, g.`created_at`\n" +
		"FROM `groups` g\n" +
		"JOIN `group_members` gm ON gm.`group_id` = g.`id`\n" +
		"WHERE gm.`user_id` = ?"

	rows, err := s.db.QueryContext(ctx, getGroupsQ, uid)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return nil, err
		}
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	defer rows.Close()

	groups := make([]domain.Group, 0)
	for rows.Next() {
		var id, name, owner string
		var avatarVersion uint32
		var avatarUpdatedAt sql.NullTime
		var createdAt time.Time
		if err := rows.Scan(&id, &name, &owner, &avatarVersion, &avatarUpdatedAt, &createdAt); err != nil {
			if ctxx.IsCtxError(err) {
				return nil, err
			}
			return nil, repo.NewError(repo.ErrInternal, err)
		}

		g, err := domain.NewGroup(
			domain.WithGroupID(id),
			domain.WithGroupName(name),
			domain.WithGroupOwner(owner),
			domain.WithGroupAvatarVersion(avatarVersion),
			domain.WithGroupCreatedAt(createdAt),
		)
		if err != nil {
			return nil, repo.NewError(repo.ErrInternal, err)
		}
		if avatarUpdatedAt.Valid {
			g.AvatarUpdatedAt = &avatarUpdatedAt.Time
		}
		groups = append(groups, *g)
	}
	if err := rows.Err(); err != nil {
		if ctxx.IsCtxError(err) {
			return nil, err
		}
		return nil, repo.NewError(repo.ErrInternal, err)
	}

	return groups, nil
}

func (s repoStore) GetDetail(ctx context.Context, groupID, userID string) (*domain.Group, error) {
	const q = "" +
		"SELECT g.`id`, g.`name`, g.`owner`, g.`avatar_version`, g.`avatar_updated_at`, g.`created_at`\n" +
		"FROM `groups` g\n" +
		"JOIN `group_members` gm ON gm.`group_id` = g.`id`\n" +
		"WHERE g.`id` = ? AND gm.`user_id` = ?"

	var (
		id, name, owner string
		avatarVersion   uint32
		avatarUpdatedAt sql.NullTime
		createdAt       time.Time
	)
	err := s.db.QueryRowContext(ctx, q, groupID, userID).Scan(
		&id,
		&name,
		&owner,
		&avatarVersion,
		&avatarUpdatedAt,
		&createdAt,
	)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			groupExists, existsErr := s.exists(ctx, "SELECT 1 FROM `groups` WHERE id = ?", groupID)
			if existsErr != nil {
				return nil, existsErr
			}
			if !groupExists {
				return nil, repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
			}

			return nil, repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	opts := []domain.GroupOption{
		domain.WithGroupID(id),
		domain.WithGroupName(name),
		domain.WithGroupOwner(owner),
		domain.WithGroupAvatarVersion(avatarVersion),
		domain.WithGroupCreatedAt(createdAt),
	}
	if avatarUpdatedAt.Valid {
		opts = append(opts, domain.WithGroupAvatarUpdatedAt(avatarUpdatedAt.Time))
	}
	g, buildErr := domain.NewGroup(opts...)
	if buildErr != nil {
		return nil, repo.NewError(repo.ErrInternal, buildErr)
	}
	return g, nil
}

func (s repoStore) GetMembers(ctx context.Context, groupID string) ([]domain.User, error) {
	const q = "" +
		"SELECT u.`user_id`, u.`username`, u.`email`, u.`avatar_version`, u.`avatar_updated_at`\n" +
		"FROM `group_members` gm\n" +
		"JOIN `users` u ON u.`user_id` = gm.`user_id`\n" +
		"WHERE gm.`group_id` = ?\n" +
		"ORDER BY u.`username` ASC, u.`user_id` ASC"

	rows, err := s.db.QueryContext(ctx, q, groupID)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return nil, err
		}
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	defer rows.Close()

	users := make([]domain.User, 0)
	for rows.Next() {
		var (
			id            string
			username      string
			email         string
			avatarVersion uint32
			avatarUpdated sql.NullTime
		)
		if err := rows.Scan(&id, &username, &email, &avatarVersion, &avatarUpdated); err != nil {
			if ctxx.IsCtxError(err) {
				return nil, err
			}
			return nil, repo.NewError(repo.ErrInternal, err)
		}

		opts := []domain.UserOption{
			domain.WithUserID(id),
			domain.WithUsername(username),
			domain.WithEmail(email),
			domain.WithAvatarVersion(avatarVersion),
		}
		if avatarUpdated.Valid {
			opts = append(opts, domain.WithAvatarUpdatedAt(avatarUpdated.Time))
		}

		user := domain.NewUser(opts...)
		users = append(users, *user)
	}
	if err := rows.Err(); err != nil {
		if ctxx.IsCtxError(err) {
			return nil, err
		}
		return nil, repo.NewError(repo.ErrInternal, err)
	}

	return users, nil
}

func (s repoStore) GetByID(ctx context.Context, groupID string) (*domain.Group, error) {
	const q = "" +
		"SELECT g.`id`, g.`name`, g.`owner`, g.`avatar_version`, g.`avatar_updated_at`, g.`created_at`\n" +
		"FROM `groups` g\n" +
		"WHERE g.`id` = ?"

	var (
		id, name, owner string
		avatarVersion   uint32
		avatarUpdatedAt sql.NullTime
		createdAt       time.Time
	)
	err := s.db.QueryRowContext(ctx, q, groupID).Scan(
		&id,
		&name,
		&owner,
		&avatarVersion,
		&avatarUpdatedAt,
		&createdAt,
	)
	switch {
	case err == nil:
		opts := []domain.GroupOption{
			domain.WithGroupID(id),
			domain.WithGroupName(name),
			domain.WithGroupOwner(owner),
			domain.WithGroupAvatarVersion(avatarVersion),
			domain.WithGroupCreatedAt(createdAt),
		}
		if avatarUpdatedAt.Valid {
			opts = append(opts, domain.WithGroupAvatarUpdatedAt(avatarUpdatedAt.Time))
		}
		g, buildErr := domain.NewGroup(opts...)
		if buildErr != nil {
			return nil, repo.NewError(repo.ErrInternal, buildErr)
		}
		return g, nil
	case errors.Is(err, sql.ErrNoRows):
		return nil, repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	case ctxx.IsCtxError(err):
		return nil, err
	default:
		return nil, repo.NewError(repo.ErrInternal, err)
	}
}
