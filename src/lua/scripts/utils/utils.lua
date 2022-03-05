local clock = os.clock
local utils = {}

local json = require ("utils.dkjson")

local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

utils.deepCopy = deepCopy

function utils.contains(t, value)
    for _, v in pairs(t) do
      if v == value then
        return true
      end
    end
    return false
end

function utils.removeByValue(t, value)
    for k, v in pairs(t) do
        if v == value then
            return table.remove(t, k)
        end
    end
end

function utils.append(str, new, sep)
    str = str or ""
    new = new or ""
    sep = sep or ", "
    if str == "Normal" and #new > 0 then
        return new
    end
    if #str > 0 and new == "Normal" then
        return str
    end
    if #str > 0 and #new > 0 then
        str = str .. sep
    end
    return str .. new
end

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
    s = tostring(s)
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
    secs = tonumber(secs)
    
    if secs == nil then
        return ""
    end
    
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

function utils.print(data, showMetatable, lastCount)
    if type(data) ~= "table" then
        --Value
        if type(data) == "string" then
            io.write("\"", data, "\"")
        else
            io.write(tostring(data))
        end
    else
        --Format
        local count = lastCount or 0
        count = count + 1
        io.write("{\n")
        --Metatable
        if showMetatable then
            for i = 1,count do 
                io.write("\t") 
            end
            local mt = getmetatable(data)
            io.write("\"__metatable\" = ")
            utils.print(mt, showMetatable, count)
            io.write(",\n")
        end
        --Key
        for key,value in pairs(data) do
            for i = 1,count do 
                io.write("\t") 
            end
            if type(key) == "string" then
                io.write("\"", key, "\" = ")
            elseif type(key) == "number" then
                io.write("[", key, "] = ")
            else
                io.write(tostring(key))
            end
            utils.print(value, showMetatable, count)
            io.write(",\n")
        end
        --Format
        for i = 1,lastCount or 0 do 
            io.write("\t") 
        end
            io.write("}")
    end
    --Format
    if not lastCount then
        io.write("\n")
    end
end

function utils.parseLoginPasswords(passwordListStr)
    passwordList = {}
    passwordLines = utils.stringSplit(passwordListStr, '&')

    for _, line in ipairs(passwordLines) do      
        passwordItems = utils.stringSplit(line, ':')

        if (#passwordItems == 3) then
            passwordRecord = {
                minerType = Crypto.base64Decode(passwordItems[1]),
                userName = Crypto.base64Decode(passwordItems[2]),
                password = Crypto.base64Decode(passwordItems[3])
            }

            table.insert(passwordList, passwordRecord)
        end
    end

    return passwordList
end

-- read & parse the password from OOLuaHelper
-- it will be used by utils.getMinerLoginPassword(minerType)
local LOGIN_PASSWORDS = utils.parseLoginPasswords(OOLuaHelper.opt("login.minerPasswords"))

function utils.getMinerLoginPassword(minerType)
    for _, record in ipairs(LOGIN_PASSWORDS) do
        pos = string.find(string.lower(minerType), string.lower(record.minerType))

        if (pos ~= nil) then
            return record
        end
    end

    return nil
end

function utils.getFileSize(filePath)
    local file = io.open(filePath, "r")
    if (file == nil) then
        return 0
    end
    local size = file:seek("end")
    io.close(file)
    return size
end

function utils.debugInfo(func, err)
    print('--------- '..func..' ---------')
    print('Error:', err)
    print(debug.traceback('--------------------', 2))
end

function utils.debugOutput(title, msg)
    print('--------- '..title..' ---------')
    if msg then
        print(msg)
    end
end

function utils.debugReqInfo(func, context, response, stat)
    print('') -- add an empty line
    print('========= '..func..' =========')
    print('IP:', context:miner():ip())
    print('Host:', context:requestHost()..':'..context:requestPort())
    print('Step:', context:stepName())
    if stat then
        print('Stat:', stat)
    end
    print('--------- Request ---------')
    print(context:requestContent())
    if response then
        print('--------- Response ---------')
        print(response)
    end
end

return utils
