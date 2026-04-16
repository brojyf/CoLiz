package group

import (
	"net/http"

	"github.com/brojyf/CoLiz/internal/policy/avpol"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

func (h *Handler) GetAvatar(c *gin.Context) {
	ctx := c.Request.Context()

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c)
		return
	}

	asset, err := h.svc.ResolveAvatar(ctx, groupID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}
	defer asset.Content.Close()

	httpx.ServeAsset(c, asset)
}

func (h *Handler) UploadAvatar(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) { httpx.WriteBadRequest(c); return }

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, avpol.MaxBytes)
	if err := c.Request.ParseMultipartForm(avpol.MaxBytes); err != nil {
		httpx.WriteBadRequest(c); return
	}
	if form := c.Request.MultipartForm; form != nil {
		defer form.RemoveAll()
	}

	fileHeader, err := c.FormFile("avatar")
	if err != nil {
		httpx.WriteBadRequest(c); return
	}

	file, err := tool.OpenMultipartFile(fileHeader)
	if err != nil {
		httpx.WriteBadRequest(c); return
	}
	defer file.Close()

	group, err := h.svc.UploadAvatar(c.Request.Context(), groupID, uid, file)
	if err != nil {
		httpx.SmartError(c, err); return
	}

	httpx.WriteJSON(c, 200, group.ToGroupDTOFor(uid))
}
