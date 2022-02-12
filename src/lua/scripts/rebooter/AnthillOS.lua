--[[
MIT License

Copyright (c) 2022 Anthill Farm

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]


AnthillOS = oo.class({}, ExecutorBase)

function AnthillOS:__init(parent, context)
    local obj = ExecutorBase.__init(self, parent, context)

    obj:setStep("getSession")

    return obj
end

function AnthillOS:getSession()
    self:setStep("parseSession", "login...")
    self:makeAnthillSessionReq();
end

function AnthillOS:parseSession(httpResponse, stat)
    local response = self:parseAnthillSessionReq(httpResponse, stat)

    if (not response) then
        return
    end

    self:setStep('callReboot')
end

function AnthillOS:callReboot()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = 'POST',
        path = '/api/v1/system/reboot',
        headers = {
            ['Authorization']='Bearer '..miner:opt('anthill_token'),
            ['content-type']='application/json; charset=utf-8'
        }
    }

    self:makeBasicHttpReq(request)

    self:setStep('parseReboot', 'parse reboot...')
end

function AnthillOS:parseReboot(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local response = self:parseHttpResponse(httpResponse, stat, false)

    if (response.statCode ~= "200") then
        self:setStep("end", "perform reboot failed")
        return
    end

    miner:setOpt("check-reboot-finish-times", "0")
    self:setStep("waitFinish")
    self:disableRetry()
end

function AnthillOS:waitFinish()
    local context = self.context
    context:setRequestDelayTimeout(5)
    context:setRequestSessionTimeout(5)

    local request = {
        method = "GET",
        path = "/api/v1/status"
    }

    self:makeBasicHttpReq(request)
    self:setStep("doWaitFinish", "wait finish...")
end

function AnthillOS:doWaitFinish(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    if (stat == "success") then
        self:setStep("end", "rebooted")
        return
    end

    local times = tonumber(miner:opt("check-reboot-finish-times"))

    if (times > 30) then
        self:setStep("end", "timeout, may succeeded")
        return
    end

    miner:setOpt("check-reboot-finish-times", tostring(times + 1))
    self:setStep("waitFinish", "not finish")
end
