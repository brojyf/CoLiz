package auth

import (
	"github.com/brojyf/CoLiz/internal/service/auth"
)

type Handler struct {
	svc auth.Service
}

func NewHandler(svc auth.Service) *Handler {
	return &Handler{svc: svc}
}
