GenericCgminerApi = oo.class({}, ExecutorBase)


function GenericCgminerApi:__init(parent, context)
    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep('begin')
    return obj
end

function GenericCgminerApi:regularTypeStr(fullTypeStr)
    local typeStr = 'unknown'
    local typeLowerStr = string.lower(fullTypeStr)

    if (string.match(typeLowerStr, 'antminer')) then
        typeStr = 'AntminerHttpCgi'
    end

    if (string.match(typeLowerStr, 'whatsminer')) then
        typeStr = 'WhatsMinerHttpsLuci'
        fullTypeStr = string.gsub(fullTypeStr, 'whatsminer', 'WhatsMiner', 1)
    end

    return typeStr, fullTypeStr
end

function GenericCgminerApi:begin()
    local context = self.context
    local miner = context:miner()

    context:setRequestHost(miner:ip())
    context:setRequestPort('4028')
    context:setRequestContent('{"command":"stats"}')

    self:setStep('parseStats', 'find type...')
end

function GenericCgminerApi:parseStats(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat ~= "success") then
        local minerType = miner:opt('httpDetect')
        if (_G[minerType]) then
            self.parent:setExecutor(self.context, _G[minerType](self.parent, self.context))
        else
            self:setStep('end', stat or 'unknown')
        end

        return
    end

    self:doParseStats(response, miner)
    self:setStep('findPools', 'success')
end

