AvalonHttpLuci = oo.class({}, ExecutorBase)

function AvalonHttpLuci:begin()
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
        path = '/cgi-bin/luci/avalon/page/index',
        body = 'username='..loginPassword.userName..'&password='..loginPassword.password,
        headers = {
            ['Content-Type'] = 'application/x-www-form-urlencoded'
        }
    }

    context:setRequestHost(ip)
    context:setRequestPort("80")
    context:setRequestContent(http.makeRequest(request))

    self:setStep("doLogin", "login...")
end

function AvalonHttpLuci:doLogin(response, stat)
    response = http.parseResponse(response)
    if (response.statCode ~= "302") then
        self:setStep("end", "login failed")
        return
    end

    local cookie = response.headers['set-cookie']
    local url = response.headers['location']

    if type(cookie) ~= 'table' or cookie[1] == nil
        or type(url) ~= 'table' or url[1] == nil
    then
        self:setStep("end", "login failed")
        return
    end

    self.cookie = string.gsub(cookie[1], ';.*', '')
    self.stok = string.match(url[1], '/;stok=([^/]*)/')

    self:setStep("reboot", "success")
end

function AvalonHttpLuci:makeLuciRequest(apiPath)
    local request = {
        method = 'GET',
        host = self.context:miner():ip(),
        path = '/cgi-bin/luci/;stok=' .. self.stok .. apiPath,
        headers = {
            ['Cookie'] = self.cookie
        }
    }
    self.context:setRequestContent(http.makeRequest(request))
end

function AvalonHttpLuci:reboot()
    self:makeLuciRequest('/admin/system/reboot?reboot=1')
    self:setStep('doReboot', 'rebooting...')
end

function AvalonHttpLuci:doReboot(response, stat)
    if not string.match(response, 'setTimeout') then
        self:setStep('end', 'reboot failed')
        return
    end

    self.context:miner():setOpt('check-reboot-finish-times', '0')
    self:setStep("waitFinish")
    self:disableRetry()
end

function AvalonHttpLuci:waitFinish()
    self.context:setRequestDelayTimeout(5)
    self.context:setRequestSessionTimeout(5)
    self:makeLuciRequest('/cgi-bin/luci')
    self:setStep("doWaitFinish", 'wait finish...')
end

function AvalonHttpLuci:doWaitFinish(httpResponse, stat)
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
