package expense

import (
	"github.com/brojyf/CoLiz/internal/infra/notif"
	expensesvc "github.com/brojyf/CoLiz/internal/service/expense"
)

type Handler struct {
	svc      expensesvc.Service
	notifier *notif.Notifier
}

func NewHandler(svc expensesvc.Service, notifier *notif.Notifier) *Handler {
	return &Handler{svc: svc, notifier: notifier}
}
