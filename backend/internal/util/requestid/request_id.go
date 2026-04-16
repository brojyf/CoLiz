package requestid

import "context"

type key struct{}

func With(ctx context.Context, rid string) context.Context {
	return context.WithValue(ctx, key{}, rid)
}
func From(ctx context.Context) (string, bool) {
	v := ctx.Value(key{})
	r, ok := v.(string)
	return r, ok
}
