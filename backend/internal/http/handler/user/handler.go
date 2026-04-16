package user

import (
	"net/http"
	"strings"

	"github.com/brojyf/CoLiz/internal/policy/avpol"
	devicerepo "github.com/brojyf/CoLiz/internal/repo/device"
	usersvc "github.com/brojyf/CoLiz/internal/service/user"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/brojyf/CoLiz/internal/util/uuidx"

	"github.com/gin-gonic/gin"
)

type updateUsernamerReq struct {
	Username string `json:"username" binding:"required,min=1,max=32"`
}

type Handler struct {
	svc        usersvc.Service
	deviceRepo devicerepo.Repo
}

func NewHandler(svc usersvc.Service, deviceRepo devicerepo.Repo) *Handler {
	return &Handler{svc: svc, deviceRepo: deviceRepo}
}

func (h *Handler) GetAvatar(c *gin.Context) {
	ctx := c.Request.Context()

	targetUID := c.Param("user_id")
	if targetUID == "" {
		targetUID = c.GetString("uid")
		if targetUID == "" {
			httpx.WriteUnauthorized(c); return
		}
	}
	if !uuidx.IsV7(targetUID) {
		httpx.WriteBadRequest(c)
		return
	}

	asset, err := h.svc.ResolveAvatar(ctx, targetUID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}
	defer asset.Content.Close()

	httpx.ServeAsset(c, asset)
}

func (h *Handler) GetMe(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c); return
	}

	user, err := h.svc.GetProfile(c.Request.Context(), uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, user.ToUserProfileDTO())
}

func (h *Handler) UpdateUsername(c *gin.Context) {
	var req updateUsernamerReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}

	ok := tool.NormAndCheckName(&req.Username)
	if !ok {
		httpx.WriteBadRequest(c)
		return
	}

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c); return
	}

	user, err := h.svc.UpdateUsername(c.Request.Context(), uid, req.Username)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, user.ToUserProfileDTO())
}

func (h *Handler) SearchByEmail(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c); return
	}

	email := c.Query("email")
	if email == "" {
		httpx.WriteBadRequest(c)
		return
	}
	email = strings.ToLower(strings.TrimSpace(email))

	user, err := h.svc.SearchByEmail(ctx, email)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, user.ToUserProfileDTO())
}

func (h *Handler) UploadAvatar(c *gin.Context) {

	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, avpol.MaxBytes)
	if err := c.Request.ParseMultipartForm(avpol.MaxBytes); err != nil {
		httpx.WriteBadRequest(c); return
	}
	if form := c.Request.MultipartForm; form != nil {
		defer form.RemoveAll()
	}

	fileHeader, err := c.FormFile("avatar")
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}

	file, err := tool.OpenMultipartFile(fileHeader)
	if err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	defer file.Close()

	user, err := h.svc.UploadAvatar(c.Request.Context(), uid, file)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, user.ToUserProfileDTO())
}
