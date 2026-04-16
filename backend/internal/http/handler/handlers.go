package handler

import (
	"github.com/brojyf/CoLiz/internal/http/handler/auth"
	"github.com/brojyf/CoLiz/internal/http/handler/expense"
	"github.com/brojyf/CoLiz/internal/http/handler/friend"
	"github.com/brojyf/CoLiz/internal/http/handler/group"
	"github.com/brojyf/CoLiz/internal/http/handler/todo"
	"github.com/brojyf/CoLiz/internal/http/handler/user"
)

type Handlers struct {
	Auth    *auth.Handler
	Expense *expense.Handler
	User    *user.Handler
	Friend  *friend.Handler
	Group   *group.Handler
	Todo    *todo.Handler
}
