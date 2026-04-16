package config

import (
	"bufio"
	"context"
	"log"
	"os"
	"strings"
	"time"
)

// RotationUpdater is satisfied by jwtx.JWTX.
type RotationUpdater interface {
	UpdateKeys(curVersion string, keys map[string][]byte)
}

// TokenUpdater is satisfied by authsvc.Service.
type TokenUpdater interface {
	UpdateTokenConfig(curVersion string, pepperMap map[string][]byte)
}

// RotationWatcher polls the rotation.env file and hot-swaps JWT keys and RTK
// peppers into the running process whenever the current key version changes.
type RotationWatcher struct {
	path         string
	interval     time.Duration
	jwtUpdater   RotationUpdater
	tokenUpdater TokenUpdater
	lastVersion  string
}

func NewRotationWatcher(
	path string,
	interval time.Duration,
	jwt RotationUpdater,
	token TokenUpdater,
) *RotationWatcher {
	return &RotationWatcher{
		path:         path,
		interval:     interval,
		jwtUpdater:   jwt,
		tokenUpdater: token,
	}
}

// Start launches the polling goroutine. It returns immediately; the goroutine
// stops when ctx is cancelled.
func (w *RotationWatcher) Start(ctx context.Context) {
	go func() {
		ticker := time.NewTicker(w.interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if err := w.reload(); err != nil {
					log.Printf("[rotation_watcher] reload: %v", err)
				}
			}
		}
	}()
}

func (w *RotationWatcher) reload() error {
	env, err := parseEnvFile(w.path)
	if err != nil {
		return err
	}

	newVersion := env["JWT_CUR_KEY_VERSION"]
	if newVersion == "" || newVersion == w.lastVersion {
		return nil
	}

	jwtKeys := parseVersionedSecrets(newVersion, env["JWT_KEY"], env["JWT_KEYS"])
	rtkVersion := env["AUTH_RTK_PEPPER_VERSION"]
	rtkPeppers := parseVersionedSecrets(rtkVersion, env["AUTH_RTK_PEPPER"], env["AUTH_RTK_PEPPERS"])

	w.jwtUpdater.UpdateKeys(newVersion, jwtKeys)
	w.tokenUpdater.UpdateTokenConfig(rtkVersion, rtkPeppers)
	w.lastVersion = newVersion

	log.Printf("[rotation_watcher] reloaded jwt_version=%s rtk_version=%s", newVersion, rtkVersion)
	return nil
}

func parseEnvFile(path string) (map[string]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	env := make(map[string]string)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		env[strings.TrimSpace(key)] = strings.TrimSpace(value)
	}
	return env, scanner.Err()
}
