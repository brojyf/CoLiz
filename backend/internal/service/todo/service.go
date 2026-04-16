package todo

import (
	"context"
	"database/sql"
	"errors"

	"github.com/brojyf/CoLiz/internal/domain"
	txinfra "github.com/brojyf/CoLiz/internal/infra/tx"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/repo/todo"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

type Service interface {
	Get(ctx context.Context, uid string) ([]domain.Todo, error)
	GetGroup(ctx context.Context, gid, uid string) ([]domain.Todo, error)
	GetDetail(ctx context.Context, tid, uid string) (*domain.Todo, error)
	Create(ctx context.Context, todo *domain.Todo) (*domain.Todo, error)
	Update(ctx context.Context, tid, uid, message string) (*domain.Todo, error)
	Mark(ctx context.Context, done bool, tid, uid string) (*domain.Todo, error)
	Delete(ctx context.Context, tid, uid string) error
}

type service struct {
	repo todo.Repo
	tx   *txinfra.Transactor
}

func NewService(r todo.Repo, t *txinfra.Transactor) Service {
	return &service{repo: r, tx: t}
}

func (s *service) Get(ctx context.Context, uid string) ([]domain.Todo, error) {
	todos, err := s.repo.Get(ctx, uid)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return nil, err
		}
		logx.Error(ctx, "todo.get", err)
		return nil, svc.ErrInternal
	}
	return todos, nil
}

func (s *service) GetGroup(ctx context.Context, gid, uid string) ([]domain.Todo, error) {
	todos, err := s.repo.GetByGroup(ctx, gid, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "todo.getGroup", err)
			return nil, svc.ErrInternal
		}
	}
	return todos, nil
}

func (s *service) GetDetail(ctx context.Context, tid, uid string) (*domain.Todo, error) {
	todo, err := s.repo.GetDetail(ctx, tid, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "todo.getDetail", err)
			return nil, svc.ErrInternal
		}
	}
	return todo, nil
}

func (s *service) Create(ctx context.Context, todo *domain.Todo) (*domain.Todo, error) {
	todo, err := s.repo.Create(ctx, todo)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "todo.create", err)
			return nil, svc.ErrInternal
		}
	}

	return todo, nil
}

func (s *service) Update(ctx context.Context, tid, uid, message string) (*domain.Todo, error) {
	todo, err := domain.NewTodo(domain.WithTodoID(tid), domain.WithMessage(message))
	if err != nil {
		logx.Error(ctx, "todo.update", err)
		return nil, svc.ErrInternal
	}

	err = s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		var innerErr error
		todo, innerErr = store.Update(ctx, todo, uid)
		return innerErr
	})
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "todo.update", err)
			return nil, svc.ErrInternal
		}
	}

	return todo, nil
}

func (s *service) Mark(ctx context.Context, done bool, tid, uid string) (*domain.Todo, error) {
	todo, err := domain.NewTodo(
		domain.WithTodoID(tid),
		domain.WithDone(done),
	)
	if err != nil {
		logx.Error(ctx, "todo.mark", err)
		return nil, svc.ErrInternal
	}

	err = s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		var innerErr error
		todo, innerErr = store.Mark(ctx, todo, uid)
		return innerErr
	})
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "todo.mark", err)
			return nil, svc.ErrInternal
		}
	}

	return todo, nil
}

func (s *service) Delete(ctx context.Context, tid, uid string) error {
	err := s.repo.Delete(ctx, tid, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrNotFound):
			return svc.ErrNotFound
		case errors.Is(err, repo.ErrUnauthorized):
			return svc.ErrUnauthorized
		default:
			logx.Error(ctx, "todo.delete", err)
			return svc.ErrInternal
		}
	}
	return nil
}
