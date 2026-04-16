package group

import (
	"context"
	"database/sql"
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

func (s *service) Create(ctx context.Context, uid, name string) (*domain.Group, error) {
	p, err := domain.NewGroup(
		domain.WithNewGroupID(),
		domain.WithGroupName(name),
		domain.WithGroupOwner(uid),
		domain.WithGroupCreatedAt(time.Now()),
	)
	if err != nil {
		logx.Error(ctx, "group.createGroup", err)
		return nil, svc.ErrInternal
	}

	var group *domain.Group
	err = s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		var innerErr error
		group, innerErr = store.Create(ctx, p)
		return innerErr
	})
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrConflict):
			return nil, svc.ErrConflict
		default:
			logx.Error(ctx, "group.createGroup", err)
			return nil, svc.ErrInternal
		}
	}
	return group, nil
}

func (s *service) UpdateName(ctx context.Context, groupID, userID, name string) (*domain.Group, error) {
	group, err := s.repo.GetDetail(ctx, groupID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "group.updateName.access", err)
			return nil, svc.ErrInternal
		}
	}

	if group.Name == name {
		return group, nil
	}

	err = s.repo.UpdateName(ctx, groupID, userID, name)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrConflict):
			return nil, svc.ErrConflict
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "group.updateName.update", err)
			return nil, svc.ErrInternal
		}
	}

	group.Name = name
	return group, nil
}

func (s *service) Delete(ctx context.Context, groupID, userID string) error {
	group, err := s.repo.GetDetail(ctx, groupID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrUnauthorized):
			return svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return svc.ErrNotFound
		default:
			logx.Error(ctx, "group.delete.access", err)
			return svc.ErrInternal
		}
	}
	if group.Owner != userID {
		return svc.ErrUnauthorized
	}

	err = s.tx.WithinTx(ctx, func(ctx context.Context, tx *sql.Tx) error {
		store := s.repo.BeginTx(tx)
		canDelete, innerErr := store.CanDelete(ctx, groupID)
		if innerErr != nil {
			switch {
			case ctxx.IsCtxError(innerErr):
				return innerErr
			default:
				logx.Error(ctx, "group.delete.canDelete", innerErr)
				return svc.ErrInternal
			}
		}
		if !canDelete {
			return svc.ErrGroupNotSettled
		}
		if innerErr = store.Delete(ctx, groupID, userID); innerErr != nil {
			switch {
			case ctxx.IsCtxError(innerErr):
				return innerErr
			case repo.IsNotFound(innerErr):
				return svc.ErrNotFound
			default:
				logx.Error(ctx, "group.delete.delete", innerErr)
				return svc.ErrInternal
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	s.cleanupDeletedAvatar(ctx, group.ID, group.AvatarVersion)

	return nil
}

func (s *service) Invite(ctx context.Context, groupID, inviterID, inviteeID string) error {
	err := s.repo.Invite(ctx, groupID, inviterID, inviteeID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrUnauthorized):
			return svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return svc.ErrNotFound
		case errors.Is(err, repo.ErrConflict):
			return svc.ErrConflict
		default:
			logx.Error(ctx, "group.inviteFriend", err)
			return svc.ErrInternal
		}
	}

	return nil
}

func (s *service) Leave(ctx context.Context, groupID, userID string) error {
	group, err := s.repo.GetDetail(ctx, groupID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrUnauthorized):
			return svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return svc.ErrNotFound
		default:
			logx.Error(ctx, "group.leave.access", err)
			return svc.ErrInternal
		}
	}
	if group.Owner == userID {
		return svc.ErrOwnerCannotLeave
	}

	canLeave, err := s.repo.CanLeave(ctx, groupID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		default:
			logx.Error(ctx, "group.leave.canLeave", err)
			return svc.ErrInternal
		}
	}
	if !canLeave {
		return svc.ErrMemberNotSettled
	}

	if err := s.repo.Leave(ctx, groupID, userID); err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrUnauthorized):
			return svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return svc.ErrNotFound
		default:
			logx.Error(ctx, "group.leave.leave", err)
			return svc.ErrInternal
		}
	}

	return nil
}