function GenericCgminerApi:doParseStats(jsonStr, miner)
    local typeStr = 'unknown'
    local fullTypeStr = 'Unknown'

    local obj, pos, err = utils.jsonDecode(jsonStr)

    if not err and type(obj) == "table" then
        local status = obj.status
        local stat = obj.STATS

        if (type(stat) == "table" and type(stat[1]) == "table" and type(stat[1].Type) == "string" and stat[1].Type ~= "") then
            fullTypeStr = stat[1].Type
            miner:setOpt('minerTypeFound', 'true')
        elseif type(obj.Description) == "string" and string.match(obj.Description, "whatsminer") then
            -- The JSON looks like: {"STATUS":"E","When":1618547449,"Code":14,"Msg":"invalid cmd","Description":"whatsminer v1.1"}
            fullTypeStr = obj.Description
            miner:setOpt('minerTypeFound', 'true')
        end

        typeStr, fullTypeStr = self:regularTypeStr(fullTypeStr)

        -- find versions
        if (type(stat) == "table" and type(stat[1]) == "table") then
            local versions = stat[1]

            if (versions.Miner ~= nil) then
                miner:setOpt('hardware_version', versions.Miner)
            end

            if (versions.BMMiner ~= nil) then
                miner:setOpt('software_version', 'bmminer ' .. versions.BMMiner)
            elseif (versions.CGMiner ~= nil) then
                miner:setOpt('software_version', 'cgminer ' .. versions.CGMiner)
            end

            if (versions.CompileTime ~= nil) then
                local ok, firmwareVer = pcall(date, versions.CompileTime)
                if (ok) then
                    miner:setOpt('firmware_version', firmwareVer:fmt("%Y%m%d"))
                end
            end

        end

        -- for Avalon 10
        if (type(stat) == "table" and type(stat[1]) == "table") then
            local opts = stat[1]
            if (opts['MM ID0'] ~= nil) then
                miner:setOpt('avalon_found_mm_id0', 'true')
                local data = opts['MM ID0']
                do
                    local iter = string.gmatch(data, '%f[%a]Fan[0-9]+%[([^%]]+)%]')
                    local fan = {}
                    while true do
                        local speed = iter()
                        if speed == nil then
                            break
                        end
                        table.insert(fan, speed)
                    end
                    if #fan > 0 then
                        miner:setOpt('fan_speed', table.concat(fan, ' / '))
                    end
                end

                do
                    local temp = string.match(data, '%f[%a]MTavg%[([^%]]+)%]')
                    if temp ~= nil and temp ~= "" then
                        miner:setOpt('temperature', string.gsub(temp, ' ', ' / '))
                    end
                end

                do
                    local version = string.match(data, '%f[%a]Ver%[([^%]]+)%]')
                    if version ~= nil and version ~= "" then
                        miner:setOpt('firmware_version', version)
                    end
                end

                do
                    local version = string.match(data, '%f[%a]DNA%[([^%]]+)%]')
                    if version ~= nil and version ~= "" then
                        miner:setOpt('hardware_version', version)
                    end
                end

                do
                    local mode = string.match(data, '%f[%a]WORKMODE%[([^%]]+)%]')
                    if mode ~= nil and mode ~= "" then
                        miner:setOpt('avalon.overclock_working_mode', mode)
                        miner:setOpt('antminer.overclock_working_mode', 'Mode ' .. mode)
                    end
                end
            end
        end

        -- find more infos
        if (type(stat) == "table" and type(stat[2]) == "table") then
            local opts = stat[2]

			local hashrateUnit = ' GH/s'

			if (string.match(fullTypeStr, 'Antminer L%d')) then
                -- the hashrate unit of Antminer L3 and L3+ is MH/s
                hashrateUnit = ' MH/s'
            elseif (string.match(fullTypeStr, 'Antminer Z%d')) then
                -- the hashrate unit of Antminer Z9 and Z11 is ksol/s
                hashrateUnit = ' ksol/s'
			end

            if (opts['RT'] ~= nil) then
                miner:setOpt('hashrate_5s', opts['RT']..hashrateUnit)
            elseif (opts['GHS 5s'] ~= nil) then
                miner:setOpt('hashrate_5s', opts['GHS 5s']..hashrateUnit)
			elseif (opts['MHS 5s'] ~= nil) then
				miner:setOpt('hashrate_5s', opts['MHS 5s']..' MH/s')
            end

            if (opts['AVG'] ~= nil) then
                miner:setOpt('hashrate_avg', opts['AVG']..hashrateUnit)
            elseif (opts['GHS av'] ~= nil) then
                miner:setOpt('hashrate_avg', opts['GHS av']..hashrateUnit)
			elseif (opts['MHS av'] ~= nil) then
				miner:setOpt('hashrate_avg', opts['MHS av']..' MH/s')
            end

            if (opts['temp1'] ~= nil) then
                local temp = {}
                local i = 1

                while (opts['temp'..i] ~= nil) do
                    if (opts['temp'..i] > 0) then
                        table.insert(temp, opts['temp'..i])
                    end

                    i = i + 1
                end
                if #temp > 0 then
                    miner:setOpt('temperature', table.concat(temp, ' / '))
                end
            end

            if (opts['fan1'] ~= nil) then
                local fan = {}
                local i = 1
                while (opts['fan'..i] ~= nil) do
                    if (opts['fan'..i] > 0) then
                        table.insert(fan, opts['fan'..i])
                    end
                    i = i + 1
                end
                if #fan > 0 then
                    miner:setOpt('fan_speed', table.concat(fan, ' / '))
                end
            end

            if (opts['Elapsed'] ~= nil) then
                miner:setOpt('elapsed', utils.formatTime(opts['Elapsed'], 'd :h :m :s '))
            end

            if (opts['Mode'] ~= nil) then
                miner:setOpt('_ant_work_mode', tostring(opts['Mode']))
                if tonumber(miner:opt("_ant_work_mode")) == nil then
                    -- _ant_work_mode is not a number, so it's a mode name
                    miner:setOpt('antminer.overclock_working_mode', miner:opt("_ant_work_mode"))
                end
            end

            if (opts['Ex Hash Rate'] ~= nil) then
                miner:setOpt('_ant_multi_level', tostring(opts['Ex Hash Rate']))
            end

            if miner:opt('hashrate_avg') ~= '' then
                miner:setOpt('skipGetMinerStat', 'true')
            end
        end
    end

    miner:setTypeStr(typeStr)
    miner:setFullTypeStr(fullTypeStr)

    return true
end

function GenericCgminerApi:findPools()
    self.context:setRequestContent('{"command":"pools"}')
    self:setStep('parsePools', 'find pools...')
end

function GenericCgminerApi:parsePools(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat == "success") then
        self:doParsePools(response, miner)
        self:setStep('end', 'success')
    else
        self:setStep('end', stat or 'unknown')
    end

    -- try to find hashrate
    if miner:opt("hashrate_5s") == "" and miner:opt("hashrate_avg") == "" then
        self:setStep('getMinerType')
        return
    end

    -- find more infos from http
    local minerType = miner:opt('httpDetect')
    if (_G[minerType]) then
        self.parent:setExecutor(self.context, _G[minerType](self.parent, self.context))
    end
