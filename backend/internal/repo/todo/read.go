package todo

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s *repoStore) Get(ctx context.Context, uid string) ([]domain.Todo, error) {
	const q = `
		SELECT t.id, t.group_id, t.message, t.done, t.created_by, u.username, t.updated_at, t.created_at
		FROM todos t
		JOIN users u ON u.user_id = t.created_by
		JOIN group_members gm ON gm.group_id = t.group_id 
	      AND gm.user_id = ?
	`
	rows, err := s.db.QueryContext(ctx, q, uid)
	if err != nil {
		if ctxx.IsCtxError(err) { return nil, err }
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	defer rows.Close()

	todos := make([]domain.Todo, 0)
	for rows.Next() {
		var t domain.Todo
		if err := rows.Scan(&t.ID, &t.GroupID, &t.Message, &t.Done, &t.CreatedBy, &t.CreatedByName, &t.UpdatedAt, &t.CreatedAt); err != nil {
			return nil, repo.NewError(repo.ErrInternal, err)
		}
		todos = append(todos, t)
	}
	if err := rows.Err(); err != nil {
		if ctxx.IsCtxError(err) { return nil, err }
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	return todos, nil
}

func (s *repoStore) GetDetail(ctx context.Context, tid, uid string) (*domain.Todo, error) {
	const q = `
		SELECT t.id, t.group_id, t.message, t.done, t.created_by, u.username, t.updated_at, t.created_at
		FROM todos t
		JOIN users u ON u.user_id = t.created_by
		JOIN group_members gm
		  ON gm.group_id = t.group_id
		  AND gm.user_id = ?
		WHERE t.id = ?
		LIMIT 1
	`

	var out domain.Todo
	err := s.db.QueryRowContext(ctx, q, uid, tid).Scan(
		&out.ID,
		&out.GroupID,
		&out.Message,
		&out.Done,
		&out.CreatedBy,
		&out.CreatedByName,
		&out.UpdatedAt,
		&out.CreatedAt,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err): 
			return nil, err
		case repo.IsNoRows(err): 
			return nil, s.todoAccessError(ctx, tid, uid, err)
		default: 
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return &out, nil
}

func (s *repoStore) GetByGroup(ctx context.Context, gid, uid string) ([]domain.Todo, error) {
	allowed, err := s.exists(
		ctx,
		"SELECT 1 FROM group_members WHERE group_id = ? AND user_id = ?",
		gid,
		uid,
	)
	if err != nil { return nil, err }
	if !allowed {
		groupExists, err := s.exists(ctx, "SELECT 1 FROM `groups` WHERE `id` = ?", gid)
		if err != nil { return nil, err }
		if !groupExists { return nil, repo.NewError(repo.ErrNotFound, sql.ErrNoRows) }
		return nil, repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
	}

	const q = `
		SELECT t.id, t.group_id, t.message, t.done, t.created_by, u.username, t.updated_at, t.created_at
		FROM todos t
		JOIN users u ON u.user_id = t.created_by
		WHERE t.group_id = ?
		ORDER BY t.updated_at DESC, t.created_at DESC, t.id DESC
	`

	rows, err := s.db.QueryContext(ctx, q, gid)
	if err != nil {
		if ctxx.IsCtxError(err) { return nil, err }
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	defer rows.Close()

	todos := make([]domain.Todo, 0)
	for rows.Next() {
		var t domain.Todo
		if err := rows.Scan(&t.ID, &t.GroupID, &t.Message, &t.Done, &t.CreatedBy, &t.CreatedByName, &t.UpdatedAt, &t.CreatedAt); err != nil {
			if ctxx.IsCtxError(err) { return nil, err }
			return nil, repo.NewError(repo.ErrInternal, err)
		}
		todos = append(todos, t)
	}
	if err := rows.Err(); err != nil {
		if ctxx.IsCtxError(err) { return nil, err }
		return nil, repo.NewError(repo.ErrInternal, err)
	}

	return todos, nil
}

// Helpe methods
func (s *repoStore) todoAccessError(ctx context.Context, tid, uid string, cause error) error {
	exists, err := s.exists(ctx, "SELECT 1 FROM todos WHERE id = ?", tid)
	if err != nil { return err }
	if !exists { return repo.NewError(repo.ErrNotFound, cause) }

	allowed, err := s.exists(
		ctx,
		`SELECT 1
		FROM todos t
		JOIN group_members gm
		  ON gm.group_id = t.group_id
		 AND gm.user_id = ?
		WHERE t.id = ?`,
		uid,
		tid,
	)
	if err != nil { return err }
	if !allowed { return repo.NewError(repo.ErrUnauthorized, cause) }

	return repo.NewError(repo.ErrInternal, cause)
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
