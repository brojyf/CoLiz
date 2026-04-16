package domain

import (
	"time"

	"github.com/brojyf/CoLiz/internal/dto"
	"github.com/google/uuid"
)

type User struct {
	ID              string
	Username        string
	Email           string
	AvatarVersion   uint32
	AvatarUpdatedAt *time.Time
	FriendSince     *time.Time
	MutualGroups    []Group
	DeviceID        string
	PasswordHash    string
	RTK             RTKState
}

type RTKState struct {
	Hash          string
	PepperVersion string
	ExpireAt      time.Time
	RevokedAt     *time.Time
}

func (u *User) BindDevice(deviceID string) {
	u.DeviceID = deviceID
}

func (u *User) UpdateRTK(hash, pepperVersion string, expireAt time.Time) {
	u.RTK.Hash = hash
	u.RTK.PepperVersion = pepperVersion
	u.RTK.ExpireAt = expireAt
}

func (u *User) IsRTKValid(deviceID string, now time.Time) bool {
	if u.RTK.RevokedAt != nil {
		return false
	}
	if u.RTK.ExpireAt.Before(now) {
		return false
	}
	if u.DeviceID != deviceID {
		return false
	}
	return true
}

func (u *User) ToUserProfileDTO() *dto.UserProfile {
	return &dto.UserProfile{
		ID:            u.ID,
		Username:      u.Username,
		Email:         u.Email,
		AvatarVersion: u.AvatarVersion,
		FriendSince:   u.FriendSince,
		MutualGroups:  ToGroupDTOs(u.MutualGroups),
	}
}

func ToUserProfileDTOs(users []User) []dto.UserProfile {
	out := make([]dto.UserProfile, 0, len(users))
	for _, user := range users {
		out = append(out, *user.ToUserProfileDTO())
	}
	return out
}

// Options
type UserOption func(*User) 

func NewUser(opts ...UserOption) *User {
	u := &User{}

	for _, opt := range opts {
		opt(u)
	}

	return u
}

func WithUserID(id string) UserOption {
	return func(u *User) {
		u.ID = id
	}
}

func WithNewUserID() UserOption {
	return func(u *User) {
		v, _ := uuid.NewV7()
		u.ID = v.String()
	}
}

func WithUsername(username string) UserOption {
	return func(u *User) {
		u.Username = username
	}
}

func WithEmail(email string) UserOption {
	return func(u *User) {
		u.Email = email
	}
}

func WithDeviceID(deviceID string) UserOption {
	return func(u *User) {
		u.DeviceID = deviceID
	}
}

func WithAvatarVersion(version uint32) UserOption {
	return func(u *User) {
		u.AvatarVersion = version
	}
}

func WithAvatarUpdatedAt(updatedAt time.Time) UserOption {
	return func(u *User) {
		u.AvatarUpdatedAt = &updatedAt
	}
}

func WithFriendSince(friendSince time.Time) UserOption {
	return func(u *User) {
		u.FriendSince = &friendSince
	}
}

func WithMutualGroups(groups []Group) UserOption {
	return func(u *User) {
		u.MutualGroups = groups
	}
}

func WithPasswordHash(passwordHash string) UserOption {
	return func(u *User) {
		u.PasswordHash = passwordHash
	}
}

func WithRTK(hash, pepperVersion string, expireAt time.Time) UserOption {
	return func(u *User) {
		u.RTK.Hash = hash
		u.RTK.PepperVersion = pepperVersion
		u.RTK.ExpireAt = expireAt
	}
}

func WithRTKRevokedAt(revokedAt *time.Time) UserOption {
	return func(u *User) {
		u.RTK.RevokedAt = revokedAt
	}
}
