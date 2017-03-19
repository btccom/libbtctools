local miner = {}

function miner.doMakeRequest(context)
    local step = context:stepName()
    local ip = context:miner():ip()
	local typeStr = context:miner():typeStr()
    
    if (step == "begin") then
        local request = {
			method = 'GET',
			host = 'localhost',
			path = '/0.php',
		}
		
		context:setRequestHost(ip)
		context:setRequestPort("80")
		context:setRequestContent(http.makeRequest(request))
		context:setStepName("doTest")
	elseif (step == "testAuth") then
		context:setStepName("doTestAuth")
	else
		context:setStepName("end")
		context:miner():setStat("inner error: unknown step name")
		context:setCanYield(true)
    end
end

function miner.doMakeResult(context, response, stat)
    local step = context:stepName()
	response = http.parseResponse(response)
    
    if (step == "doTest") then
		if (response.statCode == "401") then
			local request = http.parseRequest(context:requestContent())
			local requestContent, err = http.makeAuthRequest(request, response, 'root', 'root')
			
			if (err) then
				context:setStepName("end")
				context:miner():setStat(err)
				context:setCanYield(true)
			else
				context:setStepName("testAuth")
				context:setRequestContent(requestContent)
				context:setCanYield(false)
			end
		else
			context:setStepName("end")
			context:miner():setStat("ok")
			context:setCanYield(true)
		end
	elseif (step == "doTestAuth") then
		if (response.statCode == "401") then
			context:setStepName("end")
			context:miner():setStat("auth failed: " .. response.body)
			context:setCanYield(true)
		else
			context:setStepName("end")
			context:miner():setStat("auth ok: " .. response.body)
			context:setCanYield(true)
		end
	else
		context:setStepName("end")
		context:miner():setStat("inner error: unknown step name")
		context:setCanYield(true)
    end
end

return miner
