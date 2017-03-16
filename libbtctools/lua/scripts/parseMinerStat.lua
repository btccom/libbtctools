function parseMinerStat(jsonStr)
    local json = require ("lua.scripts.dkjson")
    
    -- Fix the invalid JSON struct from Antminer S9
    jsonStr = string.gsub(jsonStr, '"}{"', '"},{"')
    
    -- Remove possible garbage at begin & end
    jsonStr = string.gsub(jsonStr, '^[^{]+{', '{')
    jsonStr = string.gsub(jsonStr, '}[^}]+$', '}')
    
    local obj, pos, err = json.decode (jsonStr)
    
    if err then
        return nil
    else
        local typeStr = obj.STATS[1].Type
        print (typeStr)
    end
end