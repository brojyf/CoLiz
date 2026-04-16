package user

import (
	"context"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/avpol"
	"github.com/brojyf/CoLiz/internal/repo"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/service/avatarutil"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

func (s *service) UpdateUsername(ctx context.Context, userID, username string) (*domain.User, error) {
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "user.updateUsername.user", err)
			return nil, svc.ErrInternal
		}
	}

	if user.Username == username {
		return user, nil
	}

	if err := s.repo.UpdateUsername(ctx, userID, username); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "user.updateUsername.update", err)
			return nil, svc.ErrInternal
		}
	}

	user.Username = username
	return user, nil
}

func (s *service) UploadAvatar(ctx context.Context, userID string, src io.Reader) (*domain.User, error) {
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "user.uploadAvatar.user", err)
			return nil, svc.ErrInternal
		}
	}

	data, err := avatarutil.NormalizePNG(src, avpol.AvatarSidePixels)
	if err != nil {
		return nil, err
	}

	previousVersion := user.AvatarVersion
	version := previousVersion + 1
	pending, err := s.avatar.StagePNG(ctx, avatarObjectKey(user.ID, version), data)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			logx.Error(ctx, "user.uploadAvatar.stage", err)
			return nil, svc.ErrInternal
		}
	}

	updatedAt := time.Now().UTC()
	if err := pending.Commit(ctx); err != nil {
		if rollbackErr := pending.Rollback(ctx); rollbackErr != nil {
			logx.Error(ctx, "user.uploadAvatar.stageRollback", rollbackErr)
		}
		logx.Error(ctx, "user.uploadAvatar.commit", err)
		return nil, svc.ErrInternal
	}

	if err := s.repo.UpdateAvatarMeta(ctx, user.ID, user.AvatarVersion, version, &updatedAt); err != nil {
		if cleanupErr := s.avatar.Delete(ctx, avatarObjectKey(user.ID, version)); cleanupErr != nil && !errors.Is(cleanupErr, repo.ErrNotFound) {
			logx.Error(ctx, "user.uploadAvatar.cleanupNew", cleanupErr)
		}
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		case errors.Is(err, repo.ErrConflict):
			return nil, svc.ErrConflict
		default:
			logx.Error(ctx, "user.uploadAvatar.meta", err)
			return nil, svc.ErrInternal
		}
	}

	user.AvatarVersion = version
	user.AvatarUpdatedAt = &updatedAt
	s.cleanupSupersededAvatar(ctx, user.ID, previousVersion)

	return user, nil
}

func avatarObjectKey(userID string, version uint32) string {
	return fmt.Sprintf("%s.v%d", userID, version)
}

func (s *service) cleanupSupersededAvatar(ctx context.Context, userID string, previousVersion uint32) {
	if previousVersion > 0 {
		if err := s.avatar.Delete(ctx, avatarObjectKey(userID, previousVersion)); err != nil && !errors.Is(err, repo.ErrNotFound) {
			logx.Error(ctx, "user.uploadAvatar.cleanupPrevious", err)
		}
	}

	if err := s.avatar.Delete(ctx, userID); err != nil && !errors.Is(err, repo.ErrNotFound) {
		logx.Error(ctx, "user.uploadAvatar.cleanupLegacy", err)
	}
}
