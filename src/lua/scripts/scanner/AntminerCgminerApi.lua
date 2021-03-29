AntminerCgminerApi = oo.class({}, ExecutorBase)


function AntminerCgminerApi:__init(parent, context)
    if context:miner():opt('minerTypeFound') ~= 'true' then
        context:miner():setFullTypeStr('Antminer *') -- used for utils.getMinerLoginPassword()
        context:miner():setTypeStr('AntminerHttpCgi')
    end

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep('begin', 'find antminer')
    return obj
end

function AntminerCgminerApi:regularTypeStr(fullTypeStr)
    local typeStr = 'unknown'
    local typeLowerStr = string.lower(fullTypeStr)

    if (string.match(typeLowerStr, 'antminer')) then
        typeStr = 'AntminerHttpCgi'
    end

    return typeStr
end

function AntminerCgminerApi:parseMinerStats(jsonStr, miner, reqStat)
    local typeStr = 'unknown'
    local fullTypeStr = 'Unknown'

    if (reqStat == "success") then
        local obj, pos, err = utils.jsonDecode (jsonStr)

        if not err then
            local status = obj.status
            local stat = obj.STATS

            if (type(stat) == "table" and type(stat[1]) == "table" and type(stat[1].Type) == "string") then
                fullTypeStr = stat[1].Type
            end

            typeStr = self:regularTypeStr(fullTypeStr)

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

                    miner:setOpt('temperature', table.concat(temp, ' / '))
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

                    miner:setOpt('fan_speed', table.concat(fan, ' / '))
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
    else
        fullTypeStr = ''
    end

    miner:setTypeStr(typeStr)
    miner:setFullTypeStr(fullTypeStr)
    miner:setOpt('minerTypeFound', 'true')

    return true
end

function AntminerCgminerApi:parseMinerPools(jsonStr, miner, stat)
    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()

    local findSuccess = false

    if (stat == "success") then
        local obj, pos, err = utils.jsonDecode (jsonStr)

        if not err then
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
    end

    return findSuccess
end

function AntminerCgminerApi:begin()
    local context = self.context
    local miner = context:miner()

    context:setRequestHost(miner:ip())
    context:setRequestPort('4028')
    context:setRequestContent('{"command":"stats"}')

    self:setStep('parseStats', 'find type...')
end

function AntminerCgminerApi:parseStats(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat ~= "success") then
        local isAntminer = (miner:opt('httpDetect') == 'AntminerHttpCgi')
        if (isAntminer) then
            self.parent:setExecutor(self.context, AntminerHttpCgi(self.parent, self.context))
        else
            self:setStep('end', stat or 'unknown')
        end

        return
    end

    self:parseMinerStats(response, miner, stat)
    self:setStep('findPools')
end

function AntminerCgminerApi:findPools()
    self.context:setRequestContent('{"command":"pools"}')
    self:setStep('parsePools', 'find pools...')
end

function AntminerCgminerApi:parsePools(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat == "success") then
        self:parseMinerPools(response, miner, stat)
        self:setStep('end', 'success')
    else
        self:setStep('end', stat or 'unknown')
    end

    -- find more infos from http
    local isAntminer = (miner:opt('httpDetect') == 'AntminerHttpCgi')
    if (isAntminer) then
        self.parent:setExecutor(self.context, AntminerHttpCgi(self.parent, self.context))
    end
end
