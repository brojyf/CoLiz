package todo

import (
	"github.com/brojyf/CoLiz/internal/infra/notif"
	"github.com/brojyf/CoLiz/internal/service/todo"
)

type Handler struct {
	svc      todo.Service
	notifier *notif.Notifier
}

func NewHandler(svc todo.Service, notifier *notif.Notifier) *Handler {
	return &Handler{svc: svc, notifier: notifier}
}

