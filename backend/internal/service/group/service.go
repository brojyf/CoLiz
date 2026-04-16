package group

import (
	"context"
	"io"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	txinfra "github.com/brojyf/CoLiz/internal/infra/tx"
	avatarrepo "github.com/brojyf/CoLiz/internal/repo/avatar"
	"github.com/brojyf/CoLiz/internal/repo/group"
)

type Service interface {
	ResolveAvatar(ctx context.Context, groupID string) (*domain.FileAsset, error)
	Get(ctx context.Context, uid string) ([]domain.Group, error)
	Create(ctx context.Context, uid, name string) (*domain.Group, error)
	GetDetail(ctx context.Context, groupID, userID string) (*domain.Group, []domain.User, error)
	UpdateName(ctx context.Context, groupID, userID, name string) (*domain.Group, error)
	Delete(ctx context.Context, groupID, userID string) error
	Invite(ctx context.Context, groupID, inviterID, inviteeID string) error
	Leave(ctx context.Context, groupID, userID string) error
	RemoveMember(ctx context.Context, gid, uid, ridD string) error
	UploadAvatar(ctx context.Context, groupID, userID string, src io.Reader) (*domain.Group, error)
}

type service struct {
	cfg    Config
	repo   group.Repo
	tx     *txinfra.Transactor
	avatar avatarrepo.Repo
}

type Config struct {
	AvatarCacheMaxAge time.Duration
	DefaultAvatarPath string
}

func NewService(c Config, r group.Repo, t *txinfra.Transactor, a avatarrepo.Repo) Service {
	return &service{cfg: c, repo: r, tx: t, avatar: a}
}
