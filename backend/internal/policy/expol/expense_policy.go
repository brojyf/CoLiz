package expol

import "strings"

const (
	SplitFixed = "fixed"
	SplitEqual = "equal"

	TransactionExpenseName = "Transaction"

	CategoryDining        = "dining"
	CategoryGas           = "gas"
	CategoryGroceries     = "groceries"
	CategoryTransaction   = "transaction"
	CategoryTransport     = "transport"
	CategoryEntertainment = "entertainment"
	CategoryShopping      = "shopping"
	CategoryHousing       = "housing"
	CategoryUtilities     = "utilities"
	CategoryTravel        = "travel"
	CategoryHealth        = "health"
	CategoryOther         = "other"
)

var expenseCategorySymbols = map[string]string{
	CategoryDining:        "fork.knife",
	CategoryGas:           "fuelpump.fill",
	CategoryGroceries:     "cart.fill",
	CategoryTransaction:   "arrow.left.arrow.right.circle.fill",
	CategoryTransport:     "car.fill",
	CategoryEntertainment: "gamecontroller.fill",
	CategoryShopping:      "bag.fill",
	CategoryHousing:       "house.fill",
	CategoryUtilities:     "bolt.fill",
	CategoryTravel:        "airplane",
	CategoryHealth:        "cross.case.fill",
	CategoryOther:         "square.grid.2x2.fill",
}

func NormExpenseCategory(raw *string) (ok bool) {
	category := strings.TrimSpace(strings.ToLower(*raw))
	if _, ok = expenseCategorySymbols[category]; !ok {
		return false
	}
	*raw = category
	return true
}

func NormAndCheckSplit(raw *string) (ok bool) {
	switch strings.ToLower(strings.TrimSpace(*raw)) {
	case SplitEqual:
		*raw = SplitEqual
		return true
	case SplitFixed, "fixed_amount", "fixed amount":
		*raw = SplitFixed
		return true
	default:
		return false
	}
}

func ExpenseCategorySymbol(category string) string {
	if symbol, ok := expenseCategorySymbols[category]; ok {
		return symbol
	}
	return expenseCategorySymbols[CategoryOther]
}
