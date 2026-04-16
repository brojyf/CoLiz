package ratelimit

import "time"

type RLWindow struct {
	RL  int
	TTL time.Duration
}

func New(rl int, ttl time.Duration) RLWindow {
	return RLWindow{
		RL:  rl,
		TTL: ttl,
	}
}
