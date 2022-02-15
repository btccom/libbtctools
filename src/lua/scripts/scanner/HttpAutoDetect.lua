HttpAutoDetect = oo.class({}, ExecutorBase)

function HttpAutoDetect:begin()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/'
    }

    context:setRequestContent(http.makeRequest(request))
    context:setRequestHost(ip)
    context:setRequestPort("80")

    self:setStep('detect', 'http detect...')
end

function HttpAutoDetect:detect(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat ~= "success") then
        miner:setOpt('httpDetect', 'unknown')
        miner:setTypeStr('unknown')
        miner:setFullTypeStr('')
        -- Try cgminer api even if HTTP fails
        self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
        return
    end

    miner:setOpt('httpPortAvailable', 'true')
    response = http.parseResponse(response)

    if (response.statCode == "401" and
        response.headers['www-authenticate'] and
        response.headers['www-authenticate'][1] and
        string.match(response.headers['www-authenticate'][1], '^Digest%s'))
    then
        miner:setOpt('httpDetect', 'AntminerHttpCgi')
        self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
        return
    end

    if (response.statCode == "200" and
        string.match(response.body, '/luci/avalon/'))
    then
        miner:setOpt('httpDetect', 'AvalonHttpLuci')
        self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
        return
    end

    if (response.statCode == "200" and
        string.match(response.body, 'Lua Configuration Interface')
        )
    then
        miner:setOpt('httpDetect', 'BosHttpLuci')
        self.parent:setExecutor(self.context, BosHttpLuci(self.parent, self.context))
        return
    end

    if (response.statCode == "200" and
        string.match(response.body, 'AnthillOS'))
    then
        miner:setOpt('httpDetect', 'AnthillOS')
        self.parent:setExecutor(self.context, AnthillOS(self.parent, self.context))
        return
    end

    if (response.statCode == "307" and
        response.headers['location'] and
        response.headers['location'][1] and
        string.match(response.headers['location'][1], '^https://')
        )
    then
        -- detectHttps is too slow so skip it. Currently only WhatsMiner uses https.
        --self:setStep('detectHttps')
        
        miner:setOpt('httpDetect', 'WhatsMinerHttpsLuci')
        self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
        return
    end

    if (response.statCode == "200" and
        string.match(response.body, 'Avalon Device') and
        string.match(response.body, 'login.cgi'))
    then
        miner:setOpt('httpDetect', 'AvalonDeviceCgi')
        self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
        return
    end

    utils.debugInfo('HttpAutoDetect:detect', 'unknown device')

    miner:setOpt('httpDetect', 'unknown')
    miner:setTypeStr('unknown')
    miner:setFullTypeStr('')
    -- Try cgminer api even if HTTP fails
    self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
end

function HttpAutoDetect:detectHttps()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/cgi-bin/luci'
    }

    context:setRequestContent(http.makeRequest(request))
    context:setRequestHost("tls://"..ip)
    context:setRequestPort("443")
    self:setStep('doDetectHttps', 'https detect...')
end

function HttpAutoDetect:doDetectHttps(response, stat)
    local context = self.context
    local miner = context:miner()

    if (stat ~= "success" and stat ~= "stream truncated") then
        miner:setOpt('httpDetect', 'unknown')
        miner:setTypeStr('unknown')
        miner:setFullTypeStr('')
        -- Try cgminer api even if HTTP fails
        self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
        return
    end

    miner:setOpt('httpsPortAvailable', 'true')
    response = http.parseResponse(response)

    if (response.statCode == "403" and
        string.match(response.body, 'WhatsMiner')
        )
    then
        miner:setOpt('httpDetect', 'WhatsMinerHttpsLuci')
        self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
        return
    end

    utils.debugInfo('HttpAutoDetect:doDetectHttps', 'unknown device')

    miner:setOpt('httpDetect', 'unknown')
    miner:setTypeStr('unknown')
    miner:setFullTypeStr('')
    -- Try cgminer api even if HTTP fails
    self.parent:setExecutor(self.context, GenericCgminerApi(self.parent, self.context))
end
