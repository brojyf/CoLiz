package domain

import (
	"time"

	"github.com/brojyf/CoLiz/internal/dto"
	"github.com/brojyf/CoLiz/internal/policy/expol"
)

func ToExpenseHistoryDTOs(expenses []Expense, lentAmounts []string, borrowAmounts []string, users []User) []dto.ExpenseHistoryItem {
	out := make([]dto.ExpenseHistoryItem, 0, len(expenses))
	for i, expense := range expenses {
		lentAmount := ""
		if i < len(lentAmounts) {
			lentAmount = lentAmounts[i]
		}

		borrowAmount := ""
		if i < len(borrowAmounts) {
			borrowAmount = borrowAmounts[i]
		}

		paidByUser := User{}
		if i < len(users) {
			paidByUser = users[i]
		}

		occurredAt := time.Time{}
		if expense.OccurredAt != nil {
			occurredAt = *expense.OccurredAt
		}

		out = append(out, dto.ExpenseHistoryItem{
			ID:                  expense.ID,
			Name:                expense.Name,
			Category:            expense.Category,
			CategorySymbol:      expol.ExpenseCategorySymbol(expense.Category),
			Amount:              expense.Amount,
			LentAmount:          lentAmount,
			BorrowAmount:        borrowAmount,
			PaidBy:              expense.PaidBy,
			PaidByName:          paidByUser.Username,
			PaidByAvatarVersion: paidByUser.AvatarVersion,
			CreatedBy:           expense.CreatedBy,
			OccurredAt:          occurredAt,
			CreatedAt:           expense.CreatedAt,
		})
	}
	return out
}
