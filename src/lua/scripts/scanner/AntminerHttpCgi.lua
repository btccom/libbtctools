AntminerHttpCgi = oo.class({}, ExecutorBase)


function AntminerHttpCgi:__init(parent, context)
    if context:miner():opt('minerTypeFound') ~= 'true' then
        context:miner():setFullTypeStr('Antminer') -- used for utils.getMinerLoginPassword()
        context:miner():setTypeStr('AntminerHttpCgi')
    end

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep('begin', 'find antminer')
    return obj
end

function AntminerHttpCgi:begin()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/cgi-bin/get_miner_conf.cgi',
    }

    context:setRequestHost(ip)
    context:setRequestPort("80")
    context:setRequestContent(http.makeRequest(request))
    self:setStep('auth', 'login...')

    -- Use longer timeouts to avoid incomplete content downloads
    if (miner:opt('httpPortAvailable') == 'true') then
        local timeout = context:requestSessionTimeout() * 5
        if (timeout < 10) then
            timeout = 10
        end
        context:setRequestSessionTimeout(timeout)
    end
end

function AntminerHttpCgi:auth(httpResponse, stat)
    local context = self.context

    local response = self:parseHttpResponse(httpResponse, stat, false)
    if (not response) then return end
    if (response.statCode ~= "401") then
        utils.debugInfo('AntminerHttpCgi:auth', 'statCode ~= 401')
        self:setStep('end', 'read config failed')
        return
    end

    self:setStep("getMinerConf")
end

function AntminerHttpCgi:getMinerConf()
    self:makeAuthRequest()
    self:setStep("parseMinerConf", 'read config...')
end

