package domain

import (
	"errors"
	"time"

	"github.com/brojyf/CoLiz/internal/dto"
	"github.com/google/uuid"
)

type Group struct {
	ID              string
	Name            string
	Owner           string
	AvatarVersion   uint32
	AvatarUpdatedAt *time.Time
	CreatedAt       time.Time
}

func (g *Group) IsOwner(userID string) bool {
	return g.Owner == userID
}

// Single DTO
func (g *Group) ToGroupDTO() dto.Group {
	return g.ToGroupDTOFor("")
}

func (g *Group) ToGroupDTOFor(userID string) dto.Group {
	return dto.Group{
		ID:            g.ID,
		GroupName:     g.Name,
		AvatarVersion: g.AvatarVersion,
		IsOwner:       userID != "" && g.Owner == userID,
		CreatedAt:     g.CreatedAt,
	}
}

func (g *Group) ToGroupDetailDTO(userID string, members []User) dto.GroupDetail {
	return dto.GroupDetail{
		ID:            g.ID,
		GroupName:     g.Name,
		AvatarVersion: g.AvatarVersion,
		OwnerID:       g.Owner,
		IsOwner:       g.IsOwner(userID),
		CreatedAt:     g.CreatedAt,
		Members:       ToUserProfileDTOs(members),
	}
}

func (g *Group) ToGroupExpenseDTO(l, b string) dto.GroupExpense {
	return dto.GroupExpense{
		ID: g.ID,
		GroupName: g.Name,
		AvatarVersion: g.AvatarVersion,
		LentAmount: l,
		BorrowAmount: b,
	}
}

// Plural DTO
func ToGroupDTOs(groups []Group) []dto.Group {
	return ToGroupDTOsFor(groups, "")
}

func ToGroupDTOsFor(groups []Group, userID string) []dto.Group {
	out := make([]dto.Group, 0, len(groups))
	for _, g := range groups {
		out = append(out, g.ToGroupDTOFor(userID))
	}
	return out
}

func ToGroupExpenseDTOs(groups []Group, lentAmounts []string, borrowAmounts []string) []dto.GroupExpense {
	out := make([]dto.GroupExpense, 0, len(groups))
	for i, g := range groups {
		out = append(out, g.ToGroupExpenseDTO(lentAmounts[i], borrowAmounts[i]))
	}
	return out
}

// Options
type GroupOption func(*Group) error

func NewGroup(opts ...GroupOption) (*Group, error) {
	g := &Group{}

	for _, opt := range opts {
		if err := opt(g); err != nil {
			return nil, err
		}
	}

	return g, nil
}

func WithGroupID(id string) GroupOption {
	return func(g *Group) error {
		if id == "" {
			return errors.New("group id is required")
		}
		g.ID = id
		return nil
	}
}

func WithNewGroupID() GroupOption {
	return func(g *Group) error {
		v, err := uuid.NewV7()
		if err != nil {
			return err
		}
		g.ID = v.String()
		return nil
	}
}

func WithGroupName(name string) GroupOption {
	return func(g *Group) error {
		if name == "" {
			return errors.New("group name is required")
		}
		g.Name = name
		return nil
	}
}

func WithGroupOwner(owner string) GroupOption {
	return func(g *Group) error {
		if owner == "" {
			return errors.New("group owner is required")
		}
		g.Owner = owner
		return nil
	}
}

func WithGroupCreatedAt(createdAt time.Time) GroupOption {
	return func(g *Group) error {
		g.CreatedAt = createdAt
		return nil
	}
}

func WithGroupAvatarVersion(version uint32) GroupOption {
	return func(g *Group) error {
		g.AvatarVersion = version
		return nil
	}
}

func WithGroupAvatarUpdatedAt(updatedAt time.Time) GroupOption {
	return func(g *Group) error {
		g.AvatarUpdatedAt = &updatedAt
		return nil
	}
}
