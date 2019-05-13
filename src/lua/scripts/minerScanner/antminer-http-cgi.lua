local scanner = {}

local utils = require ("utils")
local http = require ("http")
local date = require ("date")

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

        -- Use longer timeouts to avoid incomplete content downloads
        if (miner:opt('httpPortAvailable') == 'true') then
            local timeout = context:requestSessionTimeout() * 5
            if (timeout < 10) then
                timeout = 10
            end
            context:setRequestSessionTimeout(timeout)
        end
        
	elseif (step == "getMinerConf") then
		context:setStepName("parseMinerConf")
        miner:setStat('read config...')
        
    elseif (step == "getMinerStat") then
        context:setStepName("parseMinerStat")
        miner:setStat('read status...')
        
    elseif (step == "getMinerFullType") then
        context:setStepName("parseMinerFullType")
        miner:setStat('read type...')

    elseif (step == "getOverclockOption") then
        context:setStepName("parseOverclockOption")
        miner:setStat('read overclock option...')

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
            local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
            
            if (loginPassword == nil) then
                context:setStepName("end")
                context:miner():setStat("require password")
            else
			    local request = http.parseRequest(context:requestContent())
			    local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
                
			    if (err) then
			    	context:setStepName("end")
			    	miner():setStat('failed: ' .. err)
			    else
			    	context:setStepName("getMinerConf")
			    	context:setRequestContent(requestContent)
                end
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
                miner:setTypeStr('antminer-http-cgi')
                miner:setStat('success')

                pool1:setUrl(confs.pools[1].url)
                pool1:setWorker(confs.pools[1].user)
                pool1:setPasswd(confs.pools[1].pass)
                
                pool2:setUrl(confs.pools[2].url)
                pool2:setWorker(confs.pools[2].user)
                pool2:setPasswd(confs.pools[2].pass)
                
                pool3:setUrl(confs.pools[3].url)
                pool3:setWorker(confs.pools[3].user)
                pool3:setPasswd(confs.pools[3].pass)
            end

            -- make next request
            local request = http.parseRequest(context:requestContent())
            
            request.path = '/cgi-bin/get_system_info.cgi';
            
            local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
            local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
            
            if (err) then
                context:setStepName("end")
                miner:setStat('failed: ' .. err)
            else
                context:setStepName("getMinerFullType")
                context:setRequestContent(requestContent)
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
                
                if (type(stats.summary) == 'table') then
                    local summary = stats.summary
                    
                    if (summary.elapsed ~= nil) then
                        miner:setOpt('elapsed', utils.formatTime(summary.elapsed, 'd :h :m :s '))
                    end

                    local hashrateUnit = ' GH/s'
				
                    -- the hashrate unit of Antminer L3 and L3+ is MH/s
                    if (string.match(miner:fullTypeStr(), 'Antminer L%d')) then
                        hashrateUnit = ' MH/s'
                    end
					
                    if (summary.ghs5s ~= nil) then
                        miner:setOpt('hashrate_5s', summary.ghs5s .. hashrateUnit)
					elseif (summary.mhs5s ~= nil) then
						miner:setOpt('hashrate_5s', summary.mhs5s .. ' MH/s')
                    end
                    
                    if (summary.ghsav ~= nil) then
                        miner:setOpt('hashrate_avg', summary.ghsav .. hashrateUnit)
					elseif (summary.mhsav ~= nil) then
						miner:setOpt('hashrate_avg', summary.mhsav .. ' MH/s')
                    end
                end

				if (type(stats.devs) == 'table' and type(stats.devs[1]) == 'table') then
					local opts = stats.devs[1]
					local datas = utils.stringSplit(opts.freq, ',')
					
					for key,value in pairs(datas) do
						if (key == 1) then
							opts.freq = value
						else
							kv = utils.stringSplit(value, '=')
							
							if (#kv == 2) then
								opts[kv[1]] = kv[2]
							end
						end
					end
					
					if (opts['temp1'] ~= nil) then
						local temp = {}
						local i = 1
						
						while (opts['temp'..i] ~= nil) do
							local value = tonumber(opts['temp'..i])
							
							if (type(value) == 'number' and value > 0) then
								table.insert(temp, value)
							end
							
							i = i + 1
						end
						
						miner:setOpt('temperature', table.concat(temp, ' / '))
					end
					
					if (opts['fan1'] ~= nil) then
						local fan = {}
						local i = 1
						
						while (opts['fan'..i] ~= nil) do
							local value = tonumber(opts['fan'..i])
							
							if (type(value) == 'number' and value > 0) then
								table.insert(fan, value)
							end
							
							i = i + 1
						end
						
						miner:setOpt('fan_speed', table.concat(fan, ' / '))
					end

				end
                
                -- scanning finished
                if (err) then
                    context:setStepName("end")
                    miner:setStat('failed: ' .. err)
                else
                    context:setStepName("end")
                    miner:setStat('success')
                end
                
            else
                context:setStepName("end")
                miner:setStat("read stat failed")
            end
		end
        
    elseif (step == "parseMinerFullType") then
		if (response.statCode == "401") then
			context:setStepName("end")
			miner:setStat("login failed")
		else
            local obj, pos, err = utils.jsonDecode (response.body)
            
            if not (err) then
                context:setStepName("end")
                miner:setStat("success")
                
                if (type(obj) == 'table') then
                    
                    if (obj.minertype ~= nil) then
                        miner:setFullTypeStr(obj.minertype)
						
						-- the hashrate unit of Antminer L3 and L3+ is MH/s
						if (string.match(obj.minertype, 'Antminer L%d')) then
							miner:setOpt('hashrate_5s', string.gsub(miner:opt('hashrate_5s'), ' GH/s',' MH/s'))
							miner:setOpt('hashrate_avg', string.gsub(miner:opt('hashrate_avg'), ' GH/s',' MH/s'))
						end
                    end

                    if (obj.system_filesystem_version ~= nil) then
                        local ok, firmwareVer = pcall(date, obj.system_filesystem_version)
                        if (ok) then
                            miner:setOpt('firmware_version', firmwareVer:fmt("%Y%m%d"))
                        end
                    end

                    -------- begin of software_version --------
                    local software = nil

                    if (obj.system_logic_version ~= nil) then
                        software = obj.system_logic_version
                    end

                    if (obj.bmminer_version ~= nil) then
                        if (software == nil) then
                            software = 'bmminer ' .. obj.bmminer_version
                        else
                            software = software .. ', bmminer ' .. obj.bmminer_version
                        end
                    elseif (obj.cgminer_version ~= nil) then
                        if (software == nil) then
                            software = 'cgminer ' .. obj.cgminer_version
                        else
                            software = software .. ', cgminer ' .. obj.cgminer_version
                        end
                    end

                    if (software ~= nil) then
                        miner:setOpt('software_version', software)
                    end
                    -------- end of software_version --------

                    if (obj.ant_hwv ~= nil) then
                        miner:setOpt('hardware_version', obj.ant_hwv)
                    end

                    if (obj.nettype ~= nil) then
                        miner:setOpt('network_type', obj.nettype)
                    end

                    if (obj.macaddr ~= nil) then
                        miner:setOpt('mac_address', obj.macaddr)
                    end
                    
                    -- make next request
                    local request = http.parseRequest(context:requestContent())
                    
                    request.path = '/cgi-bin/get_multi_option.cgi';
                    
                    local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
                    local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
                    
                    if (err) then
                        context:setStepName("end")
                        miner:setStat('failed: ' .. err)
                    else
                        context:setStepName("getOverclockOption")
                        context:setRequestContent(requestContent)
                    end
                end
                
            else
                context:setStepName("end")
                miner:setStat("read type failed")
            end
		end
        
    elseif (step == "parseOverclockOption") then
		if (response.statCode == "401") then
			context:setStepName("end")
			miner:setStat("login failed")
        else

            local obj, pos, err = utils.jsonDecode (response.body)
            
            if not (err) then
                miner:setOpt('antminer.overclock_option', response.body)
            elseif (string.match(miner:fullTypeStr(), 'Antminer L5')) then
                miner:setOpt('antminer.overclock_option', [[{
                    "(450MHz) Normal Power":"450",
                    "(400MHz) Low Power":"400",
                    "(350MHz) Ultra Low Power":"350"
                }]])
                miner:setOpt('antminer.overclock_to_freq', "true")
            elseif (string.match(miner:fullTypeStr(), 'Antminer S17 Pro')) then
                miner:setOpt('antminer.overclock_option', [[{
                    "Low Power":"0",
                    "Normal":"1",
                    "High Performance":"2"
                }]])
                miner:setOpt('antminer.overclock_to_work_mode', "true")
            elseif (string.match(miner:fullTypeStr(), 'Antminer S17')) then
                miner:setOpt('antminer.overclock_option', [[{
                    "Low Power":"1",
                    "Normal":"2"
                }]])
                miner:setOpt('antminer.overclock_to_work_mode', "true")
            end

            -- make next request
            if (miner:opt('skipGetMinerStat') == 'true') then
                context:setStepName("end")
                miner:setStat("success")
            else
                local request = http.parseRequest(context:requestContent())
                    
                request.path = '/cgi-bin/get_miner_status.cgi';
                
                local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
                local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
                
                context:setStepName("getMinerStat")
                context:setRequestContent(requestContent)
            end
        end
    else
		context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

return scanner
