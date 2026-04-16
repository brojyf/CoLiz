-- Return 
-- 1 = ok
-- 0 = throttled 

local k = KEYS[1]
local rl = tonumber(ARGV[1])
local ttl = tonumber(ARGV[2])

return throttle(k, rl, ttl)