package expense

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/expol"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s *repoStore) GetGroupExpense(ctx context.Context, uid, groupID string) (*domain.Group, string, string, error) {
	allowed, err := s.exists(
		ctx,
		"SELECT 1 FROM `group_members` WHERE `group_id` = ? AND `user_id` = ?",
		groupID,
		uid,
	)
	if err != nil {
		return nil, "", "", err
	}
	if !allowed {
		groupExists, err := s.exists(ctx, "SELECT 1 FROM `groups` WHERE `id` = ?", groupID)
		if err != nil {
			return nil, "", "", err
		}
		if !groupExists {
			return nil, "", "", repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
		}
		return nil, "", "", repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
	}

	const q = "" +
		"SELECT\n" +
		"    g.`id`,\n" +
		"    g.`name`,\n" +
		"    g.`avatar_version`,\n" +
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
		"        WHERE e.`group_id` = ?\n" +
		"    ) entries\n" +
		"    GROUP BY entries.`group_id`\n" +
		") totals ON totals.`group_id` = g.`id`\n" +
		"WHERE g.`id` = ?\n" +
		"LIMIT 1"

	var (
		item   domain.Group
		lent   string
		borrow string
	)
	err = s.db.QueryRowContext(ctx, q, uid, uid, uid, uid, groupID, groupID).Scan(
		&item.ID,
		&item.Name,
		&item.AvatarVersion,
		&lent,
		&borrow,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, "", "", err
		case errors.Is(err, sql.ErrNoRows):
			return nil, "", "", repo.NewError(repo.ErrNotFound, err)
		default:
			return nil, "", "", repo.NewError(repo.ErrInternal, err)
		}
	}

	return &item, lent, borrow, nil
}

