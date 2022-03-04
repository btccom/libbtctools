AvalonDeviceCgi = oo.class({}, ExecutorBase)

function AvalonDeviceCgi:begin()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()
    local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())

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

    self:setStep("cgConf", "success")
end

function AvalonDeviceCgi:cgConf()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    -- the default failed order of keys
    local formKeys = {
        "pool1",
        "worker1",
        "passwd1",
        "pool2",
        "worker2",
        "passwd2",
        "pool3",
        "worker3",
        "passwd3",
        "mode",
    }

    -- All known form params from Antminer S4 to S9
    local formParams = {
        pool1 = pool1:url(),
        worker1 = pool1:worker(),
        passwd1 = pool1:passwd(),
        pool2 = pool2:url(),
        worker2 = pool2:worker(),
        passwd2 = pool2:passwd(),
        pool3 = pool3:url(),
        worker3 = pool3:worker(),
        passwd3 = pool3:passwd(),
        mode = miner:opt('avalon.overclock_working_mode'),
    }

    local activeWorkingModeName = ''
    if (miner:opt("config.antminer.overclockWorkingMode") ~= "") then
        local workingModeName = miner:opt("config.antminer.overclockWorkingMode")

        local options, _, optionErr = utils.jsonDecode (miner:opt('antminer.overclock_option'))
        if not (optionErr) then
            for _, mode in ipairs(options.ModeInfo) do
                if workingModeName == mode.ModeName then
                    activeWorkingModeName = mode.ModeName
                    formParams.mode = mode.ModeValue
                    break
                end
            end
        end
    end
    miner:setOpt('antminer.overclock_working_mode', activeWorkingModeName)

    local request = {
        method = 'POST',
        host = ip,
        path = '/cgconf.cgi',
        body = utils.makeUrlQueryString(formParams, formKeys),
        headers = {
            ['Content-Type'] = 'application/x-www-form-urlencoded'
        }
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep("doCgConf", "update config...")
end

function AvalonDeviceCgi:doCgConf(response, stat)
    local context = self.context
    local miner = context:miner()

    response = http.parseResponse(response)
    if (response.statCode ~= "200" or
        not string.match(response.body, "Pool Config"))
    then
        self:setStep("end", "update config failed")
        return
    end

    self:setStep("reboot", "success")
end

function AvalonDeviceCgi:reboot()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'POST',
        host = ip,
        path = '/reboot.cgi',
        body = '',
        headers = {
            ['Content-Length'] = 0,
        }
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep('doReboot', 'rebooting...')
end

function AvalonDeviceCgi:doReboot()
    utils.sleep(20)
    self.context:miner():setOpt('check-reboot-finish-times', '0')
    self:setStep("waitFinish")
    self:disableRetry()
end

function AvalonDeviceCgi:waitFinish()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/',
    }
    context:setRequestContent(http.makeRequest(request))
    context:setRequestDelayTimeout(5)
    context:setRequestSessionTimeout(5)

    self:setStep("doWaitFinish", 'wait finish...')
end

function AvalonDeviceCgi:doWaitFinish(response, stat)
    local miner = self.context:miner()

    if (stat == 'success') then
        self:setStep('end', 'ok')
        return
    end

    local times = tonumber(miner:opt('check-reboot-finish-times'))
    if (times > 30) then
        self:setStep('end', 'timeout, may succeeded')
        return
    end

    miner:setOpt('check-reboot-finish-times', tostring(times + 1))
    self:setStep('waitFinish', 'not finish')
end
