package dto

import "time"

type Direction string

const (
	DirectionSent     Direction = "sent"
	DirectionReceived Direction = "received"
)

type FriendRequest struct {
	ID                string    `json:"id"`
	From              string    `json:"from"`
	FromName          string    `json:"from_username"`
	FromAvatarVersion uint32    `json:"from_avatar_version"`
	To                string    `json:"to"`
	ToName            string    `json:"to_username"`
	ToAvatarVersion   uint32    `json:"to_avatar_version"`
	Msg               string    `json:"msg"`
	Status            string    `json:"status"`
	CreatedAt         time.Time `json:"created_at"`
	Direction         Direction `json:"direction"`
}
