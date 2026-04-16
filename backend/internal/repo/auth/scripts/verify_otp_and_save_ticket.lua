-- Return
--  1 = ok
--  0 = throttled
-- -1 = invalid or expired

local otp_key = KEYS[1]
local short_key = KEYS[2]
local daily_key = KEYS[3]
local ticket_key = KEYS[4]

local otp = ARGV[1]
local short_rl = tonumber(ARGV[2])
local short_ttl = tonumber(ARGV[3])
local daily_rl = tonumber(ARGV[4])
local daily_ttl = tonumber(ARGV[5])
local ticket = ARGV[6]
local ticket_ttl = tonumber(ARGV[7])


if throttle(short_key, short_rl, short_ttl) == 0 then return 0 end
if throttle(daily_key, daily_rl, daily_ttl) == 0 then return 0 end

local stored = redis.call("GET", otp_key)
if not stored then return -1 end
if stored ~= otp then return -1 end

redis.call("DEL", otp_key)
redis.call("SET", ticket_key, ticket, "EX", tonumber(ticket_ttl))
return 1
