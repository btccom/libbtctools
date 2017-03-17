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

return utils