function AntminerHttpCgi:parseMinerConf(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then return end

    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    local bmconf, pos, err = utils.jsonDecode (response.body)

    if not (err) then
        miner:setTypeStr('AntminerHttpCgi')

        local pools = bmconf.pools
        if not pools then
            if bmconf.channels and bmconf.channels[1] and bmconf.channels[1].pools then
                pools = bmconf.channels[1].pools
            end
        end

        if pools then
            if pools[1] then
                pool1:setUrl(pools[1].url)
                pool1:setWorker(pools[1].user)
                pool1:setPasswd(pools[1].pass)
            end

            if pools[2] then
                pool2:setUrl(pools[2].url)
                pool2:setWorker(pools[2].user)
                pool2:setPasswd(pools[2].pass)
            end

            if pools[3] then
                pool3:setUrl(pools[3].url)
                pool3:setWorker(pools[3].user)
                pool3:setPasswd(pools[3].pass)
            end
        else
            utils.debugInfo('AntminerHttpCgi:parseMinerConf', 'empty pools')
        end

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

        if (bmconf['bitmain-work-mode'] ~= nil and miner:opt("_ant_work_mode") == '') then
            miner:setOpt('_ant_work_mode', tostring(bmconf['bitmain-work-mode']))
        end

        if (bmconf['bitmain-ex-hashrate'] ~= nil) then
            miner:setOpt('_ant_multi_level', tostring(bmconf['bitmain-ex-hashrate']))
        end
    end

    self:setStep('getMinerFullType', 'success')
end

function AntminerHttpCgi:getMinerFullType()
    self:makeAuthRequest('/cgi-bin/get_system_info.cgi')
    self:setStep("parseMinerFullType", 'read type...')
end

function AntminerHttpCgi:parseMinerFullType(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then return end

    local obj, pos, err = utils.jsonDecode (response.body)
    if err then
        utils.debugInfo('AntminerHttpCgi:parseMinerFullType', err)
        self:setStep("end", "read type failed: " .. err)
        return
    end

    self:setStep('end', 'success')

    if (type(obj) == 'table') then
        if (obj.minertype ~= nil) then
            miner:setFullTypeStr(obj.minertype)
            miner:setOpt('minerTypeFound', 'true')

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

        self:setStep('getOverclockOption', 'success')
    else
        utils.debugInfo('AntminerHttpCgi:parseMinerFullType', 'not an object')
    end
end

function AntminerHttpCgi:getOverclockOption()
    self:makeAuthRequest('/cgi-bin/get_multi_option.cgi')
    self:setStep("parseOverclockOption", 'read overclock option...')
end

function AntminerHttpCgi:parseOverclockOption(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then return end

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
    elseif (miner:fullTypeStr() == 'Antminer S17 Pro') then
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
    elseif (miner:fullTypeStr() == 'Antminer S17') then
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
        miner:setOpt('foundOverclockOption', "true")
    else
        utils.debugInfo('AntminerHttpCgi:parseOverclockOption', err or 'not an object')
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

    local workingMode = ''
    if workingModes[miner:opt("_ant_work_mode")] then
        workingMode = workingModes[miner:opt("_ant_work_mode")]
    elseif tonumber(miner:opt("_ant_work_mode")) == nil then
        -- _ant_work_mode is not a number, so it's a mode name
        workingMode = miner:opt("_ant_work_mode")
    end

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
    self:setStep('getMinerStat', 'success')
end

function AntminerHttpCgi:getMinerStat()
    if (self.context:miner():opt('skipGetMinerStat') == 'true') then
        self:getOverclockStat()
        return
    end

    self:makeAuthRequest('/cgi-bin/get_miner_status.cgi')
    self:setStep("parseMinerStat", 'read status...')
end

function AntminerHttpCgi:parseMinerStat(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then return end

    -- S17 has this:
    -- "ghsav":"0.00,GHS 30m=0.00"
    local body = string.gsub(response.body, ',GHS 30m=', '","ghs30m":"')
    local stats, pos, err = utils.jsonDecode(body)
    if err then
        utils.debugInfo('AntminerHttpCgi:parseMinerStat', err)
        self:setStep('end', 'read stat failed')
        return
    end

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
    else
        utils.debugInfo('AntminerHttpCgi:parseMinerStat', 'missing hashrate')
    end

	if (type(stats.devs) == 'table' and type(stats.devs[1]) == 'table') then
		local opts = stats.devs[1]
		local datas = utils.stringSplit(opts.freq, ',')

		for key,value in pairs(datas) do
			if (key == 1) then
				opts.freq = value
			else
				local kv = utils.stringSplit(value, '=')

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
    else
        utils.debugInfo('AntminerHttpCgi:parseMinerStat', 'missing devs')
    end

    self:setStep('getOverclockStat', 'success')
end

function AntminerHttpCgi:getOverclockStat()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
		method = 'GET',
		host = ip,
		path = '/result',
    }

    context:setRequestPort("6060")
    context:setRequestContent(http.makeRequest(request))
    context:setRequestSessionTimeout(context:requestSessionTimeout())

    self:setStep("parseOverclockStat", 'read overclock status...')
end

function AntminerHttpCgi:parseOverclockStat(httpResponse, stat)
    self:setStep('end', 'success')

    local context = self.context
    local miner = context:miner()

    local ok, response = pcall(http.parseResponse, httpResponse)
    if not ok then
        utils.debugInfo('AntminerHttpCgi:parseOverclockStat', response)
        return
    end

    local stats, pos, err = utils.jsonDecode(response.body)

    if not (err) and type(stats) == 'table' then
        local workingMode = miner:opt('antminer.overclock_working_mode')

        if stats.ex_tuning_stat then
            workingMode = utils.append(workingMode, 'OC √')
            if type(stats.ex_hash_rate) == 'number' then
                local rate = (stats.ex_hash_rate >= 0) and '+' or ''
                rate = rate .. tostring(stats.ex_hash_rate) .. ' GH/s'
                workingMode = utils.append(workingMode, rate)
            end
        elseif miner:opt('foundOverclockOption') == "true" then
            workingMode = utils.append(workingMode, 'OC tuning...')
        end

        miner:setOpt('antminer.overclock_working_mode', workingMode)
    else
        utils.debugInfo('AntminerHttpCgi:parseOverclockStat', err or 'not an object')
    end
end
