package user

import (
	"context"
	"errors"
	"mime"
	"os"
	"path/filepath"
	"strings"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

func (s *service) ResolveAvatar(ctx context.Context, userID string) (*domain.FileAsset, error) {
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "user.resolveAvatar.user", err)
			return nil, svc.ErrInternal
		}
	}

	if user.AvatarVersion == 0 {
		return s.openDefaultAvatar()
	}

	asset, err := s.avatar.Open(ctx, avatarObjectKey(user.ID, user.AvatarVersion))
	if errors.Is(err, repo.ErrNotFound) {
		asset, err = s.avatar.Open(ctx, user.ID)
	}
	if err != nil {
		switch {
		case errors.Is(err, repo.ErrNotFound):
			return s.openDefaultAvatar()
		case ctxx.IsCtxError(err):
			return nil, err
		}
		logx.Error(ctx, "user.resolveAvatar.open", err)
		return nil, svc.ErrInternal
	}

	updatedAt := asset.ModTime
	if user.AvatarUpdatedAt != nil {
		updatedAt = *user.AvatarUpdatedAt
	}

	asset.WithCacheAge(s.cfg.AvatarCacheMaxAge)
	asset.WithModTime(updatedAt)

	return asset, nil
}

func (s *service) GetProfile(ctx context.Context, uid string) (*domain.User, error) {
	user, err := s.repo.GetUserByID(ctx, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "user.getProfile", err)
			return nil, svc.ErrInternal
		}
	}

	return user, nil
}

func (s *service) SearchByEmail(ctx context.Context, email string) (*domain.User, error) {
	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "friends.searchFriendByEmail", err)
			return nil, svc.ErrInternal
		}
	}

	return user, nil
}

// helper method
func (s *service) openDefaultAvatar() (*domain.FileAsset, error) {
	if s.cfg.DefaultAvatarPath == "" {
		return nil, svc.ErrInternal
	}

	file, err := os.Open(s.cfg.DefaultAvatarPath)
	if err != nil {
		return nil, svc.ErrInternal
	}
	info, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, svc.ErrInternal
	}
	if info.IsDir() {
		file.Close()
		return nil, svc.ErrInternal
	}

	return &domain.FileAsset{
		Name:        filepath.Base(s.cfg.DefaultAvatarPath),
		ContentType: detectAvatarContentType(s.cfg.DefaultAvatarPath),
		Content:     file,
		ModTime:     info.ModTime(),
		CacheAge:    s.cfg.AvatarCacheMaxAge,
	}, nil
}

func detectAvatarContentType(path string) string {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".svg":
		return "image/svg+xml"
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".gif":
		return "image/gif"
	}

	if contentType := mime.TypeByExtension(ext); contentType != "" {
		return contentType
	}
	return "application/octet-stream"
}
