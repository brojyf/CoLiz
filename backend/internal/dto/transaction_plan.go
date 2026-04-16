package dto

type TransactionTransfer struct {
	FromUserID        string `json:"from_user_id"`
	FromUsername      string `json:"from_username"`
	FromAvatarVersion uint32 `json:"from_avatar_version"`
	ToUserID          string `json:"to_user_id"`
	ToUsername        string `json:"to_username"`
	ToAvatarVersion   uint32 `json:"to_avatar_version"`
	Amount            string `json:"amount"`
}

type GroupTransactionPlan struct {
	GroupID        string                `json:"group_id"`
	GroupName      string                `json:"group_name"`
	GroupAvatarVer uint32                `json:"group_avatar_version"`
	Transfers      []TransactionTransfer `json:"transfers"`
}
