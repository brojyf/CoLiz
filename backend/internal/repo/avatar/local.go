package avatar

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/avpol"
	"github.com/brojyf/CoLiz/internal/repo"
)

type localRepo struct {
	root string
}

type pendingWrite struct {
	finalPath  string
	legacyPath string
	tmpPath    string
}

func NewLocalRepo(root string) Repo {
	return &localRepo{
		root: filepath.Clean(root),
	}
}

func (r *localRepo) Open(_ context.Context, userID string) (*domain.FileAsset, error) {
	path, contentType, err := r.existingAvatarPath(userID)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, repo.NewError(repo.ErrNotFound, err)
		}
		return nil, repo.NewError(repo.ErrInternal, err)
	}

	file, err := os.Open(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, repo.NewError(repo.ErrNotFound, err)
		}
		return nil, repo.NewError(repo.ErrInternal, err)
	}

	info, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	if info.IsDir() {
		file.Close()
		return nil, repo.NewError(repo.ErrNotFound, os.ErrNotExist)
	}

	return &domain.FileAsset{
		Name:        filepath.Base(path),
		ContentType: contentType,
		Content:     file,
		ModTime:     info.ModTime(),
	}, nil
}

func (r *localRepo) SavePNG(_ context.Context, userID string, data []byte) error {
	pending, err := r.StagePNG(context.Background(), userID, data)
	if err != nil {
		return err
	}
	if err := pending.Commit(context.Background()); err != nil {
		_ = pending.Rollback(context.Background())
		return err
	}
	return nil
}

func (r *localRepo) Delete(_ context.Context, userID string) error {
	found := false
	for _, ext := range []string{avpol.ExtPNG, avpol.ExtWebp} {
		path, err := r.avatarPath(userID, ext)
		if err != nil {
			return repo.NewError(repo.ErrInternal, err)
		}
		err = os.Remove(path)
		switch {
		case err == nil:
			found = true
		case errors.Is(err, os.ErrNotExist):
			continue
		default:
			return repo.NewError(repo.ErrInternal, err)
		}
	}

	if !found {
		return repo.NewError(repo.ErrNotFound, os.ErrNotExist)
	}

	return nil
}

func (r *localRepo) StagePNG(_ context.Context, userID string, data []byte) (PendingWrite, error) {
	path, err := r.avatarPath(userID, avpol.ExtPNG)
	if err != nil {
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, repo.NewError(repo.ErrInternal, err)
	}

	tmp, err := os.CreateTemp(filepath.Dir(path), "avatar-*.png")
	if err != nil {
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	tmpPath := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		_ = os.Remove(tmpPath)
		return nil, repo.NewError(repo.ErrInternal, err)
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return nil, repo.NewError(repo.ErrInternal, err)
	}

	legacyPath, err := r.avatarPath(userID, avpol.ExtWebp)
	if err == nil && legacyPath != path {
		return &pendingWrite{
			finalPath:  path,
			legacyPath: legacyPath,
			tmpPath:    tmpPath,
		}, nil
	}

	return &pendingWrite{
		finalPath: path,
		tmpPath:   tmpPath,
	}, nil
}

func (w *pendingWrite) Commit(_ context.Context) error {
	if err := os.Rename(w.tmpPath, w.finalPath); err != nil {
		return repo.NewError(repo.ErrInternal, err)
	}
	if w.legacyPath != "" && w.legacyPath != w.finalPath {
		_ = os.Remove(w.legacyPath)
	}
	w.tmpPath = ""
	return nil
}

func (w *pendingWrite) Rollback(_ context.Context) error {
	if w.tmpPath == "" {
		return nil
	}
	if err := os.Remove(w.tmpPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return repo.NewError(repo.ErrInternal, err)
	}
	w.tmpPath = ""
	return nil
}

// Helper methods
func (r *localRepo) existingAvatarPath(userID string) (string, string, error) {
	candidates := []struct {
		ext         string
		contentType string
	}{
		{ext: avpol.ExtPNG, contentType: avpol.ContentTypePNG},
		{ext: avpol.ExtWebp, contentType: avpol.ContentTypeWEBP},
	}

	for _, candidate := range candidates {
		path, err := r.avatarPath(userID, candidate.ext)
		if err != nil {
			return "", "", err
		}
		info, err := os.Stat(path)
		if err == nil && !info.IsDir() {
			return path, candidate.contentType, nil
		}
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			return "", "", err
		}
	}

	return "", "", os.ErrNotExist
}

func (r *localRepo) avatarPath(userID string, ext string) (string, error) {
	root, err := filepath.Abs(r.root)
	if err != nil || root == "" {
		return "", errors.New("invalid avatar root")
	}

	path := filepath.Join(root, userID+ext)
	cleaned := filepath.Clean(path)
	rootPrefix := root + string(os.PathSeparator)
	if cleaned != root && !strings.HasPrefix(cleaned, rootPrefix) {
		return "", errors.New("avatar path escaped root")
	}

	return cleaned, nil
}
