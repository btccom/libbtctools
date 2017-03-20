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
            table.insert(queryStrs, utils.urlEncode(keys[i]) .. '=' .. utils.urlEncode(params[keys[i]]))
        end
    else
        for k,v in pairs(params) do
            table.insert(queryStrs, utils.urlEncode(k) .. '=' .. utils.urlEncode(v))
        end
    end
    
    return table.concat(queryStrs, '&')
end

return utils
