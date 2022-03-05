AvalonDeviceCgi = oo.class({}, ExecutorBase)

function AvalonDeviceCgi:__init(parent, context)
    local miner = context:miner()
    local ip = miner:ip()
    if context:miner():opt('minerTypeFound') ~= 'true' then
        miner:setFullTypeStr("Avalon Device")
    end
    miner:setTypeStr("AvalonDeviceCgi")
    miner:setOpt("upgrader.disabled", "true")

    if (miner:opt("httpPortAvailable") == "true") then
        local timeout = context:requestSessionTimeout() * 5
        if (timeout < 5) then
            timeout = 5
        end
        context:setRequestSessionTimeout(timeout)
    end

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep("login")
    return obj
end

function AvalonDeviceCgi:login()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()
    local loginPassword = utils.getMinerLoginPassword(miner:typeStr())

    if (loginPassword == nil) then
        self:setStep("end", "require password")
        return
    end

    local request = {
        method = 'POST',
        host = ip,
        path = '/login.cgi',
        body = 'username='..loginPassword.userName..'&passwd='..loginPassword.password,
        headers = {
            ['Content-Type'] = 'application/x-www-form-urlencoded'
        }
    }

    context:setRequestHost(ip)
    context:setRequestPort("80")
    context:setRequestContent(http.makeRequest(request))

    self:setStep("doLogin", "login...")
end

function AvalonDeviceCgi:doLogin(response, stat)
    response = http.parseResponse(response)
    if (response.statCode ~= "200" or
        not string.match(response.body, "get_minerinfo.cgi"))
    then
        self:setStep("end", "login failed")
        return
    end

    self:setStep("getMinerInfo", "success")
end

function AvalonDeviceCgi:getMinerInfo()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/get_minerinfo.cgi',
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep('doGetMinerInfo', 'find type...')
end

function AvalonDeviceCgi:doGetMinerInfo(response, stat)
    local context = self.context
    local miner = context:miner()
    response = http.parseResponse(response)

    local version = string.match(response.body, '"version"%s*:%s*"([^"]+)"')
    if version ~= nil and version ~= "" then
        miner:setOpt('firmware_version', version)
    end

    local mac = string.match(response.body, '"mac"%s*:%s*"([^"]+)"')
    if mac ~= nil and mac ~= "" then
        miner:setOpt('mac_address', mac)
    end

    local hwType = string.match(response.body, '"hwtype"%s*:%s*"([^"]+)"')
    if hwType ~= nil and hwType ~= "" then
        miner:setOpt("minerTypeFound", "true")
        miner:setFullTypeStr(hwType)
    end

    if miner:opt('avalon_found_mm_id0') == 'true' then
        self:setStep("updateCgConf", "success")
    else
        self:setStep("updateCgLog", "success")
    end
end

function AvalonDeviceCgi:updateCgLog()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/updatecglog.cgi',
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep('doUpdateCgLog', 'get status...')
end

function AvalonDeviceCgi:doUpdateCgLog(response, stat)
    local context = self.context
    local miner = context:miner()

    response = http.parseResponse(response)
    local data = response.body

    do
        local names = {
            'MHS 1m',
            'MHS 30s',
            'MHS 5s',
            'MHS 5m',
            'MHS 15m',
        }
        for i = 1, #names do
            local mhs = string.match(data, "'"..names[i].."'%s*:%s*([^,]+)%s*,")
            if mhs ~= nil and mhs ~= "" then
                local hashrate = tonumber(mhs)
                if hashrate < 1000 and hashrate > 0 then
                    miner:setOpt('hashrate_5s', mhs..' MH/s')
                else
                    miner:setOpt('hashrate_5s', string.format("%.2f", hashrate / 1000)..' GH/s')
                end
                break
            end
        end
    end

    
    do
        local mhs = string.match(data, "'MHS av'%s*:%s*([^,]+)%s*,")
        if mhs ~= nil and mhs ~= "" then
            local hashrate = tonumber(mhs)
            if hashrate < 1000 and hashrate > 0 then
                miner:setOpt('hashrate_avg', mhs..' MH/s')
            else
                miner:setOpt('hashrate_avg', string.format("%.2f", hashrate / 1000)..' GH/s')
            end
        end
    end

    do
        local elapsed = string.match(data, "'Elapsed'%s*:%s*([^,]+)%s*,")
        if elapsed ~= nil and elapsed ~= "" then
            miner:setOpt('elapsed', utils.formatTime(elapsed, 'd :h :m :s '))
        end
    end

    do
        local desc = string.match(data, "'Description'%s*:%s*'([^']+)'")
        if desc ~= nil and desc ~= "" then
            miner:setOpt('software_version', desc)
        end
    end

    do
        local iter = string.gmatch(data, '%f[%a]Fan[0-9]+%[([^%]]+)%]')
        local fan = {}
        while true do
            local speed = iter()
            print(speed)
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

    self:setStep("updateCgConf", "success")
