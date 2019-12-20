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
            
            local bmconf, pos, err = utils.jsonDecode (response.body)
            
            if not (err) then
                miner:setTypeStr('antminer-http-cgi')
                miner:setStat('success')

                pool1:setUrl(bmconf.pools[1].url)
                pool1:setWorker(bmconf.pools[1].user)
                pool1:setPasswd(bmconf.pools[1].pass)
                
                pool2:setUrl(bmconf.pools[2].url)
                pool2:setWorker(bmconf.pools[2].user)
                pool2:setPasswd(bmconf.pools[2].pass)
                
                pool3:setUrl(bmconf.pools[3].url)
                pool3:setWorker(bmconf.pools[3].user)
                pool3:setPasswd(bmconf.pools[3].pass)

                if (bmconf['bitmain-nobeeper'] ~= nil) then
                    miner:setOpt('_ant_nobeeper', tostring(bmconf['bitmain-nobeeper']))
                end
                
                if (bmconf['bitmain-notempoverctrl'] ~= nil) then
                    miner:setOpt('_ant_notempoverctrl', tostring(bmconf['bitmain-notempoverctrl']))
                end
                
                if (bmconf['bitmain-fan-ctrl'] ~= nil) then
                    miner:setOpt('_ant_fan_customize_switch', tostring(bmconf['bitmain-fan-ctrl']))
                end

                if (bmconf['bitmain-fan-pwm'] ~= nil) then
                    miner:setOpt('_ant_fan_customize_value', tostring(bmconf['bitmain-fan-pwm']))
                end
                
                if (bmconf['bitmain-freq'] ~= nil) then
                    miner:setOpt('_ant_freq', tostring(bmconf['bitmain-freq']))
                end
                
                if (bmconf['bitmain-voltage'] ~= nil) then
                    miner:setOpt('_ant_voltage', tostring(bmconf['bitmain-voltage']))
                end

                if (bmconf['bitmain-close-asic-boost'] ~= nil) then
                    miner:setOpt('_ant_disable_asic_boost', tostring(bmconf['bitmain-close-asic-boost']))
                end
                
                if (bmconf['bitmain-close-low-vol-freq'] ~= nil) then
                    miner:setOpt('_ant_disable_low_vol_freq', tostring(bmconf['bitmain-close-low-vol-freq']))
                end
                
                if (bmconf['bitmain-economic-mode'] ~= nil) then
                    miner:setOpt('_ant_economic_mode', tostring(bmconf['bitmain-economic-mode']))
                end

                if (bmconf['bitmain-low-vol'] ~= nil) then
                    miner:setOpt('_ant_multi_level', tostring(bmconf['bitmain-low-vol']))
                end

                if (bmconf['bitmain-work-mode'] ~= nil) then
                    miner:setOpt('_ant_work_mode', tostring(bmconf['bitmain-work-mode']))
                end

                if (bmconf['bitmain-ex-hashrate'] ~= nil) then
                    miner:setOpt('_ant_multi_level', tostring(bmconf['bitmain-ex-hashrate']))
                end
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
            -- S17 has this:
            -- "ghsav":"0.00,GHS 30m=0.00"
            local body = string.gsub(response.body, ',GHS 30m=', '","ghs30m":"')
            local stats, pos, err = utils.jsonDecode(body)
            
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
            local overclockOption = {
                ModeInfo = {
                    {
                        ModeName = "Normal",
                        ModeValue = "",
                        Level = {
                            Normal = "",
                        }
                    }
                }
            }

            if (string.match(miner:fullTypeStr(), 'Antminer L3')) then
                overclockOption = {
                    ModeInfo = {
                        {
                            ModeName = "Normal",
                            ModeValue = "",
                            Level = {
                                ["100M"] = "100",
                                ["106M"] = "106",
                                ["112M"] = "112",
                                ["118M"] = "118",
                                ["125M"] = "125",
                                ["131M"] = "131",
                                ["137M"] = "137",
                                ["142M"] = "142",
                                ["148M"] = "148",
                                ["154M"] = "154",
                                ["160M"] = "160",
                                ["166M"] = "166",
                                ["172M"] = "172",
                                ["178M"] = "178",
                                ["184M"] = "184",
                                ["190M"] = "190",
                                ["196M"] = "196",
                                ["200M"] = "200",
                                ["206M"] = "206",
                                ["212M"] = "212",
                                ["217M"] = "217",
                                ["223M"] = "223",
                                ["229M"] = "229",
                                ["235M"] = "235",
                                ["242M"] = "242",
                                ["248M"] = "248",
                                ["254M"] = "254",
                                ["260M"] = "260",
                                ["267M"] = "267",
                                ["273M"] = "273",
                                ["279M"] = "279",
                                ["285M"] = "285",
                                ["294M"] = "294",
                                ["300M"] = "300",
                                ["306M"] = "306",
                                ["312M"] = "312",
                                ["319M"] = "319",
                                ["325M"] = "325",
                                ["331M"] = "331",
                                ["338M"] = "338",
                                ["344M"] = "344",
                                ["350M"] = "350",
                                ["353M"] = "353",
                                ["356M"] = "356",
                                ["359M"] = "359",
                                ["362M"] = "362",
                                ["366M"] = "366",
                                ["369M"] = "369",
                                ["375M"] = "375",
                                ["378M"] = "378",
                                ["381M"] = "381",
                                ["384M"] = "384",
                                ["387M"] = "387",
                                ["391M"] = "391",
                                ["394M"] = "394",
                                ["397M"] = "397",
                                ["400M"] = "400",
                                ["406M"] = "406",
                                ["412M"] = "412",
                                ["419M"] = "419",
                                ["425M"] = "425",
                                ["431M"] = "431",
                                ["437M"] = "437",
                                ["438M"] = "438",
                                ["444M"] = "444",
                                ["450M"] = "450",
                                ["456M"] = "456",
                                ["462M"] = "462",
                                ["469M"] = "469",
                                ["475M"] = "475",
                                ["481M"] = "481",
                                ["487M"] = "487",
                                ["494M"] = "494",
                                ["500M"] = "500",
                                ["506M"] = "506",
                                ["512M"] = "512",
                                ["519M"] = "519",
                                ["525M"] = "525",
                                ["531M"] = "531",
                                ["537M"] = "537",
                                ["544M"] = "544",
                                ["550M"] = "550",
                                ["556M"] = "556",
                                ["562M"] = "562",
                                ["569M"] = "569",
                                ["575M"] = "575",
                                ["581M"] = "581",
                                ["587M"] = "587",
                                ["588M"] = "588",
                                ["594M"] = "594",
                                ["600M"] = "600",
                                ["606M"] = "606",
                                ["612M"] = "612",
                                ["619M"] = "619",
                                ["625M"] = "625",
                                ["631M"] = "631",
                                ["637M"] = "637",
                                ["638M"] = "638",
                                ["644M"] = "644",
                                ["650M"] = "650",
                            }
                        }
                    }
                }
                miner:setOpt('antminer.overclock_to_freq', "true")
            elseif (string.match(miner:fullTypeStr(), 'Antminer L5')) then
                overclockOption = {
                    ModeInfo = {
                        {
                            ModeName = "Normal",
                            ModeValue = "",
                            Level = {
                                ["(450MHz) Normal Power"] = "450",
                                ["(400MHz) Low Power"] = "400",
                                ["(350MHz) Ultra Low Power"] = "350"
                            }
                        }
                    }
                }
                miner:setOpt('antminer.overclock_to_freq', "true")
            elseif (string.match(miner:fullTypeStr(), 'Antminer S17 Pro')) then
                overclockOption = {
                    ModeInfo = {
                        {
                            ModeName = "Low Power",
                            ModeValue = "0",
                            Level = {
                                Normal = "0"
                            }
                        },
                        {
                            ModeName = "Normal",
                            ModeValue = "1",
                            Level = {
                                Normal = "0"
                            }
                        },
                        {
                            ModeName = "High Performance",
                            ModeValue = "2",
                            Level = {
                                Normal = "0"
                            }
                        },
                        {
                            ModeName = "Sleep Mode",
                            ModeValue = "254",
                            Level = {
                                Normal = "0"
                            }
                        }
                    }
                }
            elseif (string.match(miner:fullTypeStr(), 'Antminer [ST]17e')) then
                overclockOption = {
                    ModeInfo = {
                        {
                            ModeName = "Normal",
                            ModeValue = "0",
                            Level = {
                                Normal = "0"
                            }
                        }
                    }
                }
            elseif (string.match(miner:fullTypeStr(), 'Antminer S17')) then
                overclockOption = {
                    ModeInfo = {
                        {
                            ModeName = "Low Power",
                            ModeValue = "1",
                            Level = {
                                Normal ="0"
                            }
                        },
                        {
                            ModeName = "Normal",
                            ModeValue = "2",
                            Level = {
                                Normal ="0"
                            }
                        }
                    }
                }
            end

            local obj, pos, err = utils.jsonDecode (response.body)
            if not (err) and type(obj) == 'table' then
                if type(obj.ModeInfo) == 'table' then
                    overclockOption = obj
                else
                    for _, mode in pairs(overclockOption.ModeInfo) do
                        mode.Level = obj
                    end
                end
            end

            miner:setOpt('antminer.overclock_option', utils.jsonEncode(overclockOption))

            -- get the name of current working mode
            local workingModes = {}
            local levelNames = {}
            for _, mode in ipairs(overclockOption.ModeInfo) do
                workingModes[mode.ModeValue] = mode.ModeName
                for k, v in pairs(mode.Level) do
                    levelNames[v] = k
                end
            end

            local workingMode = workingModes[miner:opt("_ant_work_mode")] or ""

            local levelKey = (miner:opt("antminer.overclock_to_freq") == "true") and "_ant_freq" or "_ant_multi_level"
            local levelName = levelNames[miner:opt(levelKey)] or ""
            if levelName ~= workingMode then
                workingMode = utils.append(workingMode, levelName)
            end
            
            if (miner:opt("_ant_disable_asic_boost") == "false") then
                workingMode = utils.append(workingMode, 'LPM')
            end
            if (miner:opt("_ant_disable_asic_boost") == "false") then
                workingMode = utils.append(workingMode, 'Enhanced LPM')
            end

            miner:setOpt('antminer.overclock_working_mode', workingMode)

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
