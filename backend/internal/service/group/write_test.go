package group

import (
	"bytes"
	"context"
	"database/sql"
	"errors"
	"image"
	"image/png"
	"testing"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	avatarrepo "github.com/brojyf/CoLiz/internal/repo/avatar"
	grouprepo "github.com/brojyf/CoLiz/internal/repo/group"
	svc "github.com/brojyf/CoLiz/internal/service"
)

type fakeGroupPendingWrite struct {
	commitFn   func(context.Context) error
	rollbackFn func(context.Context) error
}

func (f *fakeGroupPendingWrite) Commit(ctx context.Context) error {
	if f.commitFn != nil {
		return f.commitFn(ctx)
	}
	return nil
}

func (f *fakeGroupPendingWrite) Rollback(ctx context.Context) error {
	if f.rollbackFn != nil {
		return f.rollbackFn(ctx)
	}
	return nil
}

type fakeGroupRepo struct {
	getDetailFn        func(context.Context, string, string) (*domain.Group, error)
	updateNameFn       func(context.Context, string, string, string) error
	updateAvatarMetaFn func(context.Context, string, uint32, uint32, *time.Time) error
}

func (f *fakeGroupRepo) BeginTx(*sql.Tx) grouprepo.Repo { panic("unexpected call") }
func (f *fakeGroupRepo) Create(context.Context, *domain.Group) (*domain.Group, error) {
	panic("unexpected call")
}
func (f *fakeGroupRepo) Get(context.Context, string) ([]domain.Group, error) {
	panic("unexpected call")
}
func (f *fakeGroupRepo) GetDetail(ctx context.Context, groupID, userID string) (*domain.Group, error) {
	return f.getDetailFn(ctx, groupID, userID)
}
func (f *fakeGroupRepo) GetMembers(context.Context, string) ([]domain.User, error) {
	panic("unexpected call")
}
func (f *fakeGroupRepo) GetByID(context.Context, string) (*domain.Group, error) {
	panic("unexpected call")
}
func (f *fakeGroupRepo) Invite(context.Context, string, string, string) error {
	panic("unexpected call")
}
func (f *fakeGroupRepo) UpdateName(ctx context.Context, groupID, userID, name string) error {
	if f.updateNameFn != nil {
		return f.updateNameFn(ctx, groupID, userID, name)
	}
	panic("unexpected call")
}
func (f *fakeGroupRepo) CanLeave(context.Context, string, string) (bool, error) {
	panic("unexpected call")
}
func (f *fakeGroupRepo) Leave(context.Context, string, string) error { panic("unexpected call") }
func (f *fakeGroupRepo) CanDelete(context.Context, string) (bool, error) {
	panic("unexpected call")
}
func (f *fakeGroupRepo) Delete(context.Context, string, string) error { panic("unexpected call") }
func (f *fakeGroupRepo) UpdateAvatarMeta(ctx context.Context, groupID string, currentVersion, nextVersion uint32, updatedAt *time.Time) error {
	return f.updateAvatarMetaFn(ctx, groupID, currentVersion, nextVersion, updatedAt)
}

type fakeGroupAvatarRepo struct {
	stagePNGFn func(context.Context, string, []byte) (avatarrepo.PendingWrite, error)
	deleteFn   func(context.Context, string) error
}

func (f *fakeGroupAvatarRepo) Open(context.Context, string) (*domain.FileAsset, error) {
	panic("unexpected call")
}

func (f *fakeGroupAvatarRepo) StagePNG(ctx context.Context, key string, data []byte) (avatarrepo.PendingWrite, error) {
	return f.stagePNGFn(ctx, key, data)
}

func (f *fakeGroupAvatarRepo) SavePNG(context.Context, string, []byte) error {
	panic("unexpected call")
}
func (f *fakeGroupAvatarRepo) Delete(ctx context.Context, key string) error {
	if f.deleteFn != nil {
		return f.deleteFn(ctx, key)
	}
	panic("unexpected call")
}