end

function GenericCgminerApi:doParsePools(jsonStr, miner)
    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()

    local findSuccess = false

    local obj, pos, err = utils.jsonDecode(jsonStr)

    if not err and type(obj) == "table" then
        local pools = obj.POOLS

        if (type(pools) == "table") then
            if (type(pools[1]) == "table") then
                pool1:setUrl(pools[1].URL)
                pool1:setWorker(pools[1].User)
            end

            if (type(pools[2]) == "table") then
                pool2:setUrl(pools[2].URL)
                pool2:setWorker(pools[2].User)
            end

            if (type(pools[3]) == "table") then
                pool3:setUrl(pools[3].URL)
                pool3:setWorker(pools[3].User)
            end

            findSuccess = true
        end
    end

    return findSuccess
end

function GenericCgminerApi:getMinerType()
    self.context:setRequestContent('{"command":"devdetails"}')
    self:setStep('parseMinerType', 'find type...')
end

function GenericCgminerApi:parseMinerType(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat == "success") then
        self:doParseMinerType(response, miner)
    end

    self:setStep('getSummary', stat or 'unknown')
end

function GenericCgminerApi:doParseMinerType(jsonStr, miner)
    local obj, pos, err = utils.jsonDecode(jsonStr)

    if not err and type(obj) == "table" then
        local dev = obj.DEVDETAILS

        if type(dev) == "table" and type(dev[1]) == "table" then
            dev = dev[1]

            if (dev['Model'] ~= nil and dev['Model'] ~= "") then
                local model = dev['Model']
                if miner:opt('httpDetect') == "WhatsMinerHttpsLuci" then
                    miner:setFullTypeStr("WhatsMiner "..model)
                    miner:setOpt('minerTypeFound', 'true')
                else
                    local sep = (miner:fullTypeStr() == '' and '' or ' ')
                    miner:setFullTypeStr(miner:fullTypeStr()..sep..model)
                    miner:setOpt('minerTypeFound', 'true')
                end
            end

            if dev['Name'] ~= nil and dev['Name'] ~= "" and miner:opt('minerTypeFound') ~= 'true' then
                local model = dev['Name']
                if dev['Driver'] ~= nil and dev['Driver'] ~= "" then
                    model = model .. ' (' .. dev['Driver'] .. ')'
                end

                if string.match(model, 'avalon') and miner:opt('httpDetect') ~= 'AvalonHttpLuci' then
                    -- Example: 1246-N-85-21100123_456789a_bcdef01
                    local version = string.gsub(miner:opt('firmware_version'), '[-_][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]+', '')
                    model = 'AvalonMiner '..version
                    miner:setTypeStr("AvalonDeviceCgi")
                    miner:setOpt("upgrader.disabled", "true")
                end

                miner:setFullTypeStr(model)
                miner:setOpt('minerTypeFound', 'true')
            end
        end
    end
end

function GenericCgminerApi:getSummary()
    self.context:setRequestContent('{"command":"summary"}')
    self:setStep('parseSummary', 'read summary...')
end

function GenericCgminerApi:parseSummary(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat == "success") then
        self:doParseSummary(response, miner)
    end
    self:setStep('getTemperature', stat or 'unknown')
end

