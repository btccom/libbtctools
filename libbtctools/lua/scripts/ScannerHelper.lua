-- load library
json = require ("lua.scripts.dkjson")
utils = require ("lua.scripts.utils")
http = require ("lua.scripts.http")

-- load functions
require ("lua.scripts.parseScanResponse")

local a = Crypto.base64Encode("hello------------------454545454545454545454545454545454545454545454545454545454545454545454545454545454545refsdaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabc")
print ("hello", a)
print ("hello", Crypto.base64Decode(a))

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
        
        local canYield = parseMinerStats(response, context:miner(), stat)
		context:setCanYield(canYield)
        
    elseif (step == "doFindPools") then
        context:setStepName("end")
        context:setCanYield(false)
        
        local canYield = parseMinerPools(response, context:miner(), stat)
		context:setCanYield(canYield)
		
	else
		context:setStepName("end")
		context:miner():setStat("inner error: unknown step name")
		context:setCanYield(true)
    end
end