func TestUpdateNameReturnsConflictOnDuplicateName(t *testing.T) {
	t.Parallel()

	service := NewService(
		Config{},
		&fakeGroupRepo{
			getDetailFn: func(context.Context, string, string) (*domain.Group, error) {
				return &domain.Group{ID: "group-123", Name: "old name"}, nil
			},
			updateNameFn: func(context.Context, string, string, string) error {
				return repo.ErrConflict
			},
		},
		nil,
		nil,
	)

	_, err := service.UpdateName(context.Background(), "group-123", "user-123", "new name")
	if !errors.Is(err, svc.ErrConflict) {
		t.Fatalf("expected conflict, got %v", err)
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
		&fakeGroupRepo{
			getDetailFn: func(context.Context, string, string) (*domain.Group, error) {
				return &domain.Group{ID: "group-123", AvatarVersion: 2}, nil
			},
			updateAvatarMetaFn: func(context.Context, string, uint32, uint32, *time.Time) error {
				return repo.ErrConflict
			},
		},
		nil,
		&fakeGroupAvatarRepo{
			stagePNGFn: func(_ context.Context, key string, _ []byte) (avatarrepo.PendingWrite, error) {
				if key != "group-123.v3" {
					t.Fatalf("unexpected stage key: %q", key)
				}
				return &fakeGroupPendingWrite{
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

	_, err := service.UploadAvatar(context.Background(), "group-123", "user-123", bytes.NewReader(testGroupPNGBytes(t)))
	if !errors.Is(err, svc.ErrConflict) {
		t.Fatalf("expected conflict, got %v", err)
	}
	if !committed {
		t.Fatal("expected staged avatar to be committed before CAS update")
	}
	if len(deleteKeys) != 1 || deleteKeys[0] != "group-123.v3" {
		t.Fatalf("expected new version to be cleaned up, got %#v", deleteKeys)
	}
}

func TestUploadAvatarDeletesSupersededObjectsAfterCommit(t *testing.T) {
	t.Parallel()

	var (
		deleteKeys []string
		events     []string
	)
	service := NewService(
		Config{},
		&fakeGroupRepo{
			getDetailFn: func(context.Context, string, string) (*domain.Group, error) {
				return &domain.Group{ID: "group-123", AvatarVersion: 2}, nil
			},
			updateAvatarMetaFn: func(context.Context, string, uint32, uint32, *time.Time) error {
				events = append(events, "meta")
				return nil
			},
		},
		nil,
		&fakeGroupAvatarRepo{
			stagePNGFn: func(_ context.Context, key string, _ []byte) (avatarrepo.PendingWrite, error) {
				if key != "group-123.v3" {
					t.Fatalf("unexpected stage key: %q", key)
				}
				return &fakeGroupPendingWrite{
					commitFn: func(context.Context) error {
						events = append(events, "commit")
						return nil
					},
				}, nil
			},
			deleteFn: func(_ context.Context, key string) error {
				deleteKeys = append(deleteKeys, key)
				return repo.ErrNotFound
			},
		},
	)

	updated, err := service.UploadAvatar(context.Background(), "group-123", "user-123", bytes.NewReader(testGroupPNGBytes(t)))
	if err != nil {
		t.Fatalf("upload avatar: %v", err)
	}
	if updated.AvatarVersion != 3 {
		t.Fatalf("expected avatar version 3, got %d", updated.AvatarVersion)
	}
	if len(events) != 2 || events[0] != "commit" || events[1] != "meta" {
		t.Fatalf("expected commit before meta update, got %#v", events)
	}
	if len(deleteKeys) != 2 || deleteKeys[0] != "group-123.v2" || deleteKeys[1] != "group-123" {
		t.Fatalf("unexpected cleanup keys: %#v", deleteKeys)
	}
}

func TestCleanupDeletedAvatarDeletesCurrentVersionAndLegacyKey(t *testing.T) {
	t.Parallel()

	var deleteKeys []string
	service := &service{
		avatar: &fakeGroupAvatarRepo{
			deleteFn: func(_ context.Context, key string) error {
				deleteKeys = append(deleteKeys, key)
				return repo.ErrNotFound
			},
		},
	}

	service.cleanupDeletedAvatar(context.Background(), "group-123", 3)

	if len(deleteKeys) != 2 || deleteKeys[0] != "group-123.v3" || deleteKeys[1] != "group-123" {
		t.Fatalf("unexpected cleanup keys: %#v", deleteKeys)
	}
}

func testGroupPNGBytes(t *testing.T) []byte {
	t.Helper()

	var buf bytes.Buffer
	src := image.NewNRGBA(image.Rect(0, 0, 8, 8))
	if err := png.Encode(&buf, src); err != nil {
		t.Fatalf("encode png: %v", err)
	}
	return buf.Bytes()
}
