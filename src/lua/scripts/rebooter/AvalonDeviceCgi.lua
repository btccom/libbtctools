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

    self:setStep("reboot", "success")
end

function AvalonDeviceCgi:reboot()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'POST',
        host = ip,
        path = '/reboot_btn.cgi',
        body = '',
        headers = {
            ['Content-Length'] = 0,
        }
    }
    context:setRequestContent(http.makeRequest(request))
    self:setStep('doReboot', 'rebooting...')
end

function AvalonDeviceCgi:doReboot(response, stat)
    local context = self.context
    local miner = context:miner()
    response = http.parseResponse(response)

    if not string.match(response.body, 'device reboot...') then
        self:setStep("end", "perform reboot failed")
        return
    end

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
        self:setStep('end', 'rebooted')
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
