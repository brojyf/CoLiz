package domain

import (
	"time"

	"github.com/brojyf/CoLiz/internal/util/rsc"
)

type FileAsset struct {
    Name string
    ContentType string
    Content     rsc.ReadSeekCloser
    ModTime     time.Time
    CacheAge    time.Duration
}

func (f *FileAsset) WithCacheAge(t time.Duration) {
    f.CacheAge = t
}

func (f *FileAsset) WithModTime(t time.Time) {
    f.ModTime = t
}




