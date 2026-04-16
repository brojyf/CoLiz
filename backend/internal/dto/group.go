package dto

import "time"

type Group struct {
	ID            string    `json:"id"`
	GroupName     string    `json:"group_name"`
	AvatarVersion uint32    `json:"avatar_version"`
	IsOwner       bool      `json:"is_owner"`
	CreatedAt     time.Time `json:"created_at"`
}
