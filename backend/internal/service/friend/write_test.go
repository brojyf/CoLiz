package friend

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	friendrepo "github.com/brojyf/CoLiz/internal/repo/friend"
	svc "github.com/brojyf/CoLiz/internal/service"
)

type fakeRepo struct {
	sendRequestFn func(context.Context, *domain.FriendRequest) error
}

func (f *fakeRepo) BeginTx(tx *sql.Tx) friendrepo.Repo { return f }
func (f *fakeRepo) GetFriends(context.Context, string) ([]domain.User, error) {
	panic("unexpected call")
}
func (f *fakeRepo) GetFriend(context.Context, string, string) (*domain.User, error) {
	panic("unexpected call")
}
func (f *fakeRepo) Delete(context.Context, string, string) error { panic("unexpected call") }
func (f *fakeRepo) SendRequest(ctx context.Context, req *domain.FriendRequest) error {
	return f.sendRequestFn(ctx, req)
}
func (f *fakeRepo) GetRequests(context.Context, string) ([]domain.FriendRequest, error) {
	panic("unexpected call")
}
func (f *fakeRepo) AcceptRequest(context.Context, string, string) error { panic("unexpected call") }
func (f *fakeRepo) DeclineRequest(context.Context, string, string) error {
	panic("unexpected call")
}
func (f *fakeRepo) CancelRequest(context.Context, string, string) error { panic("unexpected call") }

func TestSendRequestMapsRepoErrors(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want error
	}{
		{name: "invalid input", err: repo.ErrInvalidInput, want: svc.ErrInvalidInput},
		{name: "not found", err: repo.ErrNotFound, want: svc.ErrNotFound},
		{name: "conflict", err: repo.ErrConflict, want: svc.ErrConflict},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := &fakeRepo{
				sendRequestFn: func(context.Context, *domain.FriendRequest) error {
					return tt.err
				},
			}
			service := NewService(Config{RequestTTL: time.Minute}, repo, nil)
			req, err := domain.NewFriendRequest(
				domain.WithFromUser("from-user"),
				domain.WithToUser("to-user"),
				domain.WithFriendRequestMessage("hello"),
			)
			if err != nil {
				t.Fatalf("build request: %v", err)
			}

			err = service.SendRequest(context.Background(), req)
			if !errors.Is(err, tt.want) {
				t.Fatalf("expected %v, got %v", tt.want, err)
			}
		})
	}
}

func TestSendRequestCreatesIDAndExpiry(t *testing.T) {
	seen := &domain.FriendRequest{}
	repo := &fakeRepo{
		sendRequestFn: func(ctx context.Context, req *domain.FriendRequest) error {
			*seen = *req
			return nil
		},
	}
	service := NewService(Config{RequestTTL: 2 * time.Minute}, repo, nil)
	req, err := domain.NewFriendRequest(
		domain.WithFromUser("from-user"),
		domain.WithToUser("to-user"),
		domain.WithFriendRequestMessage("hello"),
	)
	if err != nil {
		t.Fatalf("build request: %v", err)
	}

	before := time.Now()
	err = service.SendRequest(context.Background(), req)
	if err != nil {
		t.Fatalf("send request: %v", err)
	}

	if seen.ID == "" {
		t.Fatal("expected generated request id")
	}
	if seen.From != "from-user" || seen.To != "to-user" || seen.Msg != "hello" {
		t.Fatalf("unexpected request forwarded to repo: %+v", *seen)
	}
	if !seen.ExpiredAt.After(before) {
		t.Fatalf("expected expiry after call start, got %v", seen.ExpiredAt)
	}
}
