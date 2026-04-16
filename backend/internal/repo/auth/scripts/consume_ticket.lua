-- Return
--  <email> = ok
-- "unauthorized" = unauthorized
-- "throttled" = throttled

local throttle_key = KEYS[1]
local ticket_key = KEYS[2]

local expect_did = ARGV[1]
local expect_scene = ARGV[2]
local did_rl = tonumber(ARGV[3])
local did_throttle_ttl = tonumber(ARGV[4])


if throttle(throttle_key, did_rl, did_throttle_ttl) == 0 then return "throttled" end

local ticket = redis.call("GET", ticket_key)
if not ticket then return "unauthorized" end

local ticket_val = cjson.decode(ticket)
if ticket_val["device_id"] ~= expect_did then return "unauthorized" end
if ticket_val["scene"] ~= expect_scene then return "unauthorized" end

redis.call("DEL", ticket_key)
return ticket_val["email"]
