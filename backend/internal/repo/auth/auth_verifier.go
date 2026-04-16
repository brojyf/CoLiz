package auth

import "context"

type AuthVerifier interface {
	DidMatchUID(ctx context.Context, did, uid string) error
}

func (r *repoStore) DidMatchUID(ctx context.Context, did, uid string) error {
	return r.db.didMatchUID(ctx, did, uid)
}
