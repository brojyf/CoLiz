package avatar

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestStagePNGCommitWritesFinalAvatar(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	repo := NewLocalRepo(root)
	userID := "user-123"

	pending, err := repo.StagePNG(context.Background(), userID, []byte("png-bytes"))
	if err != nil {
		t.Fatalf("stage png: %v", err)
	}

	finalPath := filepath.Join(root, userID+".png")
	if _, err := os.Stat(finalPath); !os.IsNotExist(err) {
		t.Fatalf("expected final avatar to be absent before commit, stat err=%v", err)
	}

	if err := pending.Commit(context.Background()); err != nil {
		t.Fatalf("commit pending avatar: %v", err)
	}

	data, err := os.ReadFile(finalPath)
	if err != nil {
		t.Fatalf("read final avatar: %v", err)
	}
	if string(data) != "png-bytes" {
		t.Fatalf("unexpected avatar contents: %q", string(data))
	}
}

func TestStagePNGRollbackRemovesTempFile(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	repo := NewLocalRepo(root)

	pending, err := repo.StagePNG(context.Background(), "user-123", []byte("png-bytes"))
	if err != nil {
		t.Fatalf("stage png: %v", err)
	}

	if err := pending.Rollback(context.Background()); err != nil {
		t.Fatalf("rollback pending avatar: %v", err)
	}

	entries, err := os.ReadDir(root)
	if err != nil {
		t.Fatalf("read avatar dir: %v", err)
	}
	if len(entries) != 0 {
		t.Fatalf("expected rollback to clean temp files, found %d entries", len(entries))
	}
}

func TestDeleteLegacyKeyDoesNotRemoveVersionedAvatar(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	repo := NewLocalRepo(root)

	legacyPath := filepath.Join(root, "user-123.png")
	versionedPath := filepath.Join(root, "user-123.v4.png")

	if err := os.WriteFile(legacyPath, []byte("legacy"), 0o644); err != nil {
		t.Fatalf("write legacy avatar: %v", err)
	}
	if err := os.WriteFile(versionedPath, []byte("versioned"), 0o644); err != nil {
		t.Fatalf("write versioned avatar: %v", err)
	}

	if err := repo.Delete(context.Background(), "user-123"); err != nil {
		t.Fatalf("delete legacy avatar: %v", err)
	}

	if _, err := os.Stat(legacyPath); !os.IsNotExist(err) {
		t.Fatalf("expected legacy avatar to be deleted, stat err=%v", err)
	}

	data, err := os.ReadFile(versionedPath)
	if err != nil {
		t.Fatalf("expected versioned avatar to remain, read err=%v", err)
	}
	if string(data) != "versioned" {
		t.Fatalf("unexpected versioned avatar contents: %q", string(data))
	}
}