function GenericCgminerApi:doParseSummary(jsonStr, miner)
    local obj, pos, err = utils.jsonDecode(jsonStr)

    if not err and type(obj) == "table" then
        local status = obj.STATUS
        local summary = obj.SUMMARY

        if type(status) == "table" and type(status[1]) == "table" then
            status = status[1]

            if (status['Description'] ~= nil) then
                miner:setOpt('software_version', status['Description'])
            end
        end

        if type(summary) == "table" and type(summary[1]) == "table" then
            summary = summary[1]

            if summary['Elapsed'] ~= nil then
                miner:setOpt('elapsed', utils.formatTime(summary['Elapsed'], 'd :h :m :s '))
            end

            function getHashrateName(summary)
                local names = {
                    'MHS 1m',
                    'MHS 30s',
                    'MHS 5s',
                    'MHS 5m',
                    'MHS 15m',
                }
                for i = 1, #names do
                    if summary[names[i]] ~= nil then
                        return names[i]
                    end
                end
                return names[0]
            end

            local mhsName = getHashrateName(summary)
            if summary[mhsName] ~= nil then
                local hashrate = tonumber(summary[mhsName])
                if hashrate < 1000 and hashrate > 0 then
                    miner:setOpt('hashrate_5s', summary[mhsName]..' MH/s')
                else
                    miner:setOpt('hashrate_5s', string.format("%.2f", hashrate / 1000)..' GH/s')
                end
            end

            if summary['MHS av'] ~= nil then
                local hashrate = tonumber(summary['MHS av'])
                if hashrate < 1000 and hashrate > 0 then
                    miner:setOpt('hashrate_avg', summary['MHS av']..' MH/s')
                else
                    miner:setOpt('hashrate_avg', string.format("%.2f", hashrate / 1000)..' GH/s')
                end
            end

            -- firmware
            if summary['Firmware Version'] ~= nil then
                -- it looks like: "Firmware Version": "'20200917.22.REL'"
                -- So we need to remove the single quotes
                miner:setOpt('firmware_version', string.gsub(summary['Firmware Version'], "'", ""))
            end
            
            -- hardware
            local hardware = ""
            if summary['CB Platform'] ~= nil then
                hardware = summary['CB Platform']
            end
            if summary['CB Version'] ~= nil then
                local sep = (hardware == "") and "" or " "
                hardware = hardware .. sep .. summary['CB Version']
            end
            if hardware ~= "" then
                miner:setOpt('hardware_version', hardware)
            end

            -- mac address
            if summary['MAC'] ~= nil then
                miner:setOpt('mac_address', summary['MAC'])
            end

            -- working mode
            if summary['Power Mode'] ~= nil then
                miner:setOpt("antminer.overclock_working_mode", summary['Power Mode'])
            end

            -- Temperature
            local temp = {}
            if summary['Temperature'] ~= nil then
                table.insert(temp, summary['Temperature'])
            end
            -- In order to be consistent with WhatsMinerHttpsLuci, these temperatures are no longer displayed
            --[[
            if summary['Chip Temp Min'] ~= nil then
                table.insert(temp, summary['Chip Temp Min'])
            end
            if summary['Chip Temp Avg'] ~= nil then
                table.insert(temp, summary['Chip Temp Avg'])
            end
            if summary['Chip Temp Max'] ~= nil then
                table.insert(temp, summary['Chip Temp Max'])
            end
            ]]
            if #temp > 0 then
                miner:setOpt("temperature", table.concat(temp, ' / '))
            end

            -- fan speed
            local fan = {}
            if summary['Fan Speed In'] ~= nil then
                table.insert(fan, summary['Fan Speed In'])
            end
            if summary['Fan Speed Out'] ~= nil then
                table.insert(fan, summary['Fan Speed Out'])
            end
            if #fan > 0 then
                miner:setOpt('fan_speed', table.concat(fan, ' / '))
            end
        end
    end
end

function GenericCgminerApi:getTemperature()
    self.context:setRequestContent('{"command":"devs"}')
    self:setStep('parseTemperature', 'read temperature...')
end

function GenericCgminerApi:parseTemperature(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat == "success") then
        self:doParseTemperature(response, miner)
    end

    self:setStep('end', stat or 'unknown')

    -- find more infos from http
    local minerType = miner:opt('httpDetect')
    if (_G[minerType]) then
        self.parent:setExecutor(self.context, _G[minerType](self.parent, self.context))
    end
end

function GenericCgminerApi:doParseTemperature(jsonStr, miner)
    local obj, pos, err = utils.jsonDecode(jsonStr)

    if not err and type(obj) == "table" then
        local devs = obj.DEVS
        if type(devs) == "table" and type(devs[1]) == "table" then
            local temp = {}
            for _, chip in ipairs(devs) do
                if type(chip) == "table" and chip.Temperature ~= nil
                    and chip.Temperature > -100 -- we got -273.00 with Avalon 10
                then
                    table.insert(temp, chip.Temperature)
                end
            end
            if #temp > 0 then
                miner:setOpt("temperature", table.concat(temp, ' / '))
            end
        end
    end
end
