package friend

import (
	"github.com/brojyf/CoLiz/internal/infra/notif"
	"github.com/brojyf/CoLiz/internal/service/friend"
)

type Handler struct {
	svc      friend.Service
	notifier *notif.Notifier
}

func NewHandler(svc friend.Service, notifier *notif.Notifier) *Handler {
	return &Handler{svc: svc, notifier: notifier}
}
