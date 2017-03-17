local utils = {}

function utils.regularTypeStr(fullTypeStr)
    local typeStr = 'Unknown'
    local typeLowerStr = string.lower(fullTypeStr)
    
    if (string.match(typeLowerStr, 'ant')) then
        typeStr = 'Antminer'
        
        if (string.match(typeLowerStr, 's9')) then
            typeStr = typeStr .. ' S9'
        end
    end
    
    return typeStr
end

function utils.trimJsonStr(jsonStr)
    -- Fix the invalid JSON struct from Antminer S9
    jsonStr = string.gsub(jsonStr, '"}{"', '"},{"')
    
    -- Remove possible garbage at begin & end
    jsonStr = string.gsub(jsonStr, '^[^{]+{', '{')
    jsonStr = string.gsub(jsonStr, '}[^}]+$', '}')
    
    return jsonStr
end

return utils