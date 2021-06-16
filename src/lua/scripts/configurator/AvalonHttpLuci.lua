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

    self:setStep("updateConfig", "success")
end

function AvalonHttpLuci:makeLuciRequest(apiPath, formParams)
    local request = {
        method = formParams and 'POST' or 'GET',
        host = self.context:miner():ip(),
        path = '/cgi-bin/luci/;stok=' .. self.stok .. apiPath,
        headers = {
            ['Cookie'] = self.cookie,
            ['Content-Type'] = formParams and 'application/x-www-form-urlencoded' or nil
        },
        body = formParams and utils.makeUrlQueryString(formParams) or nil
    }
    self.context:setRequestContent(http.makeRequest(request))
end

function AvalonHttpLuci:updateConfig()
    local miner = self.context:miner()
    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()

    local formParams = {
        ['cbi.submit'] = '1',
        ['cbid.cgminer.default.ntp_enable'] = miner:opt('luci.config.cgminer.ntp_enable') or 'disable',
        ['cbid.cgminer.default.pool1url'] = pool1:url(),
        ['cbid.cgminer.default.pool1user'] = pool1:worker(),
        ['cbid.cgminer.default.pool1pw'] = pool1:passwd(),
        ['cbid.cgminer.default.pool2url'] = pool2:url(),
        ['cbid.cgminer.default.pool2user'] = pool2:worker(),
        ['cbid.cgminer.default.pool2pw'] = pool2:passwd(),
        ['cbid.cgminer.default.pool3url'] = pool3:url(),
        ['cbid.cgminer.default.pool3user'] = pool3:worker(),
        ['cbid.cgminer.default.pool3pw'] = pool3:passwd(),
        ['cbi.apply'] = 'Save & Apply'
    }

    self:makeLuciRequest('/avalon/page/configure', formParams)
    self:setStep('readUpdateResult', 'update config...')
end

function AvalonHttpLuci:readUpdateResult(response, stat)
    if not string.match(response, 'servicectl/restart/cgminer') then
        self:setStep('end', 'update config failed')
        return
    end

    self:setStep("restartCgminer", "ok")
end

function AvalonHttpLuci:restartCgminer()
    self.context:setRequestDelayTimeout(5)
    self:makeLuciRequest('/servicectl/restart/cgminer')
    self:setStep("readRestartResult", 'restart cgminer...')
end

function AvalonHttpLuci:readRestartResult(response, stat)
    response = http.parseResponse(response)

    local result = utils.trimAll(response.body)
    if result ~= "OK" then
        self:setStep('end', result)
        return
    end

    local miner = self.context:miner()
    miner:setOpt('check-restart-finish-times', '0')
    self:setStep("waitRestartFinish", "ok")
    self:disableRetry()
end

function AvalonHttpLuci:waitRestartFinish()
    self.context:setRequestDelayTimeout(1)
    self:makeLuciRequest('/servicectl/status')
    self:setStep("checkRestartFinish", 'wait finish...')
end

function AvalonHttpLuci:checkRestartFinish(response, stat)
    response = http.parseResponse(response)

    local result = utils.trimAll(response.body)

    if (result == 'finish') then
        self:setStep('end', 'ok')
        return
    end

    local miner = self.context:miner()
    local times = tonumber(miner:opt('check-restart-finish-times'))
    if (times > 20) then
        self:setStep('end', 'timeout, may succeeded')
        return
    end

    miner:setOpt('check-restart-finish-times', tostring(times + 1))
    self:setStep('waitRestartFinish', 'not finish')
end
