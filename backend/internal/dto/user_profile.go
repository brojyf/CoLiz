package dto

import "time"

type UserProfile struct {
	ID            string     `json:"id"`
	Username      string     `json:"username"`
	Email         string     `json:"email"`
	AvatarVersion uint32     `json:"avatar_version"`
	FriendSince   *time.Time `json:"friend_since,omitempty"`
	MutualGroups  []Group    `json:"mutual_groups,omitempty"`
}
