package scripts

import (
	_ "embed"

	"github.com/redis/go-redis/v9"
)

//go:embed throttle_snippet.lua
var throttleSnippet string

//go:embed save_otp.lua
var saveOTP string

//go:embed verify_otp_and_save_ticket.lua
var verifyOTPAndSaveTicket string

//go:embed consume_ticket.lua
var consumeTicket string

//go:embed throttle.lua
var throttle string

func withThrottle(body string) string {
	return throttleSnippet + "\n" + body
}

type Registry struct {
	SaveOTPThrottleAndEnqueue         *redis.Script
	ThrottleAndVerifyOTPAndSaveTicket *redis.Script
	ThrottleAndConsumeTicket          *redis.Script
	Throttle                          *redis.Script
}

func NewRegistry() *Registry {
	return &Registry{
		SaveOTPThrottleAndEnqueue:         redis.NewScript(withThrottle(saveOTP)),
		ThrottleAndVerifyOTPAndSaveTicket: redis.NewScript(withThrottle(verifyOTPAndSaveTicket)),
		ThrottleAndConsumeTicket:          redis.NewScript(withThrottle(consumeTicket)),
		Throttle:                          redis.NewScript(withThrottle(throttle)),
	}
}
