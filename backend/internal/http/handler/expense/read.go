package expense

import (
	"net/http"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

func (h *Handler) GetOverview(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}

	groups, lent, borrow, err := h.svc.GetOverview(c.Request.Context(), uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, domain.ToGroupExpenseDTOs(groups, lent, borrow))
}

func (h *Handler) GetDetail(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}

	expenseID := c.Param("expense_id")
	if !uuidx.IsV7(expenseID) {
		httpx.WriteBadRequest(c)
		return
	}

	detail, err := h.svc.GetDetail(c.Request.Context(), uid, expenseID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, detail.ToDTO())
}

func (h *Handler) GetByGroup(c *gin.Context) {
	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
		return
	}

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c)
		return
	}

	expenses, lentAmounts, borrowAmounts, users, err := h.svc.GetGroup(c.Request.Context(), uid, groupID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, 200, domain.ToExpenseHistoryDTOs(expenses, lentAmounts, borrowAmounts, users))
}

func (h *Handler) GetBalance(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized.")
		return
	}

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c)
		return
	}

	group, lent, borrow, err := h.svc.GetBalance(ctx, uid, groupID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusOK, group.ToGroupExpenseDTO(lent, borrow))
}

func (h *Handler) GetTransactionPlan(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized.")
		return
	}

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c)
		return
	}

	plan, err := h.svc.GetTransactionPlan(ctx, uid, groupID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusOK, plan.ToDTO())
}

func (h *Handler) ApplyTransactionPlan(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized.")
		return
	}

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c)
		return
	}

	plan, err := h.svc.ApplyTransactionPlan(ctx, uid, groupID)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusCreated, plan.ToDTO())
}
