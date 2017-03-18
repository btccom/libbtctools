function parseMinerStats(jsonStr, miner, stat)

    local typeStr = 'Unknown'
    local fullTypeStr = 'Unknown'
    
    if (stat == "success") then
        jsonStr = utils.trimJsonStr(jsonStr)
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
    
    return true
end

function parseMinerPools(jsonStr, miner, stat)

    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()
    
    local findSuccess = false
    
    if (stat == "success") then
        jsonStr = utils.trimJsonStr(jsonStr)
        local obj, pos, err = json.decode (jsonStr)
        
        if not err then
            local pools = obj.POOLS
            
            if (type(pools) == "table") then
                if (type(pools[1]) == "table") then
                    pool1:setUrl(pools[1].URL)
                    pool1:setWorker(pools[1].User)
                end
                
                if (type(pools[2]) == "table") then
                    pool2:setUrl(pools[2].URL)
                    pool2:setWorker(pools[2].User)
                end
                
                if (type(pools[3]) == "table") then
                    pool3:setUrl(pools[3].URL)
                    pool3:setWorker(pools[3].User)
                end
                
                findSuccess = true
            end
        end
    end
    
    return findSuccess
end
