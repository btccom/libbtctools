local configurator = {}

local utils = require ("utils")
local http = require ("http")

function configurator.doMakeRequest(context)
    local step = context:stepName()
    local miner = context:miner()
    local ip = miner:ip()
    
    context:setCanYield(true)

    if (step == "begin") then
        loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
        
        if (loginPassword == nil) then
            context:setStepName("end")
            context:miner():setStat("require password")
        else
            local request = {
		    	method = 'POST',
		    	host = ip,
		    	path = '/cgi-bin/luci/avalon/page/index',
                body = 'username='..loginPassword.userName..'&password='..loginPassword.password,
                headers = {
                    ['Content-Type'] = 'application/x-www-form-urlencoded'
                }
		    }
        
		    context:setRequestHost(ip)
		    context:setRequestPort("80")
		    context:setRequestContent(http.makeRequest(request))
		    context:setStepName("login")
            miner:setStat('login...')
        end
    elseif (step == "updateConfig") then
        local cookie = miner:opt('cookie')
        local stok = miner:opt('stok')
        
        local pool1 = miner:pool1()
        local pool2 = miner:pool2()
        local pool3 = miner:pool3()
        
        local formParams = {
            ['cbi.submit'] = '1',
            ['cbid.cgminer.default.ntp_enable'] = miner:opt('luci.config.cgminer.ntp_enable') or 'disable',
            ['cbid.cgminer.default.pool1url'] = pool1:url(),
            ['cbid.cgminer.default.pool1user'] = pool1:worker(),
            ['cbid.cgminer.default.pool1pw'] = pool1:passwd(),
            ['cbid.cgminer.default.pool2url'] = pool2:url(),
            ['cbid.cgminer.default.pool2user'] = pool2:worker(),
            ['cbid.cgminer.default.pool2pw'] = pool2:passwd(),
            ['cbid.cgminer.default.pool3url'] = pool3:url(),
            ['cbid.cgminer.default.pool3user'] = pool3:worker(),
            ['cbid.cgminer.default.pool3pw'] = pool3:passwd(),
            ['cbi.apply'] = 'Save & Apply'
        }
        
        local body = utils.makeUrlQueryString(formParams)
        
        local request = {
			method = 'POST',
			host = ip,
			path = '/cgi-bin/luci/;stok=' .. stok .. '/avalon/page/configure',
            body = body,
            headers = {
                ['Cookie'] = cookie,
                ['Content-Type'] = 'application/x-www-form-urlencoded'
            }
		}
        
        context:setRequestContent(http.makeRequest(request))
		context:setStepName("readUpdateResult")
        miner:setStat('update config...')
    
    elseif (step == "restartService") then
        local cookie = miner:opt('cookie')
        local stok = miner:opt('stok')
        
        local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/luci/;stok=' .. stok .. '/servicectl/restart/cgminer',
            headers = {
                ['Cookie'] = cookie
            }
		}
        
        context:setRequestDelayTimeout(5)
        context:setRequestContent(http.makeRequest(request))
		context:setStepName("restartCgminer")
        miner:setStat('restart cgminer...')
        
    elseif (step == "waitRestartFinish") then
        local cookie = miner:opt('cookie')
        local stok = miner:opt('stok')
        
        local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/luci/;stok=' .. stok .. '/servicectl/status',
            headers = {
                ['Cookie'] = cookie
            }
		}
        
        context:setRequestDelayTimeout(1)
        context:setRequestContent(http.makeRequest(request))
		context:setStepName("checkRestartFinish")
        miner:setStat('wait finish...')
        
    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
		context:setCanYield(true)
    end
end

function configurator.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
    
    context:setCanYield(true)
    miner:setStat(stat)
    
	response = http.parseResponse(response)
    
    if (step == "login") then
        if (response.statCode == "302") then
            local cookie = response.headers['set-cookie']
            local url = response.headers['location']
            
            if (type(cookie) == 'table' and cookie[1] ~= nil
                and type(url) == 'table' and url[1] ~= nil) then
                
                cookie = string.gsub(cookie[1], ';.*', '')
                miner:setOpt('cookie', cookie)
                
                local stok = string.match(url[1], '/;stok=([^/]*)/')
                miner:setOpt('stok', stok)
                
                context:setStepName("updateConfig")
            else
                context:setStepName("end")
                miner:setStat("login failed")
            end
            
        else
            context:setStepName("end")
			miner:setStat("login failed")
        end
    
    elseif (step == "readUpdateResult") then
        if (string.match(response.body, 'servicectl/restart/cgminer')) then
            miner:setStat("ok")
            context:setStepName("restartService")
        else
            miner:setStat("update config failed")
            context:setStepName("end")
        end
        
    elseif (step == "restartCgminer") then
        local result = utils.trimAll(response.body)
        
        if (result == "OK") then
            miner:setStat("ok")
            miner:setOpt('check-restart-finish-times', '0')
            context:setStepName("waitRestartFinish")
        else
            miner:setStat(result)
            context:setStepName("end")
        end
        
    elseif (step == "checkRestartFinish") then
        local result = utils.trimAll(response.body)
        
        if (result == "finish") then
            miner:setStat("ok")
            context:setStepName("end")
        else
            local times = tonumber(miner:opt('check-restart-finish-times'))
            
            if (times > 20) then
                miner:setStat("ok") -- the restarting will be done in a few seconds
                context:setStepName("end")
            else
                miner:setOpt('check-restart-finish-times', tostring(times + 1))
                miner:setStat("not finish")
                context:setStepName("waitRestartFinish")
            end
        end
        
    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

return configurator