func (s *service) RemoveMember(ctx context.Context, gid, uid, rid string) error {
	group, members, err := s.GetDetail(ctx, gid, uid)
	if err != nil {
		return err
	}

	if !group.IsOwner(uid) {
		return svc.ErrUnauthorized
	}
	if rid == group.Owner {
		return svc.ErrConflict
	}

	isMember := false
	for _, member := range members {
		if member.ID == rid {
			isMember = true
			break
		}
	}
	if !isMember {
		return svc.ErrNotFound
	}

	return s.Leave(ctx, gid, rid)
}

func (s *service) UploadAvatar(ctx context.Context, groupID, userID string, src io.Reader) (*domain.Group, error) {
	group, err := s.repo.GetDetail(ctx, groupID, userID)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrUnauthorized):
			return nil, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		default:
			logx.Error(ctx, "group.uploadAvatar.group", err)
			return nil, svc.ErrInternal
		}
	}
	data, err := avatarutil.NormalizePNG(src, avpol.AvatarSidePixels)
	if err != nil {
		return nil, err
	}

	previousVersion := group.AvatarVersion
	version := previousVersion + 1
	pending, err := s.avatar.StagePNG(ctx, avatarObjectKey(group.ID, version), data)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		default:
			logx.Error(ctx, "group.uploadAvatar.stage", err)
			return nil, svc.ErrInternal
		}
	}

	updatedAt := time.Now().UTC()
	if err := pending.Commit(ctx); err != nil {
		if rollbackErr := pending.Rollback(ctx); rollbackErr != nil {
			logx.Error(ctx, "group.uploadAvatar.stageRollback", rollbackErr)
		}
		logx.Error(ctx, "group.uploadAvatar.commit", err)
		return nil, svc.ErrInternal
	}

	if err := s.repo.UpdateAvatarMeta(ctx, group.ID, group.AvatarVersion, version, &updatedAt); err != nil {
		if cleanupErr := s.avatar.Delete(ctx, avatarObjectKey(group.ID, version)); cleanupErr != nil && !errors.Is(cleanupErr, repo.ErrNotFound) {
			logx.Error(ctx, "group.uploadAvatar.cleanupNew", cleanupErr)
		}
		switch {
		case ctxx.IsCtxError(err):
			return nil, err
		case errors.Is(err, repo.ErrNotFound):
			return nil, svc.ErrNotFound
		case errors.Is(err, repo.ErrConflict):
			return nil, svc.ErrConflict
		default:
			logx.Error(ctx, "group.uploadAvatar.meta", err)
			return nil, svc.ErrInternal
		}
	}

	group.AvatarVersion = version
	group.AvatarUpdatedAt = &updatedAt
	s.cleanupSupersededAvatar(ctx, group.ID, previousVersion)
	return group, nil
}

func avatarObjectKey(groupID string, version uint32) string {
	return fmt.Sprintf("%s.v%d", groupID, version)
}

func (s *service) cleanupSupersededAvatar(ctx context.Context, groupID string, previousVersion uint32) {
	if previousVersion > 0 {
		if err := s.avatar.Delete(ctx, avatarObjectKey(groupID, previousVersion)); err != nil && !errors.Is(err, repo.ErrNotFound) {
			logx.Error(ctx, "group.uploadAvatar.cleanupPrevious", err)
		}
	}

	if err := s.avatar.Delete(ctx, groupID); err != nil && !errors.Is(err, repo.ErrNotFound) {
		logx.Error(ctx, "group.uploadAvatar.cleanupLegacy", err)
	}
}

func (s *service) cleanupDeletedAvatar(ctx context.Context, groupID string, currentVersion uint32) {
	if currentVersion > 0 {
		if err := s.avatar.Delete(ctx, avatarObjectKey(groupID, currentVersion)); err != nil && !errors.Is(err, repo.ErrNotFound) {
			logx.Error(ctx, "group.delete.avatarCurrent", err)
		}
	}

	if err := s.avatar.Delete(ctx, groupID); err != nil && !errors.Is(err, repo.ErrNotFound) {
		logx.Error(ctx, "group.delete.avatarLegacy", err)
	}
}
