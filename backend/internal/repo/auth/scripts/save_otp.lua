-- Return 
-- 1 = ok
-- 0 = throttled
-- -1 = key type mismatch

local otp_key = KEYS[1]
local th_key = KEYS[2]
local queue_key = KEYS[3]

local otp = ARGV[1]
local ttl = tonumber(ARGV[2])
local rl = tonumber(ARGV[3])
local th_ttl = tonumber(ARGV[4])
local queue_payload = ARGV[5]

local otp_key_type = redis.call("TYPE", otp_key)["ok"]
if otp_key_type ~= "none" and otp_key_type ~= "string" then
    return -1
end

local queue_key_type = redis.call("TYPE", queue_key)["ok"]
if queue_key_type ~= "none" and queue_key_type ~= "list" then
    return -1
end

if throttle(th_key, rl, th_ttl) == 0 then
    return 0
end

redis.call("SET", otp_key, otp, "EX", ttl)
redis.call("LPUSH", queue_key, queue_payload)
return 1
