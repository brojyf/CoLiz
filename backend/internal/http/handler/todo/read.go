package todo

import (
	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

func (h *Handler) GetAll(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	todos, err := h.svc.Get(ctx, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, domain.ToTodoDTOs(todos))
}

func (h *Handler) GetGroup(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) { httpx.WriteBadRequest(c); return }

	todos, err := h.svc.GetGroup(c.Request.Context(), groupID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, domain.ToTodoDTOs(todos))
}

func (h *Handler) GetDetail(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	todoID := c.Param("todo_id")
	if !uuidx.IsV7(todoID) { httpx.WriteBadRequest(c); return }

	todo, err := h.svc.GetDetail(c.Request.Context(), todoID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, todo.ToTodoDTO())
}
