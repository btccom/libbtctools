
local scanner = require ("lua.scripts.miner.common-scanner")


function makeRequest(context)
	local _, err = pcall (doMakeRequest, context)
	
	if (err) then
		context:setStepName("end")
		context:miner():setStat(err)
		context:setCanYield(true)
	end
	
end

function makeResult(context, response, stat)
	local _, err = pcall (doMakeResult, context, response, stat)
	
	if (err) then
		context:setStepName("end")
		context:miner():setStat(err)
		context:setCanYield(true)
	end
end

function doMakeRequest(context)
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
		
	else
		context:setStepName("end")
		context:miner():setStat("inner error: unknown step name")
		context:setCanYield(true)
    end
end

function doMakeResult(context, response, stat)
    local step = context:stepName()
    
    if (step == "doFindStats") then
    
        if (stat == "success") then
            step = "findPools"
        else
            step = "end"
        end
        
        context:setStepName(step)
        context:setCanYield(true)
        
        local canYield = scanner.parseMinerStats(response, context:miner(), stat)
		context:setCanYield(canYield)
        
    elseif (step == "doFindPools") then
        context:setStepName("end")
        context:setCanYield(false)
        
        local canYield = scanner.parseMinerPools(response, context:miner(), stat)
		context:setCanYield(canYield)
		
	else
		context:setStepName("end")
		context:miner():setStat("inner error: unknown step name")
		context:setCanYield(true)
    end
end
