package domain

import (
	"errors"
	"time"

	"github.com/brojyf/CoLiz/internal/dto"
	"github.com/google/uuid"
)

type Todo struct {
	ID            string
	GroupID       string
	Message       string
	Done          bool
	CreatedBy     string
	CreatedByName string
	UpdatedAt     time.Time
	CreatedAt     time.Time
}

type TodoOption func(*Todo) error

func NewTodo(opts ...TodoOption) (*Todo, error) {
	t := &Todo{}

	for _, opt := range opts {
		if err := opt(t); err != nil {
			return nil, err
		}
	}

	return t, nil
}

func WithTodoID(id string) TodoOption {
	return func(t *Todo) error {
		if id == "" {
			return errors.New("todo id is required")
		}
		t.ID = id
		return nil
	}
}

func WithNewTodoID() TodoOption {
	return func(t *Todo) error {
		v, err := uuid.NewV7()
		if err != nil {
			return err
		}
		t.ID = v.String()
		return nil
	}
}

func WithTodoGroupID(groupID string) TodoOption {
	return func(t *Todo) error {
		if groupID == "" {
			return errors.New("group id is required")
		}
		t.GroupID = groupID
		return nil
	}
}

func WithMessage(msg string) TodoOption {
	return func(t *Todo) error {
		t.Message = msg
		return nil
	}
}

func WithDone(done bool) TodoOption {
	return func(t *Todo) error {
		t.Done = done
		return nil
	}
}

func WithCreatedBy(uid string) TodoOption {
	return func(t *Todo) error {
		if uid == "" {
			return errors.New("created by is required")
		}
		t.CreatedBy = uid
		return nil
	}
}

func WithCreatedAt(createdAt time.Time) TodoOption {
	return func(t *Todo) error {
		t.CreatedAt = createdAt
		return nil
	}
}

func WithUpdatedAt(updatedAt time.Time) TodoOption {
	return func(t *Todo) error {
		t.UpdatedAt = updatedAt
		return nil
	}
}

func WithNowTimestamps() TodoOption {
	return func(t *Todo) error {
		now := time.Now()
		t.CreatedAt = now
		t.UpdatedAt = now
		return nil
	}
}

func (t Todo) ToTodoDTO() dto.Todo {
	return dto.Todo{
		ID:            t.ID,
		GroupID:       t.GroupID,
		Message:       t.Message,
		Done:          t.Done,
		CreatedBy:     t.CreatedBy,
		CreatedByName: t.CreatedByName,
		UpdatedAt:     t.UpdatedAt,
		CreatedAt:     t.CreatedAt,
	}
}

func ToTodoDTOs(todos []Todo) []dto.Todo {
	dtos := make([]dto.Todo, 0, len(todos))
	for _, todo := range todos {
		dtos = append(dtos, todo.ToTodoDTO())
	}
	return dtos
}
