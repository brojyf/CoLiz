package user

import (
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/gin-gonic/gin"
)

type upsertDeviceTokenReq struct {
	Token string `json:"token" binding:"required,min=32,max=200"`
}

func (h *Handler) UpsertDeviceToken(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}

	var req upsertDeviceTokenReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c)
		return
	}

	if err := h.deviceRepo.Upsert(c.Request.Context(), uid, req.Token); err != nil {
		httpx.WriteInternal(c)
		return
	}

	httpx.WriteJSON(c, 204, nil)
}
