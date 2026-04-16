package auth

import (
	"strings"

	"github.com/brojyf/CoLiz/internal/service/auth"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

type setPasswordReq struct {
	TicketID string `json:"ticket_id" binding:"required"`
	DeviceID string `json:"device_id" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type loginReq struct {
	Email    string `json:"email" binding:"required"`
	DeviceID string `json:"device_id" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
	DeviceID     string `json:"device_id" binding:"required"`
}

type changePwdReq struct {
	Old string `json:"old" binding:"required"`
	New string `json:"new" binding:"required"`
}

func (h *Handler) Register(c *gin.Context) {
	ctx := c.Request.Context()

	var req setPasswordReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	tool.Norm(&req, "Password")
	if !isUUIDv4(req.TicketID) || !isUUIDv4(req.DeviceID) {
		httpx.WriteBadRequest(c)
		return
	}

	ok := tool.NormAndCheckPwd(&req.Password)
	if !ok {
		httpx.WriteBadRequest(c)
		return
	}

	p := auth.SetPwdParam{
		DeviceID: req.DeviceID,
		Password: req.Password,
		TicketID: req.TicketID,
	}
	tokens, err := h.svc.Register(ctx, p)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 201, tokens.ToDTO())
}

func (h *Handler) ResetPassword(c *gin.Context) {
	ctx := c.Request.Context()

	var req setPasswordReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	tool.Norm(&req, "Password")
	if !isUUIDv4(req.TicketID) || !isUUIDv4(req.DeviceID) {
		httpx.WriteBadRequest(c)
		return
	}

	ok := tool.NormAndCheckPwd(&req.Password)
	if !ok {
		httpx.WriteBadRequest(c)
		return
	}

	p := auth.SetPwdParam{
		DeviceID: req.DeviceID,
		Password: req.Password,
		TicketID: req.TicketID,
	}
	tokens, err := h.svc.ResetPwd(ctx, p)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, tokens.ToDTO())
}

func (h *Handler) Login(c *gin.Context) {
	ctx := c.Request.Context()

	var req loginReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	tool.Norm(&req, "Password")
	if !isValidEmail(req.Email) || !isUUIDv4(req.DeviceID) {
		httpx.WriteBadRequest(c)
		return
	}

	ok := tool.NormAndCheckPwd(&req.Password)
	if !ok {
		httpx.WriteBadRequest(c)
		return
	}

	p := auth.LoginParam{
		Email:    req.Email,
		DeviceID: req.DeviceID,
		Password: req.Password,
	}
	tokens, err := h.svc.Login(ctx, p)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, tokens.ToDTO())
}

func (h *Handler) Logout(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}

	err := h.svc.Logout(ctx, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 204, nil)
}

func (h *Handler) Refresh(c *gin.Context) {
	ctx := c.Request.Context()

	var req refreshReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	tool.Norm(&req, "RefreshToken")
	req.RefreshToken = strings.TrimSpace(req.RefreshToken)
	if !isValidRefreshToken(req.RefreshToken) || !uuidx.IsV4(req.DeviceID) {
		httpx.WriteBadRequest(c)
		return
	}

	tokens, err := h.svc.Refresh(ctx, req.RefreshToken, req.DeviceID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, tokens.ToDTO())
}

func (h *Handler) ChangePassword(c *gin.Context) {
	ctx := c.Request.Context()

	var req changePwdReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}

	oldOK := tool.NormAndCheckPwd(&req.Old)
	newOK := tool.NormAndCheckPwd(&req.New)
	if !oldOK || !newOK {
		httpx.WriteBadRequest(c)
		return
	}

	tokens, err := h.svc.ChangePassword(ctx, uid, req.Old, req.New)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, tokens.ToDTO())
}
