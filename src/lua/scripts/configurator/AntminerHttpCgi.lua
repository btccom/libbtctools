AntminerHttpCgi = oo.class({}, ExecutorBase)


function AntminerHttpCgi:begin()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/cgi-bin/minerConfiguration.cgi',
    }

    context:setRequestHost(ip)
    context:setRequestPort("80")
    context:setRequestContent(http.makeRequest(request))
    self:setStep('auth', 'login...')
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
    self:setStep("updateMinerConf", 'read config...')
end

function AntminerHttpCgi:updateMinerConf(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then return end

    -- the default failed order of keys
    local formKeys = {
        "_ant_pool1url",
        "_ant_pool1user",
        "_ant_pool1pw",
        "_ant_pool2url",
        "_ant_pool2user",
        "_ant_pool2pw",
        "_ant_pool3url",
        "_ant_pool3user",
        "_ant_pool3pw",
        "_ant_nobeeper",
        "_ant_notempoverctrl",
        "_ant_fan_customize_switch",
        "_ant_fan_customize_value",
        "_ant_freq",
        "_ant_voltage",
        "_ant_asic_boost",
        "_ant_low_vol_freq",
        "_ant_economic_mode",
        "_ant_multi_level",
        "_ant_force_tuning",
    }

    -- Auto detecting the order of keys.
    -- It's so important because the miner's cgi script hardcoded the orders when parse params.

    local formKeysJsonStr = string.match(response.body, "data%s*:%s*{(.-)}%s*,%s*[\r\n]")

    -- Cannot find the string, indicating that the miner uses another web interface
    if not formKeysJsonStr then
        self:setStep('getMinerConfJSONBody')
        return
    end

    formKeysJsonStr = '[' .. string.gsub(formKeysJsonStr, "([a-zA-Z0-9_-]+):[a-zA-Z0-9_-]+", '"%1"') .. ']'
    local newFormKeys, pos, err = utils.jsonDecode (formKeysJsonStr)

    if (not err) and (type(newFormKeys) == "table") then
        formKeys = newFormKeys
    else
        utils.debugInfo('updateMinerConf', 'inexpectant newFormKeys: '..tostring(newFormKeys))
    end

    -- All known form params from Antminer S4 to S9
    local formParams = {
        _ant_pool1url = pool1:url(),
        _ant_pool1user = pool1:worker(),
        _ant_pool1pw = pool1:passwd(),
        _ant_pool2url = pool2:url(),
        _ant_pool2user = pool2:worker(),
        _ant_pool2pw = pool2:passwd(),
        _ant_pool3url = pool3:url(),
        _ant_pool3user = pool3:worker(),
        _ant_pool3pw = pool3:passwd(),
        _ant_nobeeper = "false",
        _ant_notempoverctrl = "false",
        _ant_fan_customize_switch = "false",
        _ant_fan_customize_value = "",
        _ant_freq = "",
        _ant_voltage = "",

        -- Some models have these configurations
        _ant_asic_boost = "false", -- false: enable ASICBoost; true: disable ASICBoost
        _ant_low_vol_freq = "true", -- true: normal freq; false: low freq
        _ant_economic_mode = "false", -- not use in AntMiner S9
        _ant_multi_level = "1", -- for AntMiner S9 overclocking
        _ant_force_tuning = "false", -- retry overclocking

        -- Other models have these configurations
        _ant_work_mode = ""
    }

    local bmconfJsonStr = string.match(string.gsub(response.body, "\n%s*EOF%s*", "\n"), "ant_data%s*=%s*({.-})%s*;%s*[\r\n]")
    if bmconfJsonStr then
        local bmconf, pos, err = utils.jsonDecode (bmconfJsonStr)
        -- Origin values of params
        if not (err) then
            if (bmconf['bitmain-nobeeper'] ~= nil) then
                formParams._ant_nobeeper = bmconf['bitmain-nobeeper']
            end

            if (bmconf['bitmain-notempoverctrl'] ~= nil) then
                formParams._ant_notempoverctrl = bmconf['bitmain-notempoverctrl']
            end

            if (bmconf['bitmain-fan-ctrl'] ~= nil) then
                formParams._ant_fan_customize_switch = bmconf['bitmain-fan-ctrl']
            end

            if (bmconf['bitmain-fan-pwm'] ~= nil) then
                formParams._ant_fan_customize_value = bmconf['bitmain-fan-pwm']
            end

            if (bmconf['bitmain-freq'] ~= nil) then
                formParams._ant_freq = bmconf['bitmain-freq']
            end

            if (bmconf['bitmain-voltage'] ~= nil) then
                formParams._ant_voltage = bmconf['bitmain-voltage']
            end

            if (bmconf['bitmain-close-asic-boost'] ~= nil) then
                formParams._ant_asic_boost = bmconf['bitmain-close-asic-boost']
            end

            if (bmconf['bitmain-close-low-vol-freq'] ~= nil) then
                formParams._ant_low_vol_freq = bmconf['bitmain-close-low-vol-freq']
            end

            if (bmconf['bitmain-economic-mode'] ~= nil) then
                formParams._ant_economic_mode = bmconf['bitmain-economic-mode']
            end

            if (bmconf['bitmain-low-vol'] ~= nil) then
                formParams._ant_multi_level = bmconf['bitmain-low-vol']
            end

            if (bmconf['bitmain-work-mode'] ~= nil) then
                formParams._ant_work_mode = bmconf['bitmain-work-mode']
            end

            if (bmconf['bitmain-ex-hashrate'] ~= nil) then
                formParams._ant_multi_level = bmconf['bitmain-ex-hashrate']
            end
        end
    else
        utils.debugInfo('updateMinerConf', 'cannot find bmconfJsonStr')
    end

    -- Custom values of params
    local activeWorkingModeName = ''
    local activeLevelName = ''
    if (miner:opt("config.antminer.overclockWorkingMode") ~= "") then

        local workingModeName = miner:opt("config.antminer.overclockWorkingMode")
        local workingMode = nil

        local options, _, optionErr = utils.jsonDecode (miner:opt('antminer.overclock_option'))
        if not (optionErr) then
            for _, mode in ipairs(options.ModeInfo) do
                if mode.ModeName == workingModeName then
                    workingMode = mode
                    formParams._ant_work_mode = mode.ModeValue
                    activeWorkingModeName = workingModeName
                    break
                end
            end
        end

        local levelName = miner:opt("config.antminer.overclockLevelName")
        local levelValue = nil

        if (workingMode ~= nil) then
            levelValue = workingMode.Level[levelName]

            if levelValue ~= nil then
                if (miner:opt("antminer.overclock_to_freq") == "true") then
                    formParams._ant_freq = levelValue
                else
                    formParams._ant_multi_level = levelValue
                end
                activeLevelName = levelName
            end
        end
    end

    if activeLevelName ~= activeWorkingModeName then
        activeWorkingModeName = utils.append(activeWorkingModeName, activeLevelName)
    end

    if (miner:opt("config.antminer.asicBoost") ~= "") then
        if (miner:opt("config.antminer.asicBoost") == "true") then
            -- it should be named "_ant_disable_low_vol_freq"
            formParams._ant_asic_boost = "false"
            activeWorkingModeName = utils.append(activeWorkingModeName, 'LPM')
        else
            formParams._ant_asic_boost = "true"
        end
    end

    if (miner:opt("config.antminer.lowPowerMode") ~= "") then
        if (miner:opt("config.antminer.lowPowerMode") == "true") then
            -- it should be named "_ant_disable_low_vol_freq"
            formParams._ant_low_vol_freq = "false"
            activeWorkingModeName = utils.append(activeWorkingModeName, 'Enhanced LPM')
        else
            formParams._ant_low_vol_freq = "true"
        end
    end

    miner:setOpt('antminer.overclock_working_mode', activeWorkingModeName)

    if (miner:opt("config.antminer.economicMode") ~= "") then
        formParams._ant_economic_mode = miner:opt("config.antminer.economicMode")
    end

    if (miner:opt("config.antminer.forceTuning") ~= "") then
        formParams._ant_force_tuning = miner:opt("config.antminer.forceTuning")
    end

    local request = http.parseRequest(context:requestContent())
    request.method = 'POST';
    request.path = '/cgi-bin/set_miner_conf.cgi';
    request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = utils.makeUrlQueryString(formParams, formKeys)

    self:makeAuthRequest(request)
    self:setStep("setMinerConf")
end

function AntminerHttpCgi:getMinerConfJSONBody()
    self:makeAuthRequest('/cgi-bin/get_miner_conf.cgi')
    self:setStep("updateMinerConfJSONBody", 'read config...')
end

function AntminerHttpCgi:updateMinerConfJSONBody(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then return end

    local bmconf, pos, err = utils.jsonDecode (response.body)

    if err then
        bmconf = {
            pools = {
                [1] = {},
                [2] = {},
                [3] = {},
            }
        }
    end

    local pools = bmconf.pools
    if not pools then
        if bmconf.channels and bmconf.channels[1] and bmconf.channels[1].pools then
            pools = bmconf.channels[1].pools
        end
    end

    if pools then
        if pools[1] then
            pools[1].url = pool1:url()
            pools[1].user = pool1:worker()
            pools[1].pass = pool1:passwd()
        end

        if pools[2] then
            pools[2].url = pool2:url()
            pools[2].user = pool2:worker()
            pools[2].pass = pool2:passwd()
        end

        if pools[3] then
            pools[3].url = pool3:url()
            pools[3].user = pool3:worker()
            pools[3].pass = pool3:passwd()
        end
    end

    -- Optional params
    local activeWorkingModeName = ''
    local activeLevelName = ''
    if (miner:opt("config.antminer.overclockWorkingMode") ~= "") then

        local workingModeName = miner:opt("config.antminer.overclockWorkingMode")
        local workingMode = nil

        local options, _, optionErr = utils.jsonDecode (miner:opt('antminer.overclock_option'))
        if not (optionErr) then
            for _, mode in ipairs(options.ModeInfo) do
                if mode.ModeName == workingModeName then
                    workingMode = mode
                    bmconf['miner-mode'] = mode.ModeValue
                    activeWorkingModeName = workingModeName
                    break
                end
            end
        end

        local levelName = miner:opt("config.antminer.overclockLevelName")
        local levelValue = nil

        if (workingMode ~= nil) then
            levelValue = workingMode.Level[levelName]

            if levelValue ~= nil then
                bmconf['freq-level'] = levelValue
                activeLevelName = levelName
            end
        end
    end

    if activeLevelName ~= activeWorkingModeName then
        activeWorkingModeName = utils.append(activeWorkingModeName, activeLevelName)
    end

    local request = http.parseRequest(context:requestContent())
    request.method = 'POST';
    request.path = '/cgi-bin/set_miner_conf.cgi';
    request.headers['Content-Type'] = 'application/json'
    request.body = utils.jsonEncode(bmconf)

    self:makeAuthRequest(request)
    self:setStep("setMinerConf")
end

function AntminerHttpCgi:setMinerConf()
    self:setStep("parseResult", 'update config...')

    -- Because the new miner firmware takes several minutes to
    -- complete the HTTP response, we should not wait longer.
    --[[
    -- set a long waiting time of the result
    local timeout = self.context:requestSessionTimeout() * 5
    if (timeout < 10) then
        timeout = 10
    end
    self.context:setRequestSessionTimeout(timeout)
    ]]
end

function AntminerHttpCgi:parseResult(httpResponse, stat)
    if stat ~= 'success' then
        stat = stat .. ', may succeeded'
    end

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then
        self:setStep('end', stat)
        return
    end

    local result = utils.trimAll(response.body)
    if result == '' then
        utils.debugInfo('parseResult', 'may succeeded')
        self:setStep('end', stat)
        return
    end

    -- got a HTML result
    if string.sub(result, 1, 1) == '<' then
        utils.debugInfo('parseResult', 'got a HTML result')

        local title = string.match(result, '<title>%s*(.*)%s*</title>')
        if title and title ~= '' then
            result = title
        end
    end

    self:setStep('end', result)
end
