AntminerHttpCgi = oo.class({}, ExecutorBase)


function AntminerHttpCgi:begin()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/cgi-bin/reboot.cgi',
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

    self:setStep("reboot")
end

function AntminerHttpCgi:reboot()
    self:makeAuthRequest()
    self:setStep("doReboot", 'rebooting...')
end

function AntminerHttpCgi:doReboot(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)
    if (response and response.statCode == "401") then
        self:setStep("end", 'login failed')
        return
    end

    self.context:miner():setOpt('check-reboot-finish-times', '0')
    self:setStep("waitFinish")
    self:disableRetry()
end

function AntminerHttpCgi:waitFinish()
    self.context:setRequestDelayTimeout(5)
    self.context:setRequestSessionTimeout(5)
    self:makeAuthRequest('/cgi-bin/get_system_info.cgi')
    self:setStep("doWaitFinish", 'wait finish...')
end

function AntminerHttpCgi:doWaitFinish(httpResponse, stat)
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
