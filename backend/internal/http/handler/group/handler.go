package group

import (
	"github.com/brojyf/CoLiz/internal/infra/notif"
	"github.com/brojyf/CoLiz/internal/service/group"
)

type Handler struct {
	svc      group.Service
	notifier *notif.Notifier
}

func NewHandler(svc group.Service, notifier *notif.Notifier) *Handler {
	return &Handler{svc: svc, notifier: notifier}
}
