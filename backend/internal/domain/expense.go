package domain

import (
	"time"

	"github.com/brojyf/CoLiz/internal/dto"
	"github.com/brojyf/CoLiz/internal/policy/expol"
)

type Expense struct {
	ID            string
	GroupID       string
	Name          string
	Category      string
	Amount        string
	PaidBy        string
	SplitMethod   string
	Note          *string
	CreatedBy     string
	OccurredAt    *time.Time
	CreatedAt     time.Time
	UpdatedAt     time.Time
	IsTransaction bool
	Participants  []Participant
}

type Participant struct {
	UserID      string
	Amount      string
	FixedAmount *string
}

// From DTO
func FromExpenseDTO(e dto.Expense, gid string) *Expense {
	participants := make([]Participant, 0, len(e.Participants))
	for _, p := range e.Participants {
		participants = append(participants, Participant{
			UserID:      p.UserID,
			FixedAmount: p.FixedAmount,
		})
	}

	return &Expense{
		GroupID:      gid,
		Name:         e.Name,
		Category:     e.Category,
		Amount:       e.Amount,
		PaidBy:       e.PaidBy,
		SplitMethod:  e.SplitMethod,
		Note:         e.Note,
		OccurredAt:   e.OccurredAt,
		Participants: participants,
	}
}

type ExpenseSplit struct {
	ExpenseID   string
	GroupID     string
	UserID      string
	Amount      string
	FixedAmount *string
}

func (p Participant) ToDTO() dto.Participant {
	return dto.Participant{
		UserID:      p.UserID,
		Amount:      p.Amount,
		FixedAmount: p.FixedAmount,
	}
}

func (e Expense) ToDTO() dto.Expense {
	participants := make([]dto.Participant, 0, len(e.Participants))
	for _, participant := range e.Participants {
		participants = append(participants, participant.ToDTO())
	}

	return dto.Expense{
		ID:             e.ID,
		GroupID:        e.GroupID,
		Name:           e.Name,
		Category:       e.Category,
		CategorySymbol: expol.ExpenseCategorySymbol(e.Category),
		Amount:         e.Amount,
		PaidBy:         e.PaidBy,
		SplitMethod:    e.SplitMethod,
		Note:           e.Note,
		OccurredAt:     e.OccurredAt,
		CreatedBy:      e.CreatedBy,
		CreatedAt:      e.CreatedAt,
		UpdatedAt:      e.UpdatedAt,
		Participants:   participants,
	}
}
