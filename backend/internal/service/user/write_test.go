package user

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/png"
	"io"
	"testing"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	avatarrepo "github.com/brojyf/CoLiz/internal/repo/avatar"
	svc "github.com/brojyf/CoLiz/internal/service"
)

type fakeUserRepo struct {
	getUserByIDFn      func(context.Context, string) (*domain.User, error)
	updateAvatarMetaFn func(context.Context, string, uint32, uint32, *time.Time) error
}

func (f *fakeUserRepo) GetUserByEmail(context.Context, string) (*domain.User, error) {
	panic("unexpected call")
}

func (f *fakeUserRepo) GetUserByID(ctx context.Context, userID string) (*domain.User, error) {
	return f.getUserByIDFn(ctx, userID)
}

func (f *fakeUserRepo) UpdateUsername(context.Context, string, string) error {
	panic("unexpected call")
}

func (f *fakeUserRepo) UpdateAvatarMeta(ctx context.Context, userID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error {
	return f.updateAvatarMetaFn(ctx, userID, currentVersion, nextVersion, updatedAt)
}

type fakePendingWrite struct {
	commitFn   func(context.Context) error
	rollbackFn func(context.Context) error
}

func (f *fakePendingWrite) Commit(ctx context.Context) error {
	if f.commitFn != nil {
		return f.commitFn(ctx)
	}
	return nil
}

func (f *fakePendingWrite) Rollback(ctx context.Context) error {
	if f.rollbackFn != nil {
		return f.rollbackFn(ctx)
	}
	return nil
}

type fakeAvatarRepo struct {
	openFn     func(context.Context, string) (*domain.FileAsset, error)
	stagePNGFn func(context.Context, string, []byte) (avatarrepo.PendingWrite, error)
	savePNGFn  func(context.Context, string, []byte) error
	deleteFn   func(context.Context, string) error
}

func (f *fakeAvatarRepo) Open(ctx context.Context, userID string) (*domain.FileAsset, error) {
	if f.openFn != nil {
		return f.openFn(ctx, userID)
	}
	panic("unexpected call")
}

func (f *fakeAvatarRepo) StagePNG(ctx context.Context, userID string, data []byte) (avatarrepo.PendingWrite, error) {
	return f.stagePNGFn(ctx, userID, data)
}

func (f *fakeAvatarRepo) SavePNG(ctx context.Context, userID string, data []byte) error {
	if f.savePNGFn != nil {
		return f.savePNGFn(ctx, userID, data)
	}
	panic("unexpected call")
}

func (f *fakeAvatarRepo) Delete(ctx context.Context, userID string) error {
	if f.deleteFn != nil {
		return f.deleteFn(ctx, userID)
	}
	panic("unexpected call")
}

func TestUploadAvatarUsesVersionedKeyAndCAS(t *testing.T) {
	t.Parallel()

	user := domain.NewUser(
		domain.WithUserID("user-123"),
		domain.WithAvatarVersion(3),
		domain.WithAvatarUpdatedAt(time.Unix(1700000000, 0)),
	)

	var (
		stagedKey   string
		stagedBytes int
		committed   bool
		deleteKeys  []string
		events      []string
	)

	service := NewService(
		Config{},
		&fakeUserRepo{
			getUserByIDFn: func(context.Context, string) (*domain.User, error) { return user, nil },
			updateAvatarMetaFn: func(_ context.Context, userID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error {
				if userID != "user-123" {
					t.Fatalf("unexpected user id: %q", userID)
				}
				if currentVersion != 3 || nextVersion != 4 {
					t.Fatalf("unexpected version transition: %d -> %d", currentVersion, nextVersion)
				}
				if updatedAt == nil {
					t.Fatal("expected updatedAt to be set")
				}
				events = append(events, "meta")
				return nil
			},
		},
		&fakeAvatarRepo{
			stagePNGFn: func(_ context.Context, key string, data []byte) (avatarrepo.PendingWrite, error) {
				stagedKey = key
				stagedBytes = len(data)
				return &fakePendingWrite{
					commitFn: func(context.Context) error {
						committed = true
						events = append(events, "commit")
						return nil
					},
				}, nil
			},
			deleteFn: func(_ context.Context, userID string) error {
				deleteKeys = append(deleteKeys, userID)
				return repo.ErrNotFound
			},
		},
	)

	updated, err := service.UploadAvatar(context.Background(), "user-123", bytes.NewReader(testPNGBytes(t)))
	if err != nil {
		t.Fatalf("upload avatar: %v", err)
	}

	if stagedKey != "user-123.v4" {
		t.Fatalf("expected staged key user-123.v4, got %q", stagedKey)
	}
	if stagedBytes == 0 {
		t.Fatal("expected normalized avatar bytes to be written")
	}
	if !committed {
		t.Fatal("expected staged file to be committed")
	}
	if len(events) != 2 || events[0] != "commit" || events[1] != "meta" {
		t.Fatalf("expected commit before meta update, got %#v", events)
	}
	if updated.AvatarVersion != 4 {
		t.Fatalf("expected avatar version 4, got %d", updated.AvatarVersion)
	}
	if len(deleteKeys) != 2 || deleteKeys[0] != "user-123.v3" || deleteKeys[1] != "user-123" {
		t.Fatalf("unexpected cleanup keys: %#v", deleteKeys)
	}
}

func TestUploadAvatarReturnsConflictOnConcurrentUpdate(t *testing.T) {
	t.Parallel()

	var (
		committed  bool
		deleteKeys []string
	)
	service := NewService(
		Config{},
		&fakeUserRepo{
			getUserByIDFn: func(context.Context, string) (*domain.User, error) {
				return domain.NewUser(
					domain.WithUserID("user-123"),
					domain.WithAvatarVersion(1),
				), nil
			},
			updateAvatarMetaFn: func(context.Context, string, uint32, uint32, *time.Time) error {
				return repo.ErrConflict
			},
		},
		&fakeAvatarRepo{
			stagePNGFn: func(_ context.Context, _ string, _ []byte) (avatarrepo.PendingWrite, error) {
				return &fakePendingWrite{
					commitFn: func(context.Context) error {
						committed = true
						return nil
					},
				}, nil
			},
			deleteFn: func(_ context.Context, key string) error {
				deleteKeys = append(deleteKeys, key)
				return nil
			},
		},
	)

	_, err := service.UploadAvatar(context.Background(), "user-123", bytes.NewReader(testPNGBytes(t)))
	if !errors.Is(err, svc.ErrConflict) {
		t.Fatalf("expected conflict, got %v", err)
	}
	if !committed {
		t.Fatal("expected staged avatar to be committed before CAS update")
	}
	if len(deleteKeys) != 1 || deleteKeys[0] != "user-123.v2" {
		t.Fatalf("expected new version to be cleaned up, got %#v", deleteKeys)
	}
}

func testPNGBytes(t *testing.T) []byte {
	t.Helper()

	var buf bytes.Buffer
	src := image.NewNRGBA(image.Rect(0, 0, 8, 8))
	if err := png.Encode(&buf, src); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buf.Bytes()
}

var _ avatarrepo.Repo = (*fakeAvatarRepo)(nil)

var _ io.Reader = (*bytes.Reader)(nil)
