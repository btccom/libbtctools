-- load library
json = require ("lua.scripts.dkjson")
utils = require ("lua.scripts.utils")
http = require ("lua.scripts.http")

-- load functions
--require ("lua.scripts.httpTest")
minerTest = require ("lua.scripts.miner.test")

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
	local typeStr = context:miner():typeStr()
	
    if (typeStr == "test") then
		minerTest.doMakeRequest(context)
	else
		context:setStepName("end")
		context:miner():setStat("Don't support: " .. typeStr)
		context:setCanYield(true)
    end
end

function doMakeResult(context, response, stat)
    local typeStr = context:miner():typeStr()
	
	if not (stat == "success") then
        context:setStepName("end")
		context:miner():setStat(stat)
		context:setCanYield(true)
		return
    end
	
    if (typeStr == "test") then
		minerTest.doMakeResult(context, response, stat)
	else
		context:setStepName("end")
		context:miner():setStat("Don't support: " .. typeStr)
		context:setCanYield(true)
    end
end
