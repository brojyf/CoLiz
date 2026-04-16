package middleware

type Middlewares struct {
	Timeout  *Timeout
	ATK      *AccessToken
	Throttle *Throttle
}
