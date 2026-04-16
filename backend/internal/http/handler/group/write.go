package group

import (
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

type createGroupReq struct {
	GroupName string `json:"group_name" binding:"required,min=1,max=32"`
}

type updateGroupReq struct {
	GroupName string `json:"group_name" binding:"required,min=1,max=32"`
}

type inviteGroupReq struct {
	UserID string `json:"user_id" binding:"required,uuid"`
}

func (h *Handler) Create(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	var req createGroupReq
	if err := c.ShouldBindJSON(&req); err != nil { httpx.WriteBadRequest(c); return }

	ok := tool.NormAndCheckName(&req.GroupName)
	if !ok { httpx.WriteBadRequest(c); return }

	group, err := h.svc.Create(c.Request.Context(), uid, req.GroupName)
	if err != nil { httpx.SmartError(c, err); return }

	httpx.WriteJSON(c, 201, group.ToGroupDTOFor(uid))
}

func (h *Handler) Update(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) { httpx.WriteBadRequest(c); return }

	var req updateGroupReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	ok := tool.NormAndCheckName(&req.GroupName)
	if !ok { httpx.WriteBadRequest(c); return }

	group, err := h.svc.UpdateName(c.Request.Context(), groupID, uid, req.GroupName)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, group.ToGroupDTOFor(uid))
}

func (h *Handler) Delete(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) { httpx.WriteBadRequest(c); return }

	err := h.svc.Delete(c.Request.Context(), groupID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 204, nil)
}

func (h *Handler) Invite(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) { httpx.WriteBadRequest(c); return }

	var req inviteGroupReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c); return
	}

	if uid == req.UserID || !uuidx.IsV7(req.UserID) {
		httpx.WriteBadRequest(c); return
	}

	err := h.svc.Invite(c.Request.Context(), groupID, uid, req.UserID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	go h.notifier.NotifyGroupInvited(groupID, uid, req.UserID)

	httpx.WriteJSON(c, 200, nil)
}

func (h *Handler) Leave(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) { httpx.WriteBadRequest(c); return }

	err := h.svc.Leave(c.Request.Context(), groupID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 204, nil)
}

func (h *Handler) RemoveMember(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	groupID := c.Param("group_id")
	targetUserID := c.Param("uid")
	if !uuidx.IsV7(groupID) || !uuidx.IsV7(targetUserID) {
		httpx.WriteBadRequest(c); return
	}

	err := h.svc.RemoveMember(c.Request.Context(), groupID, uid, targetUserID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 204, nil)
}
