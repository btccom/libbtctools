function parseMinerStat(jsonStr, miner)
    -- Init miner table
    miner.typeStr = 'Unknown'
    miner.fullTypeStr = 'Unknown'
    
    -- Fix the invalid JSON struct from Antminer S9
    jsonStr = string.gsub(jsonStr, '"}{"', '"},{"')
    
    -- Remove possible garbage at begin & end
    jsonStr = string.gsub(jsonStr, '^[^{]+{', '{')
    jsonStr = string.gsub(jsonStr, '}[^}]+$', '}')
    
    local obj, pos, err = json.decode (jsonStr)
    
    if err then
        miner.parseError = err
    else
        local stat = obj.STATS
        
        if (type(stat) == "table" and type(stat[1]) == "table" and type(stat[1].Type) == "string") then
            miner.fullTypeStr = stat[1].Type
        end
        
        miner.typeStr = utils.regularTypeStr(miner.fullTypeStr)
    end
    
    print (miner.typeStr)

    return miner
end
