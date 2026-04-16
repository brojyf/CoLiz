package avatar

import (
	"context"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/util/rsc"
)

type ReadSeekCloser = rsc.ReadSeekCloser

type PendingWrite interface {
	Commit(ctx context.Context) error
	Rollback(ctx context.Context) error
}

type Repo interface {
	Open(ctx context.Context, userID string) (*domain.FileAsset, error)
	StagePNG(ctx context.Context, userID string, data []byte) (PendingWrite, error)
	SavePNG(ctx context.Context, userID string, data []byte) error
	Delete(ctx context.Context, userID string) error
}
