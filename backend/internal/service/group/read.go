package group

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

func (s *service) ResolveAvatar(ctx context.Context, groupID string) (*domain.FileAsset, error) {
	group, err := s.repo.GetByID(ctx, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "group.resolveAvatar.group", err)
			return nil, svc.ErrInternal
		}
	}

	if group.AvatarVersion == 0 {
		return s.openDefaultAvatar()
	}

	asset, err := s.avatar.Open(ctx, avatarObjectKey(group.ID, group.AvatarVersion))
	if errors.Is(err, repo.ErrNotFound) {
		asset, err = s.avatar.Open(ctx, group.ID)
	}
	if err != nil {
		switch {
		case errors.Is(err, repo.ErrNotFound):
			return s.openDefaultAvatar()
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			logx.Error(ctx, "group.resolveAvatar.open", err)
			return nil, svc.ErrInternal
		}
	}

	updatedAt := asset.ModTime
	if group.AvatarUpdatedAt != nil {
		updatedAt = *group.AvatarUpdatedAt
	}

	return &domain.FileAsset{
		Name:        asset.Name,
		ContentType: asset.ContentType,
		Content:     asset.Content,
		ModTime:     updatedAt,
		CacheAge:    s.cfg.AvatarCacheMaxAge,
	}, nil
}

func (s *service) Get(ctx context.Context, uid string) ([]domain.Group, error) {
	groups, err := s.repo.Get(ctx, uid)
	if err != nil {
		if ctxx.IsCtxError(err) {
			return nil, err
		}
		logx.Error(ctx, "group.getGroups", err)
		return nil, svc.ErrInternal
	}
	return groups, nil
}

func (s *service) GetDetail(ctx context.Context, groupID, userID string) (*domain.Group, []domain.User, error) {
	group, err := s.repo.GetDetail(ctx, groupID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "group.getDetail.group", err)
			return nil, nil, svc.ErrInternal
		}
	}

	members, err := s.repo.GetMembers(ctx, groupID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, nil, err
		default:
			logx.Error(ctx, "group.getDetail.members", err)
			return nil, nil, svc.ErrInternal
		}
	}

	return group, members, nil
}

// Helper methods
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
