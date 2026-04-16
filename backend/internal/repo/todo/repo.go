package todo

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
)

type Repo interface {
	BeginTx(tx *sql.Tx) Repo
	Get(ctx context.Context, uid string) ([]domain.Todo, error)
	GetByGroup(ctx context.Context, gid, uid string) ([]domain.Todo, error)
	GetDetail(ctx context.Context, tid, uid string) (*domain.Todo, error)
	Create(ctx context.Context, t *domain.Todo) (*domain.Todo, error)
	Update(ctx context.Context, t *domain.Todo, uid string) (*domain.Todo, error)
	Mark(ctx context.Context, t *domain.Todo, uid string) (*domain.Todo, error)
	Delete(ctx context.Context, tid, uid string) error
}

type repoStore struct {
	db repo.DBTX
}

func NewRepo(db repo.DBTX) Repo {
	return &repoStore{db: db}
}

func (s *repoStore) BeginTx(tx *sql.Tx) Repo {
	return &repoStore{db: tx}
}
