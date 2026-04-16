package group

import (
	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

func (h *Handler) List(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c); return
	}

	groups, err := h.svc.Get(c.Request.Context(), uid)
	if err != nil {
		httpx.SmartError(c, err); return
	}

	httpx.WriteJSON(c, 200, domain.ToGroupDTOsFor(groups, uid))
}

func (h *Handler) GetDetail(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c); return
	}

	group, members, err := h.svc.GetDetail(c.Request.Context(), groupID, uid)
	if err != nil {
		httpx.SmartError(c, err); return
	}

	httpx.WriteJSON(c, 200, group.ToGroupDetailDTO(uid, members))
}

func (h *Handler) GetMembers(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }
	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) { httpx.WriteBadRequest(c); return }

	_, members, err := h.svc.GetDetail(c.Request.Context(), groupID, uid)
	if err != nil {
		httpx.SmartError(c, err); return
	}

	httpx.WriteJSON(c, 200, domain.ToUserProfileDTOs(members))
}
