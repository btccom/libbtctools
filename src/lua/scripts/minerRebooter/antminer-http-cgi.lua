local configurator = {}

local utils = require ("utils")
local http = require ("http")

function configurator.doMakeRequest(context)
    local step = context:stepName()
    local miner = context:miner()
    local ip = miner:ip()
	local typeStr = miner:typeStr()
    
    context:setCanYield(true)
    
    if (step == "begin") then
        local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/reboot.cgi',
		}
		
		context:setRequestHost(ip)
		context:setRequestPort("80")
		context:setRequestContent(http.makeRequest(request))
		context:setStepName("auth")
        miner:setStat('login...')
	elseif (step == "reboot") then
		context:setStepName("doReboot")
        miner:setStat('rebooting...')
    elseif (step == "waitFinish") then
		context:setStepName("doWaitFinish")
        miner:setStat('wait finish...')
	else
		context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

function configurator.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
    
    context:setCanYield(true)
    miner:setStat(stat)
    
    if (step ~= "doWaitFinish") then
        response = http.parseResponse(response)
    end
    
    if (step == "auth") then
		if (response.statCode == "401") then
			loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
            
            if (loginPassword == nil) then
                context:setStepName("end")
                context:miner():setStat("require password")
            else
				local request = http.parseRequest(context:requestContent())
				local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
				
				if (err) then
					context:setStepName("end")
					miner:setStat('failed: ' .. err)
				else
					context:setStepName("reboot")
					context:setRequestContent(requestContent)
				end
			end
		else
			context:setStepName("end")
			miner:setStat("read config failed")
		end
	elseif (step == "doReboot") then
		if (response.statCode == "401") then
			context:setStepName("end")
			miner:setStat("login failed")
		else
        
            local request = {
                method = 'GET',
                host = ip,
                path = '/cgi-bin/reboot.cgi',
            }
            
			if (err) then
				context:setStepName("end")
				miner:setStat('failed: ' .. err)
			else
				context:setStepName("waitFinish")
				context:setRequestContent(http.makeRequest(request))
                context:setRequestDelayTimeout(5)
                context:setRequestSessionTimeout(5)
                miner:setOpt('check-reboot-finish-times', '0')
			end
		end
        
    elseif (step == "doWaitFinish") then
    
        if (stat == "success") then
            context:setStepName("end")
			miner:setStat("rebooted")
        else
            local times = tonumber(miner:opt('check-reboot-finish-times'))
            
            if (times > 30) then
                miner:setStat("wait finish timeout")
                context:setStepName("end")
            else
                miner:setOpt('check-reboot-finish-times', tostring(times + 1))
                miner:setStat("not finish")
                context:setStepName("waitFinish")
            end
        end
	else
		context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

return configurator
