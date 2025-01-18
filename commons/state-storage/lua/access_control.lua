JSON = (loadfile("/var/lib/lua/JSON.lua"))()

STATE_STORAGE_CLUSTER = "state-storage"

local function url_encode(str)
	if str then
		str = string.gsub(str, "\n", "\r\n")
		str = string.gsub(str, "([^%w%-%.%_%~])", function(c)
			return string.format("%%%02X", string.byte(c))
		end)
	end
	return str
end

local function generate_redis_script()
	local script = [[
local key = KEYS[1]
local start = KEYS[2]
local new_cost = KEYS[3]
local current = tostring(KEYS[4])

redis.call("ZREMRANGEBYLEX", key, "[0", "(" .. start)

local key_members = redis.call("ZRANGE", key, 0, -1, "WITHSCORES")

local key_sum = 0
for i = 2, #key_members, 2 do
    key_sum = key_sum + tonumber(key_members[i])
end

redis.call("ZINCRBY", key, new_cost, current)

return key_sum
]]

	return script
end

function envoy_on_request(request_handle)
	local path_call = request_handle:headers():get(":path")

    local key, start, cost, timestamp = string.match(path_call, "/([^/]+)/([^/]+)/([^/]+)/([^/]+)")

	local script = generate_redis_script()

	local path = "/EVAL/"
		.. url_encode(script)
		.. "/4/"
		.. url_encode(key)
		.. "/"
		.. url_encode(start)
		.. "/"
		.. cost
		.. "/"
		.. timestamp

	local headers, body = request_handle:httpCall(STATE_STORAGE_CLUSTER, {
		[":method"] = "GET",
		[":path"] = path,
		[":authority"] = STATE_STORAGE_CLUSTER,
	}, "", 1000)

	if headers[":status"] == "200" then
		local data = JSON:decode(body)
		local sum = data["EVAL"]
		request_handle:respond({ [":status"] =  headers[":status"] }, sum)
	else
		request_handle:respond({ [":status"] =  headers[":status"] }, body)
	end
end
