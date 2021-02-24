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
        self.parent:setExecutor(self.context, AntminerCgminerApi(self.parent, self.context))
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
        self.parent:setExecutor(self.context, AntminerCgminerApi(self.parent, self.context))
        return
    end

    if (response.statCode == "200" and
        string.match(response.body, '/luci/avalon/'))
    then
        miner:setOpt('httpDetect', 'AvalonHttpLuci')
        self.parent:setExecutor(self.context, AvalonHttpLuci(self.parent, self.context))
        return
    end

    if (response.statCode == "200" and
        string.match(response.body,'Lua Configuration Interface')
        )
    then
        miner:setOpt('httpDetect', 'BosHttpLuci')
        self.parent:setExecutor(self.context, BosHttpLuci(self.parent, self.context))
        return
    end

    utils.debugInfo('HttpAutoDetect:detect', 'unknown miner', context, response, stat)

    miner:setOpt('httpDetect', 'unknown')
    miner:setTypeStr('unknown')
    miner:setFullTypeStr('')
    -- Try cgminer api even if HTTP fails
    self.parent:setExecutor(self.context, AntminerCgminerApi(self.parent, self.context))
end
