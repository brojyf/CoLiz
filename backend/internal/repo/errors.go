package repo

import (
	"database/sql"
	"errors"
	"fmt"

	"github.com/go-sql-driver/mysql"
)

var (
	ErrInvalidInput = errors.New("invalid input")
	ErrUnauthorized = errors.New("unauthorized")
	ErrRateLimit    = errors.New("rate limit exceeded")
	ErrConflict     = errors.New("conflict")
	ErrNotFound     = errors.New("not found")
	ErrInternal     = errors.New("internal error")
)

const (
	ErrDuplicateEntry uint16 = 1062
	ErrFKDeleteParent uint16 = 1451
	ErrFKConstraint   uint16 = 1452
	ErrDBConflict     uint16 = 1644
)

func NewError(sentinel, err error) error {
	if err == nil {
		return sentinel
	}
	return fmt.Errorf("%w:%s", sentinel, err)
}

func IsNoRows(err error) bool {
	return errors.Is(err, sql.ErrNoRows)
}

func IsNotFound(err error) bool {
	return errors.Is(err, ErrNotFound)
}

// Driver Error
func IsDuplicateEntry(err error) bool {
	var me *mysql.MySQLError
	return errors.As(err, &me) && me.Number == ErrDuplicateEntry
}

func IsFKDeleteParent(err error) bool {
	var me *mysql.MySQLError
	return errors.As(err, &me) && me.Number == ErrFKDeleteParent
}

func IsFKConstraint(err error) bool {
	var me *mysql.MySQLError
	return errors.As(err, &me) && me.Number == ErrFKConstraint
}

func IsConflict(err error) bool {
	var me *mysql.MySQLError
	return errors.As(err, &me) && me.Number == ErrDBConflict
}
