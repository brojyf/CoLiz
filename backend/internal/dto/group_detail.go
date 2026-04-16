package dto

import "time"

type GroupDetail struct {
	ID            string        `json:"id"`
	GroupName     string        `json:"group_name"`
	AvatarVersion uint32        `json:"avatar_version"`
	OwnerID       string        `json:"owner_id"`
	IsOwner       bool          `json:"is_owner"`
	CreatedAt     time.Time     `json:"created_at"`
	Members       []UserProfile `json:"members"`
}
