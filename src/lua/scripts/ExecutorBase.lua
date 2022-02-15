ExecutorBase = oo.class()

function ExecutorBase:__init(parent, context)
    local obj = {
        parent = parent,
        context = context
    }
    obj = oo.rawnew(self, obj)
    obj:initRetry()
    obj:setStep('begin')
    return obj
end

function ExecutorBase:initRetry()
    local autoRetryTimes = tonumber(OOLuaHelper.opt("network.autoRetryTimes")) or 2
    self.autoRetry = {
        enable = true,
        inRetry = false, -- Is it currently retrying
        limit = autoRetryTimes, -- Maximum number of retries
        times = 0, -- Number of retries at current
        delay = 1, -- Wait N seconds and try again
        originDelay = nil, -- Delay value before retry
        originStepName = nil -- stepName value before retry
    }
end

function ExecutorBase:stopRetry()
    self.context:setRequestDelayTimeout(self.autoRetry.originDelay)
    self:initRetry()
    utils.debugOutput('autoRetry stopped')
end

function ExecutorBase:enableRetry()
    self.autoRetry.enable = true
    utils.debugOutput('autoRetry enabled')
end

function ExecutorBase:disableRetry()
    self.autoRetry.enable = false
    utils.debugOutput('autoRetry disabled')
end

function ExecutorBase:inRetry()
    return self.autoRetry.inRetry
end

function ExecutorBase:retry()
    if not self.autoRetry.enable or self.autoRetry.times >= self.autoRetry.limit then
        return false
    end
    self.autoRetry.originDelay = self.context:requestDelayTimeout()
    self.autoRetry.originStepName = self.context:stepName()
    self.autoRetry.times = self.autoRetry.times + 1
    self.autoRetry.inRetry = true
    self.context:setRequestDelayTimeout(self.autoRetry.delay)
    self:setStep('doRetry', 'retry times: '..self.autoRetry.times)
    return true
end

function ExecutorBase:doRetry()
    print("originStepName:", self.autoRetry.originStepName)
    self:setStep(self.autoRetry.originStepName, 'retry times: '..self.autoRetry.times)
    utils.debugOutput('ExecutorBase:doRetry', 'retry times: '..self.autoRetry.times)
end

function ExecutorBase:setStep(name, stat)
    self.nextStep = self[name]
    self.context:setStepName(name)
    if stat then
        self.context:miner():setStat(stat)
        self.context:setCanYield(true)
    end
end

function ExecutorBase:exec(...)
    if type(self.nextStep) ~= 'function' then
        error('unknown step name: '..self.context:stepName())
    end
    return self:nextStep(...)
end

function ExecutorBase:parseHttpResponse(httpResponse, stat, loginCheck)
    self.httpResponse = httpResponse
    self.stat = stat

    local ok, response = pcall(http.parseResponse, httpResponse)
    if not ok then
        utils.debugInfo('parseHttpResponse', response)
        self:setStep('end', 'failed: ' .. self.context:stepName() .. ': ' .. response)
        return
    end
    if (loginCheck ~= false and response.statCode == "401") then
        utils.debugInfo('parseHttpResponse', 'login failed')
        self:setStep("end", 'login failed')
        return
    end

    self.response = response
    return response
end

function ExecutorBase:makeAuthRequest(path)
    local context = self.context
    local miner = context:miner()
    local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())

    if (loginPassword == nil) then
        self:setStep('end', 'require password')
        return
    end

    local request
    if type(path) == 'table' then
        request = path
    else
        request = http.parseRequest(context:requestContent())
        if type(path) == 'string' then
            request.path = path
        end
    end
    local requestContent, err = http.makeAuthRequest(request, self.response, loginPassword.userName, loginPassword.password)

    if (err) then
        utils.debugInfo('makeAuthRequest', err)
        self:setStep('end', 'failed: ' .. err)
        return
    end

    context:setRequestContent(requestContent)
end

function ExecutorBase:makeBasicHttpReq(request)
    local context = self.context
    local miner = context:miner()
    local ip=miner:ip()

    request.ip=ip

    context:setRequestHost(ip)
    context:setRequestPort('80')
    context:setRequestContent(http.makeRequest(request))
end

function ExecutorBase:makeSessionedHttpReq(request)
    if request['headers']==nil then
        request['headers']={}
    end
    local context = self.context
    local miner=context:miner()
    request['headers']['cookie']=miner:opt('_luci_session')
    self:makeBasicHttpReq(request)
