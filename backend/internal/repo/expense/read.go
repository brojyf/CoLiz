package expense

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s *repoStore) GetOverview(ctx context.Context, uid string) ([]domain.Group, []string, []string, error) {
	const q = "" +
		"SELECT\n" +
		"    g.`id`, g.`name`, g.`avatar_version`,\n" +
		"    CAST(\n" +
		"        CASE\n" +
		"            WHEN totals.`net_amount` > 0 THEN ROUND(totals.`net_amount`, 2)\n" +
		"            ELSE 0.00\n" +
		"        END AS CHAR(32)\n" +
		"    ) AS lent_amount,\n" +
		"    CAST(\n" +
		"        CASE\n" +
		"            WHEN totals.`net_amount` < 0 THEN ROUND(ABS(totals.`net_amount`), 2)\n" +
		"            ELSE 0.00\n" +
		"        END AS CHAR(32)\n" +
		"    ) AS borrow_amount\n" +
		"FROM `groups` g\n" +
		"JOIN `group_members` gm ON gm.`group_id` = g.`id`\n" +
		"    AND gm.`user_id` = ?\n" +
		"LEFT JOIN (\n" +
		"    SELECT\n" +
		"        entries.`group_id`,\n" +
		"        SUM(entries.`net_amount`) AS net_amount\n" +
		"    FROM (\n" +
		"        SELECT\n" +
		"            e.`group_id`,\n" +
		"            CASE\n" +
		"                WHEN e.`paid_by` = ? THEN e.`amount` - COALESCE(es.`amount`, 0)\n" +
		"                ELSE -COALESCE(es.`amount`, 0)\n" +
		"            END AS net_amount\n" +
		"        FROM `expenses` e\n" +
		"        JOIN `group_members` gm_expense ON gm_expense.`group_id` = e.`group_id`\n" +
		"            AND gm_expense.`user_id` = ?\n" +
		"        LEFT JOIN `expense_splits` es ON es.`expense_id` = e.`id`\n" +
		"            AND es.`user_id` = ?\n" +
		"    ) entries\n" +
		"    GROUP BY entries.`group_id`\n" +
		") totals ON totals.`group_id` = g.`id`\n" +
		"ORDER BY g.`created_at` DESC, g.`id` ASC"

	rows, err := s.db.QueryContext(
		ctx,
		q,
		uid,
		uid,
		uid,
		uid,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, nil, err
		default:
			return nil, nil, nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	groups := make([]domain.Group, 0)
	lentAmounts := make([]string, 0)
	borrowAmounts := make([]string, 0)
	for rows.Next() {
		var (
			item   domain.Group
			lent   string
			borrow string
		)
		if err := rows.Scan(
			&item.ID,
			&item.Name,
			&item.AvatarVersion,
			&lent,
			&borrow,
		); err != nil {
			switch {
			case ctxx.IsCtxError(err):
				return nil, nil, nil, err
			default:
				return nil, nil, nil, repo.NewError(repo.ErrInternal, err)
			}
		}
		groups = append(groups, item)
		lentAmounts = append(lentAmounts, lent)
		borrowAmounts = append(borrowAmounts, borrow)
	}
	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, nil, err
		default:
			return nil, nil, nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return groups, lentAmounts, borrowAmounts, nil
}

func (s *repoStore) GetGroupMemberIDs(ctx context.Context, groupID string) (map[string]struct{}, error) {
	const q = "" +
		"SELECT gm.`user_id`\n" +
		"FROM `group_members` gm\n" +
		"WHERE gm.`group_id` = ?"

	rows, err := s.db.QueryContext(ctx, q, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	memberIDs := make(map[string]struct{})
	for rows.Next() {
		var userID string
		if err := rows.Scan(&userID); err != nil {
			switch {
			case ctxx.IsCtxError(err):
				return nil, err
			default:
				return nil, repo.NewError(repo.ErrInternal, err)
			}
		}
		memberIDs[userID] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	if len(memberIDs) > 0 {
		return memberIDs, nil
	}

	exists, err := s.exists(ctx, "SELECT 1 FROM `groups` WHERE `id` = ?", groupID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
	}

	return memberIDs, nil
}

func (s *repoStore) exists(ctx context.Context, q string, args ...any) (bool, error) {
	var one int
	err := s.db.QueryRowContext(ctx, q, args...).Scan(&one)
	switch {
	case err == nil:
		return true, nil
	case repo.IsNoRows(err):
		return false, nil
	case ctxx.IsCtxError(err):
		return false, err
	default:
		return false, repo.NewError(repo.ErrInternal, err)
	}
}
