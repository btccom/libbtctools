-- load library
json = require ("lua.scripts.dkjson")
utils = require ("lua.scripts.utils")

-- load functions
require ("lua.scripts.parseScanResponse")

print ("hello")

function makeRequest(context)
    local step = context:stepName()
    local ip = context:miner():ip()
    
    if (step == "begin") then
        local port = "4028"
        local content = '{"command":"stats"}'
        
        context:setStepName("doFindStats")
        context:setRequestHost(ip)
        context:setRequestPort(port)
        context:setRequestContent(content)
        
    elseif (step == "findPools") then
        local content = '{"command":"pools"}'
        
        context:setStepName("doFindPools")
        context:setRequestContent(content)
    end
end

function makeResult(context, response, stat)
    local step = context:stepName()
    
    if (step == "doFindStats") then
    
        if (stat == "success") then
            step = "findPools"
        else
            step = "end"
        end
        
        context:setStepName(step)
        context:setCanYield(true)
        
        local canYield = parseMinerStats(response, context:miner(), stat)
        context:setCanYield(canYield)
        
    elseif (step == "doFindPools") then
        context:setStepName("end")
        context:setCanYield(false)
        
        local canYield = parseMinerPools(response, context:miner(), stat)
        
        context:setCanYield(canYield)
    end
end