end

function ExecutorBase:makeLuciSessionReq(noPswd)
    local context = self.context
    local miner = context:miner()

    local pswd_key=miner:opt('settings_pasword_key')
    local loginPassword = utils.getMinerLoginPassword(pswd_key)

    if loginPassword==nil then
        utils.debugInfo('ExecutorBase:makeLuciSessionReq', 'Password not found for key '..pswd_key)
        self:setStep('end', 'require password')
        return
    end

    local userName=loginPassword.userName
    local password=loginPassword.password

    if noPswd==true then
        password=''
    end
    
    local request = {
        method = 'POST',
        path = '/cgi-bin/luci',
        headers={
            ['content-type']='application/x-www-form-urlencoded'
        },
        body='luci_username='..userName..'&luci_password='..password,
    }

    self:makeBasicHttpReq(request)
end

function ExecutorBase:parseLuciSessionReq(httpResponse, stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat, false)

    if not response then
        utils.debugInfo('ExecutorBase:parseSession', 'No response from miner')
        self:setStep('end', stat)
        return
    end

    if response.statCode~='302' then
        utils.debugInfo('ExecutorBase:parseSession', 'Bad return code:' .. response.statCode)
        self:setStep('end', 'login failed')
        return
    end

    if response['headers']==nil or response['headers']['set-cookie']==nil then
        utils.debugInfo('ExecutorBase:parseSession', 'Missing set-cookie header')
        self:setStep('end', 'login failed')
        return
    end

    local miner=context:miner()
    miner:setOpt('_luci_session',response['headers']['set-cookie'][1])

    return response
end

function ExecutorBase:makeLuciTokenReq()
    local request = {
        method = 'GET',
        path = '/cgi-bin/luci/admin/system/reboot',
    }
    self:makeSessionedHttpReq(request)
end

function ExecutorBase:parseLuciTokenReq(httpResponse, stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat,false)
    if response.statCode~='200' then
        utils.debugInfo('ExecutorBase:parseLuciTokenReq', 'Bad return code:'..response.statCode)
        self:setStep('end', 'get token failed')
        return
    end

    local token = string.match(response.body, "token:%s*'([^']-)'")
               or string.match(response.body, 'token:%s*"([^"]-)"')

    if token=='' or token==nil then
        utils.debugInfo('ExecutorBase:parseLuciTokenReq', 'Cant find token in body')
        self:setStep('end', 'get token failed')
        return
    end

    local miner=context:miner()
    miner:setOpt('_luci_token',token)

    return token
end

function ExecutorBase:parseHttpResponseJson(httpResponse,stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat,false)
    if (not response) then return end
    local obj,pos,err = utils.jsonDecode(response.body)
    if err then
        utils.debugInfo('parseHttpResponseJson', err)
        self:setStep('end', 'failed :' .. err)
        return
    end
    return obj
end

function ExecutorBase:makeAnthillSessionReq()
    local context = self.context
    local miner = context:miner()

    local loginPassword = utils.getMinerLoginPassword('AnthillOS')

    if (loginPassword == nil) then
        loginPassword = utils.getMinerLoginPassword('VnishOS')
    end

    if (loginPassword == nil) then
        self:setStep('end', 'no password specified')
        return
    end

    if (loginPassword.password == nil) then
        self:setStep('end', 'require password')
        return
    end

    local request = {
        method = 'POST',
        path = '/api/v1/unlock',
        headers = {
            ['content-type']='application/json; charset=utf-8'
        },
        body = '{"pw": "'..loginPassword.password..'"}'
    }

    self:makeBasicHttpReq(request);
end

function ExecutorBase:parseAnthillSessionReq(httpResponse, stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat)

    if not response then
        utils.debugInfo('ExecutorBase:parseSession', 'No response from miner')
        self:setStep('end', stat)
        return
    end

    if response.statCode ~= '200' then
        utils.debugInfo('ExecutorBase:parseSession', 'Bad return code' .. response.statCode)
        self:setStep('end', 'login failed')
        return
    end

    local miner = context:miner()
    local obj = utils.jsonDecode(response.body)

    if (type(obj) ~= 'table') then
        utils.debugInfo('ExecutorBase:parseSession', 'invalid response format')
        self:setStep('end', 'invalid response format')
        return
    end

    miner:setOpt('anthill_token', obj.token)

    return response
end
