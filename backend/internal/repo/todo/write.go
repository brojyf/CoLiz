package todo

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
)

func (s *repoStore) Create(ctx context.Context, t *domain.Todo) (*domain.Todo, error) {
	const q = `
		INSERT INTO todos (
		  id, group_id, message, created_by, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?)
	`

	_, err := s.db.ExecContext(ctx, q, t.ID, t.GroupID, t.Message, t.CreatedBy, t.CreatedAt, t.UpdatedAt)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsDuplicateEntry(err):
			return nil, repo.NewError(repo.ErrConflict, err)
		case repo.IsFKConstraint(err):
			groupExists, existsErr := s.exists(ctx, "SELECT 1 FROM `groups` WHERE `id` = ?", t.GroupID)
			if existsErr != nil {
				return nil, existsErr
			}
			if !groupExists {
				return nil, repo.NewError(repo.ErrNotFound, sql.ErrNoRows)
			}

			allowed, existsErr := s.exists(
				ctx,
				"SELECT 1 FROM group_members WHERE group_id = ? AND user_id = ?",
				t.GroupID,
				t.CreatedBy,
			)
			if existsErr != nil {
				return nil, existsErr
			}
			if !allowed {
				return nil, repo.NewError(repo.ErrUnauthorized, sql.ErrNoRows)
			}

			return nil, repo.NewError(repo.ErrInternal, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return t, nil
}

func (s *repoStore) Update(ctx context.Context, t *domain.Todo, uid string) (*domain.Todo, error) {
	const updateQ = `
		UPDATE todos t
		JOIN group_members gm
		  ON gm.group_id = t.group_id
		  AND gm.user_id = ?
		SET t.message = ?, t.updated_at = NOW()
		WHERE t.id = ?
	`
	const getQ = `
		SELECT t.id, t.group_id, t.message, t.done, t.created_by, u.username, t.updated_at, t.created_at
		FROM todos t
		JOIN users u ON u.user_id = t.created_by
		JOIN group_members gm
		  ON gm.group_id = t.group_id
		  AND gm.user_id = ?
		WHERE t.id = ?
		LIMIT 1
`

	_, err := s.db.ExecContext(ctx, updateQ, uid, t.Message, t.ID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsFKConstraint(err):
			return nil, repo.NewError(repo.ErrUnauthorized, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	var out domain.Todo
	err = s.db.QueryRowContext(ctx, getQ, uid, t.ID).Scan(
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
			return nil, s.todoAccessError(ctx, t.ID, uid, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return &out, nil
}

func (s *repoStore) Mark(ctx context.Context, t *domain.Todo, uid string) (*domain.Todo, error) {
	const updateQ = `
		UPDATE todos t
		JOIN group_members gm
		  ON gm.group_id = t.group_id
		  AND gm.user_id = ?
		SET t.done = ?
		WHERE t.id = ?
	`
	const getQ = `
		SELECT t.id, t.group_id, t.message, t.done, t.created_by, u.username, t.updated_at, t.created_at
		FROM todos t
		JOIN users u ON u.user_id = t.created_by
		JOIN group_members gm
		  ON gm.group_id = t.group_id
		  AND gm.user_id = ?
		WHERE t.id = ?
		LIMIT 1
`

	doneVal := 0
	if t.Done {
		doneVal = 1
	}

	_, err := s.db.ExecContext(ctx, updateQ, uid, doneVal, t.ID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case repo.IsFKConstraint(err):
			return nil, repo.NewError(repo.ErrUnauthorized, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	var out domain.Todo
	err = s.db.QueryRowContext(ctx, getQ, uid, t.ID).Scan(
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
			return nil, s.todoAccessError(ctx, t.ID, uid, err)
		default:
			return nil, repo.NewError(repo.ErrInternal, err)
		}
	}

	return &out, nil
}

func (s *repoStore) Delete(ctx context.Context, tid, uid string) error {
	const q = `
		DELETE t
		FROM todos t
		JOIN group_members gm
		  ON gm.group_id = t.group_id
		  AND gm.user_id = ?
		WHERE t.id = ?
	`
	res, err := s.db.ExecContext(ctx, q, uid, tid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case repo.IsFKConstraint(err) || repo.IsFKDeleteParent(err):
			return repo.NewError(repo.ErrConflict, err)
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	affected, err := res.RowsAffected()
	if err != nil {
		return repo.NewError(repo.ErrInternal, err)
	}
	if affected == 0 {
		return s.todoAccessError(ctx, tid, uid, sql.ErrNoRows)
	}

	return nil
}
