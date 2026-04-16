package group

import (
	"context"
	"database/sql"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s repoStore) Create(ctx context.Context, p *domain.Group) (*domain.Group, error) {
	const createGroupQ = "INSERT INTO `groups` (`id`, `name`, `owner`, `created_at`) VALUES (?, ?, ?, ?)"
	const addOwnerQ = "INSERT INTO `group_members` (`group_id`, `user_id`) VALUES (?, ?)"

	_, err := s.db.ExecContext(ctx, createGroupQ, p.ID, p.Name, p.Owner, p.CreatedAt)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsDuplicateEntry(err):
			return nil, repo.NewError(repo.ErrConflict, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	_, err = s.db.ExecContext(ctx, addOwnerQ, p.ID, p.Owner)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsDuplicateEntry(err):
			return nil, repo.NewError(repo.ErrConflict, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return p, nil
}

func (s repoStore) UpdateName(ctx context.Context, groupID, userID, name string) error {
	const q = "" +
		"UPDATE `groups` g\n" +
		"JOIN `group_members` gm ON gm.`group_id` = g.`id`\n" +
		"SET g.`name` = ?\n" +
		"WHERE g.`id` = ? AND gm.`user_id` = ?"

	res, err := s.db.ExecContext(ctx, q, name, groupID, userID)
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
		groupExists, existsErr := s.exists(ctx, "SELECT 1 FROM `groups` WHERE id = ?", groupID)
		if existsErr != nil {
			return existsErr
		}
		if !groupExists {
			return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
		}
		return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
	}

	return nil
}

func (s repoStore) Delete(ctx context.Context, groupID, ownerID string) error {
	const q = "" +
		"DELETE FROM `groups`\n" +
		"WHERE `id` = ? AND `owner` = ?"

	res, err := s.db.ExecContext(ctx, q, groupID, ownerID)
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
		return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	}

	return nil
}

func (s repoStore) Invite(ctx context.Context, groupID, inviterID, inviteeID string) error {
	const inviteQ = "" +
		"INSERT INTO group_members (group_id, user_id)\n" +
		"SELECT ?, ?\n" +
		"FROM DUAL\n" +
		"WHERE ? <> ?\n" +
		"  AND EXISTS (\n" +
		"    SELECT 1 FROM `groups` g\n" +
		"    WHERE g.`id` = ?\n" +
		"  )\n" +
		"  AND EXISTS (\n" +
		"    SELECT 1 FROM users u\n" +
		"    WHERE u.user_id = ?\n" +
		"  )\n" +
		"  AND EXISTS (\n" +
		"    SELECT 1 FROM group_members gm\n" +
		"    WHERE gm.group_id = ?\n" +
		"      AND gm.user_id = ?\n" +
		"  )\n" +
		"  AND EXISTS (\n" +
		"    SELECT 1\n" +
		"    FROM friendships f\n" +
		"    WHERE f.user_low = LEAST(?, ?)\n" +
		"      AND f.user_high = GREATEST(?, ?)\n" +
		"  )\n" +
		"  AND NOT EXISTS (\n" +
		"    SELECT 1 FROM group_members gm\n" +
		"    WHERE gm.group_id = ?\n" +
		"      AND gm.user_id = ?\n" +
		"  )"

	res, err := s.db.ExecContext(
		ctx,
		inviteQ,
		groupID, inviteeID,
		inviterID, inviteeID,
		groupID,
		inviteeID,
		groupID, inviterID,
		inviterID, inviteeID, inviterID, inviteeID,
		groupID, inviteeID,
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
	if affected > 0 {
		return nil
	}

	if inviterID == inviteeID {
		return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
	}

	groupExists, err := s.exists(ctx, "SELECT 1 FROM `groups` WHERE id = ?", groupID)
	if err != nil {
		return err
	}
	if !groupExists {
		return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	}

	inviteeExists, err := s.exists(ctx, "SELECT 1 FROM users WHERE user_id = ?", inviteeID)
	if err != nil {
		return err
	}
	if !inviteeExists {
		return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	}

	inviterInGroup, err := s.exists(
		ctx,
		"SELECT 1 FROM group_members WHERE group_id = ? AND user_id = ?",
		groupID,
		inviterID,
	)
	if err != nil {
		return err
	}
	if !inviterInGroup {
		return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
	}

	inviteeInGroup, err := s.exists(
		ctx,
		"SELECT 1 FROM group_members WHERE group_id = ? AND user_id = ?",
		groupID,
		inviteeID,
	)
	if err != nil {
		return err
	}
	if inviteeInGroup {
		return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
	}

	areFriends, err := s.exists(
		ctx,
		"SELECT 1 FROM friendships WHERE user_low = LEAST(?, ?) AND user_high = GREATEST(?, ?)",
		inviterID, inviteeID, inviterID, inviteeID,
	)
	if err != nil {
		return err
	}
	if !areFriends {
		return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
	}

	return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
}

func (s repoStore) Leave(ctx context.Context, groupID, userID string) error {
	const q = "" +
		"DELETE FROM `group_members`\n" +
		"WHERE `group_id` = ? AND `user_id` = ?"

	res, err := s.db.ExecContext(ctx, q, groupID, userID)
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
		groupExists, existsErr := s.exists(ctx, "SELECT 1 FROM `groups` WHERE id = ?", groupID)
		if existsErr != nil {
			return existsErr
		}
		if !groupExists {
			return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
		}
		return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
	}

	return nil
}

func (s repoStore) UpdateAvatarMeta(ctx context.Context, groupID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error {
	const q = "" +
		"UPDATE `groups`\n" +
		"SET avatar_version = ?, avatar_updated_at = ?\n" +
		"WHERE id = ? AND avatar_version = ?"

	res, err := s.db.ExecContext(ctx, q, nextVersion, updatedAt, groupID, currentVersion)
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
		groupExists, existsErr := s.exists(ctx, "SELECT 1 FROM `groups` WHERE id = ?", groupID)
		if existsErr != nil {
			return existsErr
		}
		if !groupExists {
			return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
		}
		return repo.NewError(repo.ErrConflict, sql.ErrNoRows)
	}

	return nil
}