end

function AvalonDeviceCgi:updateCgConf()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/updatecgconf.cgi',
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep('doUpdateCgConf', 'get pools...')
end

function AvalonDeviceCgi:doUpdateCgConf(response, stat)
    local context = self.context
    local miner = context:miner()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    response = http.parseResponse(response)
    local json = string.match(response.body, 'CGConfCallback%(({.*})%);')

    if json ~= nil then
        local options, _, err = utils.jsonDecode(json)
        if type(options) == "table" then
            pool1:setUrl(options.pool1)
            pool2:setUrl(options.pool2)
            pool3:setUrl(options.pool3)

            pool1:setWorker(options.worker1)
            pool2:setWorker(options.worker2)
            pool3:setWorker(options.worker3)
            
            pool1:setPasswd(options.passwd1)
            pool2:setPasswd(options.passwd2)
            pool3:setPasswd(options.passwd3)

            if options.mode ~= nil and options.mode ~= "" then
                miner:setOpt('avalon.overclock_working_mode', options.mode)
                miner:setOpt('antminer.overclock_working_mode', 'Mode ' .. options.mode)
            end
        end
    end

    self:setStep("updateNetwork", "success")
end

function AvalonDeviceCgi:updateNetwork()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/updatenetwork.cgi',
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep('doUpdateNetwork', 'get network info...')
end

function AvalonDeviceCgi:doUpdateNetwork(response, stat)
    local context = self.context
    local miner = context:miner()

    response = http.parseResponse(response)
    local json = string.match(response.body, 'NetworkCallback%(({.*})%);')

    if json ~= nil then
        local options, _, err = utils.jsonDecode(json)
        if type(options) == "table" then
            if options.protocal ~= nil then
                miner:setOpt('network_type', (options.protocol == 0 and 'DHCP' or 'STATIC'))
            end
        end
    end

    self:setStep("cgConf", "success")
end

function AvalonDeviceCgi:cgConf()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'POST',
        host = ip,
        path = '/cgconf.cgi',
        body = '',
        headers = {
            ['Content-Length'] = 0,
        }
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep('doCgConf', 'read overclock option...')
end

function AvalonDeviceCgi:doCgConf(response, stat)
    local context = self.context
    local miner = context:miner()

    response = http.parseResponse(response)

    local workMode = string.match(response.body, '<select name="mode" id="mode">(.-)</select>')
    local iter = string.gmatch(workMode, '<option value="([^"]+)">([^<]+)</option>')

    local options = {}
    while true do
        local value, name = iter()
        if value == nil or name == nil then
            break
        end
        table.insert(options, {
            ModeName = name,
            ModeValue = value,
            Level = {
                Normal = "",
            }
        })
        if miner:opt('avalon.overclock_working_mode') == value then
            miner:setOpt('antminer.overclock_working_mode', name)
        end
    end
    local overclockOption = {
        ModeInfo = options
    }
    miner:setOpt('antminer.overclock_option', utils.jsonEncode(overclockOption))

    self:setStep("end", "success")
end
