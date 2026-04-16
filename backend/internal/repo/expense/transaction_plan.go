package expense

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s *repoStore) GetGroupMemberBalances(ctx context.Context, uid, groupID string) (*domain.Group, []domain.MemberNetBalance, error) {
	if err := s.ensureGroupAccess(ctx, uid, groupID); err != nil {
		return nil, nil, err
	}

	const q = "" +
		"SELECT\n" +
		"    g.`id`,\n" +
		"    g.`name`,\n" +
		"    g.`avatar_version`,\n" +
		"    u.`user_id`,\n" +
		"    u.`username`,\n" +
		"    u.`avatar_version`,\n" +
		"    CAST(\n" +
		"        ROUND(\n" +
		"            COALESCE(SUM(CASE WHEN e.`paid_by` = gm.`user_id` THEN e.`amount` ELSE 0 END), 0) -\n" +
		"            COALESCE(SUM(es.`amount`), 0),\n" +
		"            2\n" +
		"        ) AS CHAR(32)\n" +
		"    ) AS net_amount\n" +
		"FROM `group_members` gm\n" +
		"JOIN `groups` g ON g.`id` = gm.`group_id`\n" +
		"JOIN `users` u ON u.`user_id` = gm.`user_id`\n" +
		"LEFT JOIN `expenses` e ON e.`group_id` = gm.`group_id`\n" +
		"LEFT JOIN `expense_splits` es ON es.`expense_id` = e.`id`\n" +
		"    AND es.`user_id` = gm.`user_id`\n" +
		"WHERE gm.`group_id` = ?\n" +
		"GROUP BY g.`id`, g.`name`, g.`avatar_version`, u.`user_id`, u.`username`, u.`avatar_version`\n" +
		"ORDER BY u.`user_id` ASC"

	rows, err := s.db.QueryContext(ctx, q, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, err
		default:
			return nil, nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	var group *domain.Group
	balances := make([]domain.MemberNetBalance, 0)
	for rows.Next() {
		var (
			item   domain.Group
			user   domain.User
			amount string
		)
		if err := rows.Scan(
			&item.ID,
			&item.Name,
			&item.AvatarVersion,
			&user.ID,
			&user.Username,
			&user.AvatarVersion,
			&amount,
		); err != nil {
			switch {
			case ctxx.IsCtxError(err):
				return nil, nil, err
			default:
				return nil, nil, repo.NewError(repo.ErrInternal, err)
			}
		}

		if group == nil {
			group = &item
		}

		balances = append(balances, domain.MemberNetBalance{
			User:      user,
			NetAmount: amount,
		})
	}
	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, err
		default:
			return nil, nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	if group == nil {
		return nil, nil, repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	}

	return group, balances, nil
}

func (s *repoStore) LockGroup(ctx context.Context, uid, groupID string) error {
	if err := s.ensureGroupAccess(ctx, uid, groupID); err != nil {
		return err
	}

	const q = "" +
		"SELECT `id`\n" +
		"FROM `groups`\n" +
		"WHERE `id` = ?\n" +
		"FOR UPDATE"

	var lockedID string
	err := s.db.QueryRowContext(ctx, q, groupID).Scan(&lockedID)
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

	return nil
}

func (s *repoStore) ensureGroupAccess(ctx context.Context, uid, groupID string) error {
	allowed, err := s.exists(
		ctx,
		"SELECT 1 FROM `group_members` WHERE `group_id` = ? AND `user_id` = ?",
		groupID,
		uid,
	)
	if err != nil {
		return err
	}
	if allowed {
		return nil
	}

	groupExists, err := s.exists(ctx, "SELECT 1 FROM `groups` WHERE `id` = ?", groupID)
	if err != nil {
		return err
	}
	if !groupExists {
		return repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	}

	return repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
}
