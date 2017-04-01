local scanner = {}

local utils = require ("lua.scripts.utils")
local http = require ("lua.scripts.http")

function scanner.doMakeRequest(context)
    local step = context:stepName()
    local miner = context:miner()
    local ip = miner:ip()
	local typeStr = miner:typeStr()
    
    context:setCanYield(true)
    
    if (step == "begin") then
        local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/get_miner_conf.cgi',
		}
		
		context:setRequestHost(ip)
		context:setRequestPort("80")
		context:setRequestContent(http.makeRequest(request))
		context:setStepName("auth")
        miner:setStat('login...')
        
	elseif (step == "getMinerConf") then
		context:setStepName("parseMinerConf")
        miner:setStat('read config...')
        
    elseif (step == "getMinerStat") then
        context:setStepName("parseMinerStat")
        miner:setStat('read status...')
        
	else
		context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

function scanner.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
    
    context:setCanYield(true)
    miner:setStat(stat)
    
	response = http.parseResponse(response)
    
    if (step == "auth") then
		if (response.statCode == "401") then
			local request = http.parseRequest(context:requestContent())
			local requestContent, err = http.makeAuthRequest(request, response, 'root', 'root')
			
			if (err) then
				context:setStepName("end")
				miner():setStat('failed: ' .. err)
			else
				context:setStepName("getMinerConf")
				context:setRequestContent(requestContent)
			end
		else
			context:setStepName("end")
			miner():setStat("read config failed")
		end
        
	elseif (step == "parseMinerConf") then
		if (response.statCode == "401") then
			context:setStepName("end")
			miner:setStat("login failed")
		else
            local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()
            
            local confs, pos, err = utils.jsonDecode (response.body)
            
            if not (err) then
                miner:setTypeStr('antminer-cgi-sh')
                miner:setFullTypeStr('Antminer')
                miner:setStat('success')
                miner:setOpt('getPoolsSuccess', 'true')
                
                pool1:setUrl(confs.pools[1].url)
                pool1:setWorker(confs.pools[1].user)
                pool1:setPasswd(confs.pools[1].pass)
                
                pool2:setUrl(confs.pools[2].url)
                pool2:setWorker(confs.pools[2].user)
                pool2:setPasswd(confs.pools[2].pass)
                
                pool3:setUrl(confs.pools[3].url)
                pool3:setWorker(confs.pools[3].user)
                pool3:setPasswd(confs.pools[3].pass)
                
                
                -- make next request
                local request = http.parseRequest(context:requestContent())
                
                request.path = '/cgi-bin/get_miner_status.cgi';
                
                local requestContent, err = http.makeAuthRequest(request, response, 'root', 'root')
                
                if (err) then
                    context:setStepName("end")
                    miner:setStat('failed: ' .. err)
                -- It has got the status from cgminer api, skipping the next step
                elseif (miner:opt('getStatSuccess') == "true") then
                    context:setStepName("end")
                    miner:setStat('success')
                else
                    context:setStepName("getMinerStat")
                    context:setRequestContent(requestContent)
                end
                
            else
                context:setStepName("end")
                miner:setStat("read config failed")
            end
		end
        
    elseif (step == "parseMinerStat") then
		if (response.statCode == "401") then
			context:setStepName("end")
			miner:setStat("login failed")
		else
            local stats, pos, err = utils.jsonDecode (response.body)
            
            if not (err) then
                context:setStepName("end")
                miner:setStat("success")
                miner:setOpt('getStatSuccess', 'true')
                
                if (type(stats.summary) == 'table') then
                    local summary = stats.summary
                    
                    if (summary.elapsed ~= nil) then
                        miner:setOpt('elapsed', utils.formatTime(summary.elapsed, 'd :h :m :s '))
                    end
                    
                    if (summary.ghs5s ~= nil) then
                        miner:setOpt('hashrate_5s', summary.ghs5s .. ' GH/s')
                    end
                    
                    if (summary.ghsav ~= nil) then
                        miner:setOpt('hashrate_avg', summary.ghsav .. ' GH/s')
                    end
                end
                
                -- find miner's full type from cgminer api
                miner:setOpt('scannerName', 'antminer-cgminer')
                context:setStepName("begin")
            else
                context:setStepName("end")
                miner:setStat("read stat failed")
            end
		end
        
	else
		context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

return scanner
