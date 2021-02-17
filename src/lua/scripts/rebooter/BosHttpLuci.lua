BosHttpLuci = oo.class({}, ExecutorBase)

function BosHttpLuci:__init(parent, context)
    local miner = context:miner()
    miner:setOpt("settings_pasword_key", "Antminer")

    local obj = {
        parent = parent,
        context = context
    }
    obj = oo.rawnew(self, obj)
    obj:setStep("getSession", "get session..")
    return obj
end

function BosHttpLuci:getSession()
    self:makeLuciSessionReq()
    self:setStep("parseSession", "parse session..")
end

function BosHttpLuci:parseSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        self:setStep("getNoPswdSession", "parse session..")
    else
        self:setStep("getToken", "get luci token..")
    end
end

function BosHttpLuci:getNoPswdSession()
    self:makeLuciSessionReq(true)
    self:setStep("parseNoPswdSession", "parse session..")
end

function BosHttpLuci:parseNoPswdSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        return
    end
    self:setStep("getToken", "get luci token..")
end

function BosHttpLuci:getToken()
    self:makeLuciTokenReq()
    self:setStep("parseToken", "parse luci token..")
end

function BosHttpLuci:parseToken(httpResponse, stat)
    local response = self:parseLuciTokenReq(httpResponse, stat)
    if (not response) then
        return
    end
    self:setStep("callReboot", "call reboot..")
end

function BosHttpLuci:callReboot()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = "POST",
        path = "/cgi-bin/luci/admin/system/reboot/call",
        headers = {
            ["content-type"] = "application/x-www-form-urlencoded"
        },
        body = "token=" .. miner:opt("_luci_token")
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseReboot", "parse reboot")
end

function BosHttpLuci:parseReboot(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local response = self:parseHttpResponse(httpResponse, stat, false)

    if (response.statCode ~= "200") then
        utils.debugInfo("BosHttpLuci:parseReboot", "statCode ~= 200", context, httpResponse, stat)
        self:setStep("end", "perform reboot failed")
        return
    end

    miner:setOpt("check-reboot-finish-times", "0")
    self:setStep("waitFinish")
end

function BosHttpLuci:waitFinish()
    local context = self.context
    context:setRequestDelayTimeout(5)
    context:setRequestSessionTimeout(5)

    local request = {
        method = "GET",
        path = "/"
    }

    self:makeBasicHttpReq(request)
    self:setStep("doWaitFinish", "wait finish..")
end

function BosHttpLuci:doWaitFinish(httpResponse, stat)
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
