package dto

import "time"

type ExpenseHistoryItem struct {
	ID                  string    `json:"id"`
	Name                string    `json:"name"`
	Category            string    `json:"category"`
	CategorySymbol      string    `json:"category_symbol"`
	Amount              string    `json:"amount"`
	LentAmount          string    `json:"lent_amount"`
	BorrowAmount        string    `json:"borrow_amount"`
	PaidBy              string    `json:"paid_by"`
	PaidByName          string    `json:"paid_by_name"`
	PaidByAvatarVersion uint32    `json:"paid_by_avatar_version"`
	CreatedBy           string    `json:"created_by"`
	OccurredAt          time.Time `json:"occurred_at"`
	CreatedAt           time.Time `json:"created_at"`
}
