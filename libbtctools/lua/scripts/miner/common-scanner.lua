local scanner = {}

local json = require ("lua.scripts.dkjson")
local utils = require ("lua.scripts.utils")


local regularTypeStr = function(fullTypeStr)
    local typeStr = 'unknown'
    local typeLowerStr = string.lower(fullTypeStr)
    
    if (string.match(typeLowerStr, 'antminer')) then
        typeStr = 'antminer'
        
        if (string.match(typeLowerStr, 's9')) then
            typeStr = typeStr .. '-s9'
        else
            typeStr = 'unknown'
        end
    end
    
    return typeStr
end

function scanner.parseMinerStats(jsonStr, miner, stat)

    local typeStr = 'unknown'
    local fullTypeStr = 'Unknown'
    
    if (stat == "success") then
        local obj, pos, err = utils.jsonDecode (jsonStr)
        
        if not err then
            local stat = obj.STATS
            
            if (type(stat) == "table" and type(stat[1]) == "table" and type(stat[1].Type) == "string") then
                fullTypeStr = stat[1].Type
            end
            
            typeStr = regularTypeStr(fullTypeStr)
        end
    else
        fullTypeStr = ''
    end
    
    miner:setStat(stat)
    miner:setTypeStr(typeStr)
    miner:setFullTypeStr(fullTypeStr)
    
    return true
end

function scanner.parseMinerPools(jsonStr, miner, stat)

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

return scanner
