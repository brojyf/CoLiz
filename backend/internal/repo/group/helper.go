package group

import (
	"context"

	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s repoStore) CanDelete(ctx context.Context, groupID string) (bool, error) {
	const q = `
		SELECT 1 FROM (
		  SELECT
			gm.user_id,
			COALESCE(SUM(CASE WHEN e.paid_by = gm.user_id THEN e.amount ELSE 0 END), 0) - 
			COALESCE(SUM(es.amount), 0) AS net_amount          -- paid - received
		  FROM group_members gm
		  LEFT JOIN expenses e ON e.group_id = gm.group_id     -- left join expenses
		  LEFT JOIN expense_splits es ON es.expense_id = e.id  -- left join expense_split for the user
		    AND es.user_id = gm.user_id
		  WHERE gm.group_id = ?
		  GROUP BY gm.user_id
		) balances
		WHERE balances.net_amount <> 0
		LIMIT 1
	`

	hasOutstandingBalance, err := s.exists(ctx, q, groupID)
	if err != nil {
		return false, err
	}

	return !hasOutstandingBalance, nil
}

func (s repoStore) CanLeave(ctx context.Context, groupID, userID string) (bool, error) {
	const q = "" +
		"SELECT 1\n" +
		"FROM (\n" +
		"  SELECT\n" +
		"    gm.`user_id`,\n" +
		"    COALESCE(SUM(CASE WHEN e.`paid_by` = gm.`user_id` THEN e.`amount` ELSE 0 END), 0) -\n" +
		"    COALESCE(SUM(es.`amount`), 0) AS net_amount\n" +
		"  FROM `group_members` gm\n" +
		"  LEFT JOIN `expenses` e ON e.`group_id` = gm.`group_id`\n" +
		"  LEFT JOIN `expense_splits` es ON es.`expense_id` = e.`id`\n" +
		"    AND es.`user_id` = gm.`user_id`\n" +
		"  WHERE gm.`group_id` = ? AND gm.`user_id` = ?\n" +
		"  GROUP BY gm.`user_id`\n" +
		") balances\n" +
		"WHERE balances.`net_amount` <> 0\n" +
		"LIMIT 1"

	hasOutstandingBalance, err := s.exists(ctx, q, groupID, userID)
	if err != nil {
		return false, err
	}

	return !hasOutstandingBalance, nil
}

func (s repoStore) exists(ctx context.Context, q string, args ...any) (bool, error) {
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
