package todo

import (
	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

type createTodoReq struct {
	Message string `json:"message" binding:"required,min=1,max=64"`
}

type markTodoReq struct {
	Done *bool `json:"done" binding:"required"`
}

type updateTodoReq struct {
	Message string `json:"message" binding:"required,min=1,max=64"`
}

func (h *Handler) Create(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	var req createTodoReq
	if err := c.ShouldBindJSON(&req); err != nil { httpx.WriteBadRequest(c); return }

	ok := tool.NormAndChecMessage(&req.Message)
	if !ok { httpx.WriteBadRequest(c); return }
	
	gid := c.Param("group_id")
	if !uuidx.IsV7(gid) { httpx.WriteBadRequest(c); return }

	todo, err := domain.NewTodo(
		domain.WithNewTodoID(),
		domain.WithTodoGroupID(gid),
		domain.WithMessage(req.Message),
		domain.WithDone(false),
		domain.WithCreatedBy(uid),
		domain.WithNowTimestamps(),
	)
	if err != nil { httpx.WriteInternal(c); return }

	todo, err = h.svc.Create(c.Request.Context(), todo)
	if err != nil {
		httpx.SmartError(c, err); return
	}

	go h.notifier.NotifyTodoCreated(todo)

	httpx.WriteJSON(c, 201, todo.ToTodoDTO())
}

func (h *Handler) Mark(c *gin.Context) {
	ctx := c.Request.Context()

	var req markTodoReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c)
		return
	}

	todoID := c.Param("todo_id")
	if !uuidx.IsV7(todoID) { httpx.WriteBadRequest(c); return }
	uid := c.GetString("uid")

	if uid == "" { httpx.WriteUnauthorized(c); return }

	todo, err := h.svc.Mark(ctx, *req.Done, todoID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	go h.notifier.NotifyTodoUpdated(todo, uid)

	httpx.WriteJSON(c, 200, todo.ToTodoDTO())
}

func (h *Handler) Update(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	var req updateTodoReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c)
		return
	}

	ok := tool.NormAndChecMessage(&req.Message)
	todoID := c.Param("todo_id")
	if !ok || !uuidx.IsV7(todoID) { httpx.WriteBadRequest(c); return }

	todo, err := h.svc.Update(c.Request.Context(), todoID, uid, req.Message)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	go h.notifier.NotifyTodoUpdated(todo, uid)

	httpx.WriteJSON(c, 200, todo.ToTodoDTO())
}

func (h *Handler) Delete(c *gin.Context) {
	ctx := c.Request.Context()

	todoID := c.Param("todo_id")
	if !uuidx.IsV7(todoID) { httpx.WriteBadRequest(c); return }
	
	uid := c.GetString("uid")
	if uid == "" { httpx.WriteUnauthorized(c); return }

	err := h.svc.Delete(ctx, todoID, uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 204, nil)
}
