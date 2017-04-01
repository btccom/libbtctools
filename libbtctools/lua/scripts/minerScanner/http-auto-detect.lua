local scanner = {}

local utils = require ("lua.scripts.utils")
local http = require ("lua.scripts.http")


function scanner.doMakeRequest(context)
    local step = context:stepName()
    local miner = context:miner()
    local ip = miner:ip()
    
    context:setCanYield(true)

    if (step == "begin") then
        local request = {
			method = 'GET',
			host = ip,
			path = '/'
		}
		
		context:setRequestHost(ip)
		context:setRequestPort("80")
		context:setRequestContent(http.makeRequest(request))
		context:setStepName("detect")
        miner:setStat('http detect...')

    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
		context:setCanYield(true)
    end
end

function scanner.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
    
    context:setCanYield(true)
    miner:setStat(stat)
    
	response = http.parseResponse(response)
    
    if (step == 'detect') then
        
        if (response.statCode == "401" and
            response.headers['www-authenticate'] and
            response.headers['www-authenticate'][1] and
            string.match(response.headers['www-authenticate'][1], '^Digest%s')) then
            
            miner:setOpt('httpDetect', 'antminer-cgi-sh')
            miner:setOpt('scannerName', 'antminer-cgi-sh')
            context:setStepName("begin")
            miner:setStat('find antminer')
            context:setCanYield(true)
            
        elseif (response.statCode == "200" and
            string.match(response.body, '/luci/avalon/')) then
            
            miner:setOpt('httpDetect', 'avalon-luci')
            miner:setOpt('scannerName', 'avalon-luci')
            context:setStepName("begin")
            miner:setStat('find avalon')
            context:setCanYield(true)
            
        else
            miner:setOpt('httpDetect', 'unknown')
            miner:setStat('unknown')
            miner:setTypeStr('unknown')
            context:setStepName("end")
        end
        
    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

return scanner
