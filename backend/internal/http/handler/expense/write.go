package expense

import (
	"net/http"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/dto"
	"github.com/brojyf/CoLiz/internal/policy/expol"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
)

type transactionExpenseReq struct {
	Amount       string                       `json:"amount" binding:"required"`
	PaidBy       string                       `json:"paid_by" binding:"required,uuid"`
	Note         *string                      `json:"note"`
	OccurredAt   *time.Time                   `json:"occurred_at"`
	Participants []dto.TransactionParticipant `json:"participants" binding:"required,min=1"`
}

func (h *Handler) Create(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteUnauthorized(c)
		return
	}
	if !uuidx.IsV7(uid) {
		httpx.WriteBadRequest(c)
		return
	}

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c)
		return
	}

	var req dto.Expense
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	if ok := req.Cleanup(); !ok {
		httpx.WriteBadRequest(c)
		return
	}

	detail, err := h.svc.Create(ctx, domain.FromExpenseDTO(req, groupID), uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	go h.notifier.NotifyExpenseCreated(detail)

	httpx.WriteJSON(c, http.StatusCreated, detail.ToDTO())
}

func (h *Handler) Delete(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized.")
		return
	}
	if !uuidx.IsV7(uid) {
		httpx.WriteBadRequest(c)
		return
	}

	expenseID := c.Param("expense_id")
	if !uuidx.IsV7(expenseID) {
		httpx.WriteBadRequest(c)
		return
	}

	if err := h.svc.Delete(ctx, uid, expenseID); err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusNoContent, nil)
}

func (h *Handler) Update(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized.")
		return
	}
	if !uuidx.IsV7(uid) {
		httpx.WriteBadRequest(c)
		return
	}

	expenseID := c.Param("expense_id")
	if !uuidx.IsV7(expenseID) {
		httpx.WriteBadRequest(c)
		return
	}

	var req dto.Expense
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c)
		return
	}
	if ok := req.Cleanup(); !ok {
		httpx.WriteBadRequest(c)
		return
	}

	detail, err := h.svc.Update(ctx, uid, expenseID, domain.FromExpenseDTO(req, ""))
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	go h.notifier.NotifyExpenseUpdated(detail, uid)

	httpx.WriteJSON(c, http.StatusOK, detail.ToDTO())
}

func (h *Handler) CreateTransaction(c *gin.Context) {
	ctx := c.Request.Context()

	uid := c.GetString("uid")
	if uid == "" {
		httpx.WriteErrorAbort(c, http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized.")
		return
	}
	if !uuidx.IsV7(uid) {
		httpx.WriteBadRequest(c)
		return
	}

	groupID := c.Param("group_id")
	if !uuidx.IsV7(groupID) {
		httpx.WriteBadRequest(c)
		return
	}

	var req transactionExpenseReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteBadRequest(c)
		return
	}

	participants := make([]dto.Participant, 0, len(req.Participants))
	for _, participant := range req.Participants {
		fixedAmount := participant.FixedAmount
		participants = append(participants, dto.Participant{
			UserID:      participant.UserID,
			FixedAmount: &fixedAmount,
		})
	}

	expenseDTO := dto.Expense{
		Name:         expol.TransactionExpenseName,
		Category:     expol.CategoryTransaction,
		Amount:       req.Amount,
		PaidBy:       req.PaidBy,
		SplitMethod:  expol.SplitFixed,
		Note:         req.Note,
		OccurredAt:   req.OccurredAt,
		Participants: participants,
	}
	if ok := expenseDTO.Cleanup(); !ok {
		httpx.WriteBadRequest(c)
		return
	}

	detail, err := h.svc.Create(ctx, domain.FromExpenseDTO(expenseDTO, groupID), uid)
	if err != nil {
		httpx.SmartError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusCreated, detail.ToDTO())
}
