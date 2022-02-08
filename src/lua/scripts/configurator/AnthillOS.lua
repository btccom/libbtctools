AnthillOS = oo.class({}, ExecutorBase)

function AnthillOS:__init(parent, context)
    local obj = ExecutorBase.__init(self, parent, context)

    obj:setStep("getSession")

    obj.config = {
        miner = nil
    }

    return obj
end

function AnthillOS:getSession()
    self:setStep("parseSession", "login...")
    self:makeAnthillSessionReq();
end

function AnthillOS:parseSession(httpResponse, stat)
    local response = self:parseAnthillSessionReq(httpResponse, start)

    if (not response) then
        return
    end

    self:setStep('getMinerSettings')
end

function AnthillOS:getMinerSettings()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = 'GET',
        path = '/api/v1/settings',
        headers = {
            ['Authorization']=miner:opt('anthill_token'),
            ['content-type']='application/json; charset=utf-8'
        }
    }

    self:makeBasicHttpReq(request)

    self:setStep('parseMinerSettings')
end

function AnthillOS:parseMinerSettings(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    self.config.miner = {
        pools = {}
    }

    if obj.miner ~= nil and obj.miner.pools ~= nil then
        self.config.miner.pools = obj.miner.pools
    end

    if pool1:url() ~= "" and pool1:worker() ~= "" then
        self.config.miner.pools[1] = {
            url = pool1:url(),
            user = pool1:worker(),
            pass = pool1:passwd()
        }
    end

    if pool2:url() ~= "" and pool2:worker() ~= "" then
        self.config.miner.pools[2] = {
            url = pool2:url(),
            user = pool2:worker(),
            pass = pool2:passwd()
        }
    end

    if pool3:url() ~= "" and pool3:worker() ~= "" then
        self.config.miner.pools[3] = {
            url = pool3:url(),
            user = pool3:worker(),
            pass = pool3:passwd()
        }
    end

    self:setStep('setConfig', 'setting config...')
end

function AnthillOS:setConfig()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = 'POST',
        path = '/api/v1/settings',
        headers = {
            ['Authorization']=miner:opt('anthill_token'),
            ['content-type']='application/json; charset=utf-8'
        },
        body = utils.jsonEncode(self.config)
    }

    self:makeBasicHttpReq(request)

    self:setStep('parseApplyResult', 'apply result...');
end

function AnthillOS:parseApplyResult(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)

    if (not obj) then
        return
    end

    if(obj.restart_required ~= nil and obj.restart_required == true) then
        self:setStep('restartMining', 'restart mining...')
    else
        self:setStep('end', 'success')
    end
end

function AnthillOS:restartMining()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = 'POST',
        path = '/api/v1/mining/restart',
        headers = {
            ['Authorization']=miner:opt('anthill_token'),
            ['content-type']='application/json; charset=utf-8'
        },
    }

    self:makeBasicHttpReq(request)

    self:setStep('parseRestartMining', 'restart mining result...');
end

function AnthillOS:parseRestartMining(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        self:setStep("end", "failed restart")
        return
    end

    self:setStep('closeSession')
end

function AnthillOS:closeSession()
    local context = self.context
    local miner = context:miner()
    
    local request = {
        method = 'POST',
        path = '/api/v1/lock',
        headers = {
            ['Authorization']='Bearer '..miner:opt('anthill_token')
        }
    }

    self:makeBasicHttpReq(request);

    self:setStep('parseCloseSession')
end

function AnthillOS:parseCloseSession(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        self:setStep("end", "Close session error")
        return
    end

    self:setStep('end', 'success')
end
