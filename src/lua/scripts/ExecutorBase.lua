ExecutorBase = oo.class()

function ExecutorBase:__init(parent, context)
    local obj = {
        parent = parent,
        context = context
    }
    obj = oo.rawnew(self, obj)
    obj:setStep('begin')
    return obj
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
        utils.debugInfo('parseHttpResponse', response, self.context, httpResponse, stat)
        self:setStep('end', 'failed: ' .. self.context:stepName() .. ': ' .. response)
        return
    end
    if (loginCheck ~= false and response.statCode == "401") then
        utils.debugInfo('parseHttpResponse', 'login failed', self.context, httpResponse, stat)
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
        utils.debugInfo('makeAuthRequest', err, context, self.httpResponse, self.stat)
        self:setStep('end', 'failed: ' .. err)
        return
    end

    context:setRequestContent(requestContent)
end
