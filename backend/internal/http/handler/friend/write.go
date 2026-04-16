package friend

import (
	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

type sendRequestReq struct {
	To  string `json:"to" binding:"required,uuid"`
	Msg string `json:"msg" binding:"required,min=1,max=64"`
}

func (h *Handler) Delete(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}

	friendID := c.Param("uid")
	if !uuidx.IsV7(friendID) || friendID == uid {
		httpx.WriteBadRequest(c)
		return
	}

	err := h.svc.Delete(ctx, uid, friendID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 204, nil)
}

func (h *Handler) SendRequest(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	
	var req sendRequestReq
	if err := c.ShouldBindJSON(&req); err != nil { httpx.WriteBadRequest(c); return }
	tool.Norm(&req, "Msg")

	if !tool.NormAndChecMessage(&req.Msg) || !uuidx.IsV7(req.To) || req.To == uid { 
		httpx.WriteBadRequest(c); return 
	}

	friendReq, err := domain.NewFriendRequest(
		domain.WithFromUser(uid),
		domain.WithToUser(req.To),
		domain.WithFriendRequestMessage(req.Msg),
	)
	if err != nil { httpx.WriteInternal(c); return }

	err = h.svc.SendRequest(ctx, friendReq)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	go h.notifier.NotifyFriendRequest(friendReq)

	httpx.WriteJSON(c, 201, nil)
}

func (h *Handler) AcceptRequest(c *gin.Context) {
	ctx := c.Request.Context()

	requestID := c.Param("request_id")
	if !uuidx.IsV7(requestID) {
		httpx.WriteBadRequest(c)
		return
	}

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}

	err := h.svc.Accept(ctx, requestID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, nil)
}

func (h *Handler) DeclineRequest(c *gin.Context) {
	ctx := c.Request.Context()

	rid := c.Param("request_id")
	if !uuidx.IsV7(rid) {
		httpx.WriteBadRequest(c)
		return
	}

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
		return
	}

	err := h.svc.Decline(ctx, rid, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, nil)
}

func (h *Handler) CancelRequest(c *gin.Context) {
	ctx := c.Request.Context()

	requestID := c.Param("request_id")
	if !uuidx.IsV7(requestID) {
		httpx.WriteBadRequest(c)
		return
	}

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
		return
	}

	err := h.svc.CancelRequest(ctx, requestID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, nil)
}
