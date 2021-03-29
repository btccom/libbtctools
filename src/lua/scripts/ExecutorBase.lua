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
        self:setStep('end', 'login failed')
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
        utils.debugInfo('ExecutorBase:parseSession', 'Bad return code:'..response.statCode)
        self:setStep('end', 'get token failed')
        return
    end

    s,e=string.find(response.body,"token: '")
    token=string.sub(response.body,e+1,e+32)

    if token=='' or token==nil then
        utils.debugInfo('ExecutorBase:parseSession', 'Cant find token in body')
        self:setStep('end', 'get token failed')
        return
    end

    local miner=context:miner()
    miner:setOpt('_luci_token',token)

    return response
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
