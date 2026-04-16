package user

import (
	"context"
	"io"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	avatarrepo "github.com/brojyf/CoLiz/internal/repo/avatar"
	userrepo "github.com/brojyf/CoLiz/internal/repo/user"
)

type Service interface {
	ResolveAvatar(ctx context.Context, userID string) (*domain.FileAsset, error)
	GetProfile(ctx context.Context, userID string) (*domain.User, error)
	UpdateUsername(ctx context.Context, userID, username string) (*domain.User, error)
	SearchByEmail(ctx context.Context, email string) (*domain.User, error)
	UploadAvatar(ctx context.Context, userID string, src io.Reader) (*domain.User, error)
}

type Config struct {
	AvatarCacheMaxAge time.Duration
	DefaultAvatarPath string
}

type service struct {
	cfg    Config
	repo   userrepo.Repo
	avatar avatarrepo.Repo
}

func NewService(c Config, r userrepo.Repo, a avatarrepo.Repo) Service {
	return &service{
		cfg:    c,
		repo:   r,
		avatar: a,
	}
}
