package auth

import (
	"github.com/brojyf/CoLiz/internal/service/auth"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/gin-gonic/gin"
)

type requestCodeReq struct {
	Email string `json:"email" binding:"required"`
	Scene string `json:"scene" binding:"required"`
}

type requestCodeResp struct {
	CodeID string `json:"code_id" binding:"required,len=36,uuid4"`
}

type verifyCodeReq struct {
	Email    string `json:"email" binding:"required"`
	Scene    string `json:"scene" binding:"required"`
	OTP      string `json:"otp" binding:"required"`
	CodeID   string `json:"code_id" binding:"required"`
	DeviceID string `json:"device_id" binding:"required"`
}

type verifyCodeResp struct {
	TicketID string `json:"ticket_id"`
}

func (h *Handler) RequestOTP(c *gin.Context) {
	ctx := c.Request.Context()

	var req requestCodeReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	tool.Norm(&req)
	if !isValidEmail(req.Email) || !isValidScene(req.Scene) {
		httpx.WriteBadRequest(c)
		return
	}

	codeID, err := h.svc.RequestOTP(ctx, req.Email, req.Scene)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, &requestCodeResp{
		CodeID: codeID,
	})
}

func (h *Handler) VerifyOTP(c *gin.Context) {
	ctx := c.Request.Context()

	var req verifyCodeReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	tool.Norm(&req)
	if !isValidEmail(req.Email) || !isValidScene(req.Scene) || !isValidOTP(req.OTP) {
		httpx.WriteBadRequest(c)
		return
	}
	if !isUUIDv4(req.CodeID) || !isUUIDv4(req.DeviceID) {
		httpx.WriteBadRequest(c)
		return
	}

	p := auth.VerifyOTPParam{
		CodeID:   req.CodeID,
		Email:    req.Email,
		Scene:    req.Scene,
		OTP:      req.OTP,
		DeviceID: req.DeviceID,
	}
	ticketID, err := h.svc.VerifyOTP(ctx, p)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, verifyCodeResp{
		TicketID: ticketID,
	})
}
