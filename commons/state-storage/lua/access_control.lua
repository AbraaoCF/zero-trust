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

local global_timestamp = 0
local global_cost = 0

function parse_json(json_str)
        local data = {}
        -- Attempt to extract the part inside the brackets
        local values_str = json_str:match("%b[]")

        if not values_str then
                return data
        end
        -- Remove brackets and split the entries by comma
        values_str = values_str:gsub("%s+", ""):gsub("%[", ""):gsub("%]", "")

        for entry in values_str:gmatch("([^,]+)") do
                -- Trim whitespace
                entry = entry:gsub("^%s*(.-)%s*$", "%1")
                table.insert(data, entry)
        end
        return data
end

function envoy_on_request(request_handle)
        -- Store the x-timestamp header in the global variable
        local header_timestamp = request_handle:headers():get("x-timestamp")

        if header_value then
                global_timestamp = header_value
        end
      local header_cost = request_handle:headers():get("x-cost")

      if header_cost then
              global_cost = header_cost
      end
end

function envoy_on_response(response_handle)
  if not response_handle then
        return
  end

  local body = response_handle:body():getBytes(0, response_handle:body():length())
  local sum = 0
  -- Convert the body from bytes to string
  local body_str = tostring(body)

  -- Parse the JSON response using custom function
  local parsed_values = parse_json(body_str)
  for _, entry in ipairs(parsed_values) do
        -- Match the timestamp and cost
        local timestamp, cost = entry:match("([^:]+):([^:]+)")
        timestamp = timestamp and timestamp:gsub('"', '') or nil
        cost = cost and cost:gsub('"', '') or nil
        if timestamp and cost then
          if tonumber(timestamp) > tonumber(global_timestamp) then
                sum = sum + tonumber(cost)
          end
        end
  end
  -- Set the new body with the sum
  response_handle:body():setBytes(tostring(sum))
  response_handle:headers():remove("content-length")
  response_handle:headers():add("content-length", tostring(#tostring(sum)))

  local path = "/LPUSH/"
  .. url_encode(key)
  .. "/"
  .. global_cost

  local headers, body = request_handle:httpCall(STATE_STORAGE_CLUSTER, {
    [":method"] = "GET",
    [":path"] = path,
    [":authority"] = STATE_STORAGE_CLUSTER,
  }, "", 1000)
end
