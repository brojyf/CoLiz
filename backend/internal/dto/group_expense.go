package dto

type GroupExpense struct {
	ID            string `json:"id"`
	GroupName     string `json:"group_name"`
	AvatarVersion uint32 `json:"avatar_version"`
	LentAmount    string `json:"lent_amount"`
	BorrowAmount  string `json:"borrow_amount"`
}