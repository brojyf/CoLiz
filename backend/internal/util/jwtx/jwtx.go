package jwtx

import (
	"errors"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type ATKClaims struct {
	UserID   string `json:"user_id"`
	DeviceID string `json:"device_id"`
	jwt.RegisteredClaims
}

type JWTX interface {
	SignATK(uid, did string) (string, error)
	ParseATK(token string) (*ATKClaims, error)
	UpdateKeys(curVersion string, keys map[string][]byte)
}

type Config struct {
	ISS           string
	ATKExpiresIn  int64
	CurKeyVersion string
	Keys          map[string][]byte
}

type jwtx struct {
	mu  sync.RWMutex
	cfg *Config
}

func NewJWTX(cfg *Config) JWTX {
	return &jwtx{cfg: cfg}
}

// UpdateKeys hot-swaps the signing key set. Safe to call concurrently.
// The new keys map must not be modified by the caller after this call.
func (j *jwtx) UpdateKeys(curVersion string, keys map[string][]byte) {
	j.mu.Lock()
	defer j.mu.Unlock()
	j.cfg.CurKeyVersion = curVersion
	j.cfg.Keys = keys
}

func (j *jwtx) SignATK(uid, did string) (string, error) {
	j.mu.RLock()
	curVersion := j.cfg.CurKeyVersion
	secret, ok := j.cfg.Keys[curVersion]
	j.mu.RUnlock()

	if !ok || secret == nil {
		return "", errors.New("can't find jwt key")
	}

	now := time.Now()
	claims := &ATKClaims{
		UserID:   uid,
		DeviceID: did,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    j.cfg.ISS,
			Subject:   uid,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(time.Second * time.Duration(j.cfg.ATKExpiresIn))),
		},
	}

	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tok.Header["kid"] = curVersion
	return tok.SignedString(secret)
}

func (j *jwtx) ParseATK(token string) (*ATKClaims, error) {
	// Snapshot the keys map reference under the read lock.
	// UpdateKeys always replaces the map (never mutates it), so the
	// snapshot remains valid for the lifetime of this call.
	j.mu.RLock()
	keys := j.cfg.Keys
	j.mu.RUnlock()

	claims := &ATKClaims{}
	keyFunc := func(t *jwt.Token) (any, error) {
		if t.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, errors.New("unexpected signing method")
		}
		kid, ok := t.Header["kid"].(string)
		if !ok || kid == "" {
			return nil, errors.New("missing kid")
		}
		secret, ok := keys[kid]
		if !ok || secret == nil {
			return nil, errors.New("can't find jwt key")
		}
		return secret, nil
	}

	tok, err := jwt.ParseWithClaims(
		token,
		claims,
		keyFunc,
		jwt.WithIssuer(j.cfg.ISS),
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
	)
	if err != nil {
		return nil, err
	}
	if !tok.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}
