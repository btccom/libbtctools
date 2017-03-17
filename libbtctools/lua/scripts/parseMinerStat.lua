function parseMinerStat(jsonStr, miner, stat)
    -- Init miner table
    local typeStr = 'Unknown'
    local fullTypeStr = 'Unknown'
    
    if (stat == "success") then
        -- Fix the invalid JSON struct from Antminer S9
        jsonStr = string.gsub(jsonStr, '"}{"', '"},{"')
        
        -- Remove possible garbage at begin & end
        jsonStr = string.gsub(jsonStr, '^[^{]+{', '{')
        jsonStr = string.gsub(jsonStr, '}[^}]+$', '}')
        
        local obj, pos, err = json.decode (jsonStr)
        
        if not err then
            local stat = obj.STATS
            
            if (type(stat) == "table" and type(stat[1]) == "table" and type(stat[1].Type) == "string") then
                fullTypeStr = stat[1].Type
            end
            
            typeStr = utils.regularTypeStr(fullTypeStr)
        end
    end
    
    miner:setStat(stat)
    miner:setType(typeStr)
    miner:setFullTypeStr(fullTypeStr)
end