func (s *repoStore) GetGroupExpenseHistory(ctx context.Context, groupID, uid string) ([]domain.Expense, []string, []string, []domain.User, error) {
	allowed, err := s.exists(
		ctx,
		"SELECT 1 FROM `group_members` WHERE `group_id` = ? AND `user_id` = ?",
		groupID,
		uid,
	)
	if err != nil {
		return nil, nil, nil, nil, err
	}
	if !allowed {
		groupExists, err := s.exists(ctx, "SELECT 1 FROM `groups` WHERE `id` = ?", groupID)
		if err != nil {
			return nil, nil, nil, nil, err
		}
		if !groupExists {
			return nil, nil, nil, nil, repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
		}
		return nil, nil, nil, nil, repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
	}

	const q = "" +
		"SELECT\n" +
		"  e.`id`,\n" +
		"  e.`name`,\n" +
		"  e.`category`,\n" +
		"  CAST(e.`amount` AS CHAR(32)) AS amount,\n" +
		"  CAST(\n" +
		"    CASE\n" +
		"      WHEN balances.`net_amount` > 0 THEN ROUND(balances.`net_amount`, 2)\n" +
		"      ELSE 0.00\n" +
		"    END AS CHAR(32)\n" +
		"  ) AS lent_amount,\n" +
		"  CAST(\n" +
		"    CASE\n" +
		"      WHEN balances.`net_amount` < 0 THEN ROUND(ABS(balances.`net_amount`), 2)\n" +
		"      ELSE 0.00\n" +
		"    END AS CHAR(32)\n" +
		"  ) AS borrow_amount,\n" +
		"  e.`paid_by`,\n" +
		"  u.`username`,\n" +
		"  u.`avatar_version`,\n" +
		"  e.`created_by`,\n" +
		"  e.`occurred_at`,\n" +
		"  e.`created_at`\n" +
		"FROM `expenses` e\n" +
		"LEFT JOIN (\n" +
		"  SELECT\n" +
		"    e_inner.`id` AS expense_id,\n" +
		"    CASE\n" +
		"      WHEN e_inner.`paid_by` = ? THEN e_inner.`amount` - COALESCE(es_inner.`amount`, 0)\n" +
		"      ELSE -COALESCE(es_inner.`amount`, 0)\n" +
		"    END AS net_amount\n" +
		"  FROM `expenses` e_inner\n" +
		"  LEFT JOIN `expense_splits` es_inner ON es_inner.`expense_id` = e_inner.`id`\n" +
		"    AND es_inner.`user_id` = ?\n" +
		") balances ON balances.`expense_id` = e.`id`\n" +
		"JOIN `users` u ON u.`user_id` = e.`paid_by`\n" +
		"WHERE e.`group_id` = ?\n" +
		"ORDER BY e.`occurred_at` DESC, e.`created_at` DESC, e.`id` DESC"

	rows, err := s.db.QueryContext(ctx, q, uid, uid, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, nil, nil, err
		default:
			return nil, nil, nil, nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	expenses := make([]domain.Expense, 0)
	lentAmounts := make([]string, 0)
	borrowAmounts := make([]string, 0)
	users := make([]domain.User, 0)
	for rows.Next() {
		var (
			expense      domain.Expense
			lentAmount   string
			borrowAmount string
			user         domain.User
			occurredAt   time.Time
		)
		if err := rows.Scan(
			&expense.ID,
			&expense.Name,
			&expense.Category,
			&expense.Amount,
			&lentAmount,
			&borrowAmount,
			&expense.PaidBy,
			&user.Username,
			&user.AvatarVersion,
			&expense.CreatedBy,
			&occurredAt,
			&expense.CreatedAt,
		); err != nil {
			switch {
			case ctxx.IsCtxError(err):
				return nil, nil, nil, nil, err
			default:
				return nil, nil, nil, nil, repo.NewError(repo.ErrInternal, err)
			}
		}
		expense.GroupID = groupID
		expense.OccurredAt = &occurredAt
		user.ID = expense.PaidBy

		expenses = append(expenses, expense)
		lentAmounts = append(lentAmounts, lentAmount)
		borrowAmounts = append(borrowAmounts, borrowAmount)
		users = append(users, user)
	}
	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, nil, nil, err
		default:
			return nil, nil, nil, nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return expenses, lentAmounts, borrowAmounts, users, nil
}

func (s *repoStore) Create(ctx context.Context, expense *domain.Expense, splits []domain.ExpenseSplit) error {
	const expenseQ = "" +
		"INSERT INTO `expenses` (\n" +
		"  `id`, `group_id`, `name`, `category`, `amount`, `paid_by`, `is_transaction`,\n" +
		"  `split_method`, `note`, `created_by`, `occurred_at`, `created_at`, `updated_at`\n" +
		") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

	var note any
	if expense.Note != nil {
		note = *expense.Note
	}

	_, err := s.db.ExecContext(
		ctx,
		expenseQ,
		expense.ID,
		expense.GroupID,
		expense.Name,
		expense.Category,
		expense.Amount,
		expense.PaidBy,
		expense.IsTransaction,
		expense.SplitMethod,
		note,
		expense.CreatedBy,
		expense.OccurredAt,
		expense.CreatedAt,
		expense.UpdatedAt,
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

	if len(splits) == 0 {
		return repo.NewError(repo.ErrInternal, errors.New("expense splits are required"))
	}

	var (
		builder strings.Builder
		args    = make([]any, 0, len(splits)*5)
	)
	builder.WriteString("INSERT INTO `expense_splits` (`expense_id`, `group_id`, `user_id`, `amount`, `fixed_amount`) VALUES ")
	for idx, split := range splits {
		if idx > 0 {
			builder.WriteString(",")
		}
		builder.WriteString("(?, ?, ?, ?, ?)")
		var fixedAmount any
		if expense.SplitMethod == expol.SplitFixed && split.FixedAmount != nil {
			fixedAmount = *split.FixedAmount
		}
		args = append(args, split.ExpenseID, split.GroupID, split.UserID, split.Amount, fixedAmount)
	}

	_, err = s.db.ExecContext(ctx, builder.String(), args...)
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

func (s *repoStore) GetDetail(ctx context.Context, expenseID, uid string) (*domain.Expense, error) {
	const q = "" +
		"SELECT\n" +
		"  e.`id`,\n" +
		"  e.`group_id`,\n" +
		"  e.`name`,\n" +
		"  e.`category`,\n" +
		"  CAST(e.`amount` AS CHAR(32)) AS amount,\n" +
		"  e.`paid_by`,\n" +
		"  e.`split_method`,\n" +
		"  e.`note`,\n" +
		"  e.`occurred_at`,\n" +
		"  e.`created_by`,\n" +
		"  e.`created_at`,\n" +
		"  e.`updated_at`,\n" +
		"  es.`user_id`,\n" +
		"  CAST(es.`amount` AS CHAR(32)) AS split_amount,\n" +
		"  CAST(es.`fixed_amount` AS CHAR(32)) AS split_fixed_amount\n" +
		"FROM `expenses` e\n" +
		"JOIN `group_members` gm ON gm.`group_id` = e.`group_id`\n" +
		"  AND gm.`user_id` = ?\n" +
		"JOIN `expense_splits` es ON es.`expense_id` = e.`id`\n" +
		"  AND es.`group_id` = e.`group_id`\n" +
		"WHERE e.`id` = ?\n" +
		"ORDER BY es.`user_id` ASC"

	rows, err := s.db.QueryContext(ctx, q, uid, expenseID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	defer rows.Close()

	var detail *domain.Expense
	for rows.Next() {
		var (
			rowExpense  domain.Expense
			note        sql.NullString
			splitFixed  sql.NullString
			occurredAt  time.Time
			participant domain.Participant
		)
		if err := rows.Scan(
			&rowExpense.ID,
			&rowExpense.GroupID,
			&rowExpense.Name,
			&rowExpense.Category,
			&rowExpense.Amount,
			&rowExpense.PaidBy,
			&rowExpense.SplitMethod,
			&note,
			&occurredAt,
			&rowExpense.CreatedBy,
			&rowExpense.CreatedAt,
			&rowExpense.UpdatedAt,
			&participant.UserID,
			&participant.Amount,
			&splitFixed,
		); err != nil {
			switch {
			case ctxx.IsCtxError(err):
				return nil, err
			default:
				return nil, repo.NewError(repo.ErrInternal, err)
			}
		}

		if detail == nil {
			if note.Valid {
				rowExpense.Note = &note.String
			}
			rowExpense.OccurredAt = &occurredAt
			rowExpense.Participants = make([]domain.Participant, 0, 4)
			detail = &rowExpense
		}
		if splitFixed.Valid {
			participant.FixedAmount = &splitFixed.String
		}
		detail.Participants = append(detail.Participants, participant)
	}
	if err := rows.Err(); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}
	if detail == nil {
		return nil, s.expenseAccessError(ctx, expenseID, uid, sql.ErrNoRows)
	}

	return detail, nil
}

func (s *repoStore) Update(ctx context.Context, uid string, expense *domain.Expense, splits []domain.ExpenseSplit) error {
	const expenseQ = "" +
		"UPDATE `expenses` e\n" +
		"JOIN `group_members` gm ON gm.`group_id` = e.`group_id`\n" +
		"  AND gm.`user_id` = ?\n" +
		"SET e.`name` = ?,\n" +
		"    e.`category` = ?,\n" +
		"    e.`amount` = ?,\n" +
		"    e.`paid_by` = ?,\n" +
		"    e.`is_transaction` = ?,\n" +
		"    e.`split_method` = ?,\n" +
		"    e.`note` = ?,\n" +
		"    e.`occurred_at` = ?,\n" +
		"    e.`updated_at` = ?\n" +
		"WHERE e.`id` = ?"

	var note any
	if expense.Note != nil {
		note = *expense.Note
	}

	res, err := s.db.ExecContext(
		ctx,
		expenseQ,
		uid,
		expense.Name,
		expense.Category,
		expense.Amount,
		expense.PaidBy,
		expense.IsTransaction,
		expense.SplitMethod,
		note,
		expense.OccurredAt,
		expense.UpdatedAt,
		expense.ID,
	)
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
		switch {
		case ctxx.IsCtxError(err):
			return err
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}
	if affected == 0 {
		return s.expenseAccessError(ctx, expense.ID, uid, sql.ErrNoRows)
	}

	if _, err := s.db.ExecContext(ctx, "DELETE FROM `expense_splits` WHERE `expense_id` = ?", expense.ID); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	if len(splits) == 0 {
		return repo.NewError(repo.ErrInternal, errors.New("expense splits are required"))
	}

	var (
		builder strings.Builder
		args    = make([]any, 0, len(splits)*5)
	)
	builder.WriteString("INSERT INTO `expense_splits` (`expense_id`, `group_id`, `user_id`, `amount`, `fixed_amount`) VALUES ")
	for idx, split := range splits {
		if idx > 0 {
			builder.WriteString(",")
		}
		builder.WriteString("(?, ?, ?, ?, ?)")
		var fixedAmount any
		if expense.SplitMethod == expol.SplitFixed && split.FixedAmount != nil {
			fixedAmount = *split.FixedAmount
		}
		args = append(args, split.ExpenseID, split.GroupID, split.UserID, split.Amount, fixedAmount)
	}

	if _, err := s.db.ExecContext(ctx, builder.String(), args...); err != nil {
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

func (s *repoStore) Delete(ctx context.Context, expenseID, uid string) error {
	const q = "" +
		"DELETE e\n" +
		"FROM `expenses` e\n" +
		"JOIN `group_members` gm ON gm.`group_id` = e.`group_id`\n" +
		"  AND gm.`user_id` = ?\n" +
		"WHERE e.`id` = ?"

	res, err := s.db.ExecContext(ctx, q, uid, expenseID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case repo.IsFKDeleteParent(err), repo.IsFKConstraint(err):
			return repo.NewError(repo.ErrConflict, err)
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	affected, err := res.RowsAffected()
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}
	if affected == 0 {
		return s.expenseAccessError(ctx, expenseID, uid, sql.ErrNoRows)
	}

	return nil
}

func (s *repoStore) expenseAccessError(ctx context.Context, expenseID, uid string, cause error) error {
	exists, err := s.exists(ctx, "SELECT 1 FROM `expenses` WHERE `id` = ?", expenseID)
	if err != nil {
		return err
	}
	if !exists {
		return repo.NewError(repo.ErrNotFound, cause)
	}

	allowed, err := s.exists(
		ctx,
		"SELECT 1 FROM `expenses` e JOIN `group_members` gm ON gm.`group_id` = e.`group_id` AND gm.`user_id` = ? WHERE e.`id` = ?",
		uid,
		expenseID,
	)
	if err != nil {
		return err
	}
	if !allowed {
		return repo.NewError(repo.ErrUnauthorized, cause)
	}

	return repo.NewError(repo.ErrInternal, cause)
}
