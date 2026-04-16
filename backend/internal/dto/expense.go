package dto

import (
	"strconv"
	"strings"
	"time"

	"github.com/brojyf/CoLiz/internal/policy/expol"
	"github.com/brojyf/CoLiz/internal/util/tool"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
)

type Expense struct {
	ID             string        `json:"id,omitempty"`
	GroupID        string        `json:"group_id,omitempty"`
	Name           string        `json:"name" binding:"required,min=1,max=32"`
	Category       string        `json:"category" binding:"required"`
	CategorySymbol string        `json:"category_symbol,omitempty"`
	Amount         string        `json:"amount" binding:"required,max=32"`
	PaidBy         string        `json:"paid_by" binding:"required,uuid"`
	SplitMethod    string        `json:"split_method" binding:"required,oneof=equal fixed"`
	Note           *string       `json:"note,omitempty" binding:"omitempty,max=64"`
	OccurredAt     *time.Time    `json:"occurred_at"`
	CreatedBy      string        `json:"created_by,omitempty"`
	CreatedAt      time.Time     `json:"created_at,omitempty"`
	UpdatedAt      time.Time     `json:"updated_at,omitempty"`
	Participants   []Participant `json:"participants" binding:"required"`
}

type Participant struct {
	UserID      string  `json:"user_id" binding:"required,uuid"`
	Amount      string  `json:"amount,omitempty"`
	FixedAmount *string `json:"fixed_amount,omitempty" binding:"omitempty,max=32"`
}

type TransactionParticipant struct {
	UserID      string `json:"user_id" binding:"required,uuid"`
	FixedAmount string `json:"fixed_amount" binding:"required,max=32"`
}

func (e *Expense) Cleanup() bool {
	if !tool.NormAndCheckName(&e.Name) ||
		!expol.NormAndCheckSplit(&e.SplitMethod) ||
		!expol.NormExpenseCategory(&e.Category) ||
		!uuidx.IsV7(e.PaidBy) ||
		len(e.Participants) == 0 {
		return false
	}
	if e.Note != nil && !tool.NormAndChecMessage(e.Note) {
		return false
	}
	if e.Category == expol.CategoryTransaction && e.SplitMethod != expol.SplitFixed {
		return false
	}

	_, normalizedAmount, err := parseAmountToCents(e.Amount)
	if err != nil {
		return false
	}

	var note *string
	if e.Note != nil {
		trimmed := strings.TrimSpace(*e.Note)
		note = &trimmed
	}

	seen := make(map[string]struct{}, len(e.Participants))
	for i := range e.Participants {
		e.Participants[i].UserID = strings.TrimSpace(e.Participants[i].UserID)
		if !uuidx.IsV7(e.Participants[i].UserID) {
			return false
		}
		if _, ok := seen[e.Participants[i].UserID]; ok {
			return false
		}
		seen[e.Participants[i].UserID] = struct{}{}
		e.Participants[i].FixedAmount = trimOptionalString(e.Participants[i].FixedAmount)
	}

	e.Amount = normalizedAmount
	e.Note = note

	return true
}

func trimOptionalString(value *string) *string {
	if value == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func parseAmountToCents(raw string) (int64, string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return 0, "", strconv.ErrSyntax
	}
	if strings.HasPrefix(value, "-") || strings.HasPrefix(value, "+") {
		return 0, "", strconv.ErrSyntax
	}

	parts := strings.Split(value, ".")
	if len(parts) > 2 {
		return 0, "", strconv.ErrSyntax
	}

	intPart := parts[0]
	if intPart == "" || len(intPart) > 8 {
		return 0, "", strconv.ErrSyntax
	}
	for _, ch := range intPart {
		if ch < '0' || ch > '9' {
			return 0, "", strconv.ErrSyntax
		}
	}

	fracPart := ""
	if len(parts) == 2 {
		fracPart = parts[1]
		if fracPart == "" || len(fracPart) > 2 {
			return 0, "", strconv.ErrSyntax
		}
		for _, ch := range fracPart {
			if ch < '0' || ch > '9' {
				return 0, "", strconv.ErrSyntax
			}
		}
	}

	intValue, err := strconv.ParseInt(intPart, 10, 64)
	if err != nil || intValue > 99999999 {
		return 0, "", strconv.ErrSyntax
	}

	for len(fracPart) < 2 {
		fracPart += "0"
	}
	fracValue, err := strconv.ParseInt(fracPart, 10, 64)
	if err != nil {
		return 0, "", strconv.ErrSyntax
	}

	cents := intValue*100 + fracValue
	if cents <= 0 || cents > 9999999999 {
		return 0, "", strconv.ErrSyntax
	}

	return cents, formatCents(cents), nil
}

func formatCents(cents int64) string {
	return strconv.FormatInt(cents/100, 10) + "." + leftPad2(cents%100)
}

func leftPad2(v int64) string {
	if v < 10 {
		return "0" + strconv.FormatInt(v, 10)
	}
	return strconv.FormatInt(v, 10)
}
