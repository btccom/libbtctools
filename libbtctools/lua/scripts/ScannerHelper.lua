-- load library
json = require ("lua.scripts.dkjson")
utils = require ("lua.scripts.utils")

-- load functions
require ("lua.scripts.parseMinerStat")

print ("hello")

function makeRequest(context)
    local step = context:stepName()
    local ip = context:miner():ip()
    
    if (step == "begin") then
        local port = "4028"
        local content = '{"command":"stats"}'
        
        context:setStepName("findStats")
        context:setRequestHost(ip)
        context:setRequestPort(port)
        context:setRequestContent(content)
    end
end

function makeResult(context, response, stat)
    local step = context:stepName()
    
    if (step == "findStats") then
        parseMinerStat(response, context:miner(), stat)
        context:setCanYield(true)
        context:setStepName("end")
    end
end
