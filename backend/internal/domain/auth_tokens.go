package domain

import "github.com/brojyf/CoLiz/internal/dto"

type AuthTokens struct {
	AccessToken  string
	TokenType    string
	ExpiresIn    int64
	RefreshToken string
}

type AuthTokensOption func(*AuthTokens)

func NewAuthTokens(opts ...AuthTokensOption) *AuthTokens {
	t := &AuthTokens{}
	for _, opt := range opts {
		opt(t)
	}
	return t
}

func WithAccessToken(token string) AuthTokensOption {
	return func(t *AuthTokens) {
		t.AccessToken = token
	}
}

func WithTokenType(tokenType string) AuthTokensOption {
	return func(t *AuthTokens) {
		t.TokenType = tokenType
	}
}

func WithExpiresIn(expiresIn int64) AuthTokensOption {
	return func(t *AuthTokens) {
		t.ExpiresIn = expiresIn
	}
}

func WithRefreshToken(refreshToken string) AuthTokensOption {
	return func(t *AuthTokens) {
		t.RefreshToken = refreshToken
	}
}

func (a *AuthTokens) ToDTO() dto.AuthTokens {
	return dto.AuthTokens{
		AccessToken:  a.AccessToken,
		TokenType:    a.TokenType,
		ExpiresIn:    a.ExpiresIn,
		RefreshToken: a.RefreshToken,
	}
}
