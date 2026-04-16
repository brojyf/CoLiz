package friend

import (
	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

func (h *Handler) List(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	friends, err := h.svc.GetFriends(ctx, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, domain.ToUserProfileDTOs(friends))
}

func (h *Handler) GetByUID(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
		return
	}

	friendID := c.Param("uid")
	if !uuidx.IsV7(friendID) { httpx.WriteBadRequest(c); return }

	friend, err := h.svc.GetFriend(ctx, uid, friendID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, friend.ToUserProfileDTO())
}

func (h *Handler) ListRequests(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c); return
	}

	reqs, err := h.svc.GetRequests(ctx, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, domain.ToFriendRequestDTOs(reqs, uid))
}
