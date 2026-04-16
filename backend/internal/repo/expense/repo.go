package expense

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
)

type Repo interface {
	BeginTx(tx *sql.Tx) Repo
	GetOverview(ctx context.Context, uid string) ([]domain.Group, []string, []string, error)
	GetGroupExpense(ctx context.Context, uid, groupID string) (*domain.Group, string, string, error)
	LockGroup(ctx context.Context, uid, groupID string) error
	GetGroupMemberBalances(ctx context.Context, uid, groupID string) (*domain.Group, []domain.MemberNetBalance, error)
	GetGroupExpenseHistory(ctx context.Context, groupID, uid string) ([]domain.Expense, []string, []string, []domain.User, error)
	GetGroupMemberIDs(ctx context.Context, groupID string) (map[string]struct{}, error)
	Create(ctx context.Context, expense *domain.Expense, splits []domain.ExpenseSplit) error
	GetDetail(ctx context.Context, expenseID, uid string) (*domain.Expense, error)
	Update(ctx context.Context, uid string, expense *domain.Expense, splits []domain.ExpenseSplit) error
	Delete(ctx context.Context, expenseID, uid string) error
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
