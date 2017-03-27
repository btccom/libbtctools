local utils = {}

local json = require ("lua.scripts.dkjson")

function utils.trim(str)
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

function utils.trimAll(str)
    return utils.trim(str:gsub("%s+", " "))
end

function utils.trimJsonStr(jsonStr)
    -- Fix the invalid JSON struct from Antminer S9
    jsonStr = string.gsub(jsonStr, '"}{"', '"},{"')
    
    -- Remove possible garbage at begin & end
    jsonStr = string.gsub(jsonStr, '^[^{]+{', '{')
    jsonStr = string.gsub(jsonStr, '}[^}]+$', '}')
    
    return jsonStr
end

function utils.jsonEncode(obj)
    return json.encode(obj)
end

function utils.jsonDecode(jsonStr)
    return json.decode(utils.trimJsonStr(jsonStr))
end

function utils.urlEncode(s)
    s = string.gsub(s, "([^%w%.%- _])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

function utils.urlDecode(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end

function utils.makeUrlQueryString(params, keys)
    local queryStrs = {}
    
    if (keys) then
        for i=1,#keys do
            local k = keys[i] or ""
            local v = params[k] or ""
            table.insert(queryStrs, utils.urlEncode(k) .. '=' .. utils.urlEncode(v))
        end
    else
        for k,v in pairs(params) do
            table.insert(queryStrs, utils.urlEncode(k) .. '=' .. utils.urlEncode(v))
        end
    end
    
    return table.concat(queryStrs, '&')
end

function utils.stringSplit(str, exp)
	local result = {}
	local strlen = #str
	local index = 1
	while index < strlen do
		local start_pos, end_pos = string.find(str, exp, index)
		if start_pos == nil then
			break;
		else
			local match_str = string.sub(str, index, start_pos - 1)
			result[#result + 1] = match_str
			index = end_pos + 1
		end
	end
	result[#result + 1] = string.sub(str, index)
	
	return result
end 

function utils.formatTime(secs, format)
	format = utils.stringSplit(format, ":")
	local radix = {24, 60, 60}
	local time_str = "";
	local base_value, base_name, value
	local i = #radix
	while i > 0 do
		base_value = radix[i]
		base_name = format[i + 1]
		
		value = secs % base_value
		
		if value > 0 then
			if base_name then
				time_str = value .. base_name .. time_str
			end
		end
		
		secs = math.floor(secs / base_value)
		
		i = i - 1
	end
	
	if secs > 0 then
		time_str = secs .. format[i + 1] .. time_str
	end
	
	return time_str 
end

return utils
