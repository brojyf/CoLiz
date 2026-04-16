package domain

import "github.com/brojyf/CoLiz/internal/dto"

type MemberNetBalance struct {
	User      User
	NetAmount string
}

type TransactionTransfer struct {
	FromUser User
	ToUser   User
	Amount   string
}

type GroupTransactionPlan struct {
	Group     Group
	Transfers []TransactionTransfer
}

func (p GroupTransactionPlan) ToDTO() dto.GroupTransactionPlan {
	transfers := make([]dto.TransactionTransfer, 0, len(p.Transfers))
	for _, transfer := range p.Transfers {
		transfers = append(transfers, dto.TransactionTransfer{
			FromUserID:        transfer.FromUser.ID,
			FromUsername:      transfer.FromUser.Username,
			FromAvatarVersion: transfer.FromUser.AvatarVersion,
			ToUserID:          transfer.ToUser.ID,
			ToUsername:        transfer.ToUser.Username,
			ToAvatarVersion:   transfer.ToUser.AvatarVersion,
			Amount:            transfer.Amount,
		})
	}

	return dto.GroupTransactionPlan{
		GroupID:        p.Group.ID,
		GroupName:      p.Group.Name,
		GroupAvatarVer: p.Group.AvatarVersion,
		Transfers:      transfers,
	}
}
