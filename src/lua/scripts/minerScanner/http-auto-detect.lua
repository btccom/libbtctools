local scanner = {}

local utils = require ("utils")
local http = require ("http")


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
    
    if (stat ~= "success") then
        context:setStepName("end")
        return
    end
    
    response = http.parseResponse(response)
    miner:setOpt('httpPortAvailable', 'true')
    
    if (step == 'detect') then
        
        if (response.statCode == "401" and
            response.headers['www-authenticate'] and
            response.headers['www-authenticate'][1] and
            string.match(response.headers['www-authenticate'][1], '^Digest%s')) then
            
            miner:setOpt('httpDetect', 'antminer-http-cgi')
            miner:setOpt('scannerName', 'antminer-cgminer-api')
            context:setStepName("begin")
            miner:setStat('find antminer')
            miner:setFullTypeStr('Antminer *') -- used for utils.getMinerLoginPassword()
            miner:setTypeStr('antminer-http-cgi')
            context:setCanYield(true)
            
        elseif (response.statCode == "200" and
            string.match(response.body, '/luci/avalon/')) then
            
            miner:setOpt('httpDetect', 'avalon-http-luci')
            miner:setOpt('scannerName', 'avalon-http-luci')
            context:setStepName("begin")
            miner:setStat('find avalon')
            miner:setFullTypeStr('Avalon *') -- used for utils.getMinerLoginPassword()
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
