package auth

import (
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/gin-gonic/gin"
)

func (h *Handler) Ping(c *gin.Context) {
	httpx.WriteJSON(c, 200, "pong")
}
