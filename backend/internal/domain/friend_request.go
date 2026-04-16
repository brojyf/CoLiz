package domain

import (
	"errors"
	"time"

	"github.com/brojyf/CoLiz/internal/dto"
	"github.com/google/uuid"
)

const (
	pending     = 0
	accepted    = 1
	rejected    = 2
	canceled    = 3
	pendingStr  = "pending"
	acceptedStr = "accepted"
	rejectedStr = "rejected"
	canceledStr = "canceled"
)

type FriendRequest struct {
	ID                string
	From              string
	FromName          string
	FromAvatarVersion uint32
	To                string
	ToName            string
	ToAvatarVersion   uint32
	Msg               string
	Status            int
	CreatedAt         time.Time
	ExpiredAt         time.Time
	UpdatedAt         time.Time
}

type FriendRequestOption func(*FriendRequest) error

func NewFriendRequest(opts ...FriendRequestOption) (*FriendRequest, error) {
	fr := &FriendRequest{}

	for _, opt := range opts {
		if err := opt(fr); err != nil {
			return nil, err
		}
	}

	return fr, nil
}

func WithFriendRequestID(id string) FriendRequestOption {
	return func(fr *FriendRequest) error {
		if id == "" {
			return errors.New("friend request id is required")
		}
		fr.ID = id
		return nil
	}
}

func WithNewFriendRequestID() FriendRequestOption {
	return func(fr *FriendRequest) error {
		u, err := uuid.NewV7()
		if err != nil {
			return err
		}
		fr.ID = u.String()
		return nil
	}
}

func WithFromUser(from string) FriendRequestOption {
	return func(fr *FriendRequest) error {
		if from == "" {
			return errors.New("from user is required")
		}
		fr.From = from
		return nil
	}
}

func WithToUser(to string) FriendRequestOption {
	return func(fr *FriendRequest) error {
		if to == "" {
			return errors.New("to user is required")
		}
		fr.To = to
		return nil
	}
}

func WithFromUsername(username string) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.FromName = username
		return nil
	}
}

func WithToUsername(username string) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.ToName = username
		return nil
	}
}

func WithFromAvatarVersion(version uint32) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.FromAvatarVersion = version
		return nil
	}
}

func WithToAvatarVersion(version uint32) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.ToAvatarVersion = version
		return nil
	}
}

func WithFriendRequestMessage(msg string) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.Msg = msg
		return nil
	}
}

func WithFriendRequestStatus(status int) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.Status = status
		return nil
	}
}

func WithFriendRequestCreatedAt(createdAt time.Time) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.CreatedAt = createdAt
		return nil
	}
}

func WithFriendRequestExpiredAt(expiredAt time.Time) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.ExpiredAt = expiredAt
		return nil
	}
}

func WithFriendRequestTTL(ttl time.Duration) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.ExpiredAt = time.Now().Add(ttl)
		return nil
	}
}

func WithFriendRequestUpdatedAt(updatedAt time.Time) FriendRequestOption {
	return func(fr *FriendRequest) error {
		fr.UpdatedAt = updatedAt
		return nil
	}
}

func (r FriendRequest) ToFriendRequestDTO(uid string) dto.FriendRequest {
	dir := dto.DirectionReceived
	if r.From == uid {
		dir = dto.DirectionSent
	}

	statusStr := pendingStr
	switch r.Status {
	case pending:
		statusStr = pendingStr
	case accepted:
		statusStr = acceptedStr
	case rejected:
		statusStr = rejectedStr
	case canceled:
		statusStr = canceledStr
	}

	return dto.FriendRequest{
		ID:                r.ID,
		From:              r.From,
		FromName:          r.FromName,
		FromAvatarVersion: r.FromAvatarVersion,
		To:                r.To,
		ToName:            r.ToName,
		ToAvatarVersion:   r.ToAvatarVersion,
		Msg:               r.Msg,
		Status:            statusStr,
		CreatedAt:         r.CreatedAt,
		Direction:         dir,
	}
}

func ToFriendRequestDTOs(reqs []FriendRequest, uid string) []dto.FriendRequest {
	out := make([]dto.FriendRequest, 0, len(reqs))

	for _, r := range reqs {
		out = append(out, r.ToFriendRequestDTO(uid))
	}

	return out
}
