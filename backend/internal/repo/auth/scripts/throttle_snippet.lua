-- Return 
-- 1 = ok
-- 0 = throttled 

local function throttle(key, rl, ttl)
    rl = tonumber(rl)
    ttl = tonumber(ttl)
    if rl and rl > 0 then
        local count = redis.call("INCR", key)
        if count == 1 then redis.call("EXPIRE", key, ttl) end
        if count > rl then return 0 end
    end
    return 1
end