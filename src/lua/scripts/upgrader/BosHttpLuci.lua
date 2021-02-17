BosHttpLuci = oo.class({}, ExecutorBase)

function BosHttpLuci:__init(parent, context)
    local miner = context:miner()
    miner:setOpt("settings_pasword_key", "Antminer")

    local obj = {
        parent = parent,
        context = context
    }
    obj = oo.rawnew(self, obj)
    obj:setStep("getSession", "get session")
    return obj
end

function BosHttpLuci:isKeepSettings()
    if OOLuaHelper.opt("upgrader.keepSettings") == "0" then
        return ""
    end
    return "1"
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
    self:setStep("parseToken", "get luci token..")
end

function BosHttpLuci:parseToken(httpResponse, stat)
    local response = self:parseLuciTokenReq(httpResponse, stat)
    if (not response) then
        return
    end
    self:setStep("uploadFile", "parse token..")
end

function BosHttpLuci:setFormDataRequest(request, fields)
    local boundary = "-----------------------BTCTools" .. tostring(os.time())
    if request.headers == nil then
        request.headers = {}
    end
    request.headers["content-type"] = "multipart/form-data; boundary=" .. boundary
    request.body = ""
    for name, item in pairs(fields) do
        request.body = request.body .. "\r\n--" .. boundary .. "\r\n"
        request.body = request.body .. 'Content-Disposition: form-data; name="' .. name .. '"'

        if (item["filename"] ~= nil) then
            request.body = request.body .. '; filename="' .. item["filename"] .. '"'
        end

        if (item["content-type"] ~= nil) then
            request.body = request.body .. "\r\nContent-Type: " .. item["content-type"]
        end

        request.body = request.body .. "\r\n\r\n" .. item["data"] .. ""
    end
    request.body = request.body .. "\r\n--" .. boundary .. "--\r\n"
end

function BosHttpLuci:uploadFile()
    local context = self.context
    local miner = context:miner()
    local request = {
        method = "POST",
        path = "/cgi-bin/luci/admin/system/flashops/sysupgrade",
        headers = {}
    }

    local filePath = OOLuaHelper.opt("upgrader.firmwareName")
    local replaceTag = "{file-data}"

    local fields = {
        ["image"] = {
            ["filename"] = filePath,
            ["data"] = replaceTag,
            ["content-type"] = "application/octet-stream"
        },
        ["token"] = {
            ["data"] = miner:opt("_luci_token")
        },
        ["keep"] = {
            ["data"] = self:isKeepSettings()
        },
        ["step"] = {
            ["data"] = "1"
        }
    }

    self:setFormDataRequest(request, fields)
    context:setFileUpload(filePath, replaceTag)
    request.headers["content-length"] = string.len(request.body) + utils.getFileSize(filePath) - string.len(replaceTag)

    local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
    OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize - 1))

    self:makeSessionedHttpReq(request)
    self:setStep("parseUploadFile", "upload file..")
end

function BosHttpLuci:parseUploadFile(httpResponse, stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        utils.debugInfo("BosHttpLuci:parseUploadFile", "statCode ~= 200", context, httpResponse, stat)
        self:setStep("end", "perform reboot failed")
        return
    end

    local formatErr =
        "The uploaded image file does not contain a supported format. Make sure that you choose the generic image format for your platform."
    s = string.find(response.body, formatErr)

    if (s ~= nil) then
        utils.debugInfo("BosHttpLuci:parseUploadFile", "format err", context, httpResponse, stat)
        self:setStep("end", formatErr)
        return
    end

    context:clearFileUpload()
    self:setStep("runUpgrade", "run upgrade..")
end

function BosHttpLuci:runUpgrade()
    local context = self.context
    local miner = context:miner()
    local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
    OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize + 1))

    local request = {
        method = "POST",
        path = "/cgi-bin/luci/admin/system/flashops/sysupgrade"
    }

    local fields = {
        ["token"] = {
            ["data"] = miner:opt("_luci_token")
        },
        ["keep"] = {
            ["data"] = self:isKeepSettings()
        },
        ["step"] = {
            ["data"] = "2"
        }
    }

    self:setFormDataRequest(request, fields)
    self:makeSessionedHttpReq(request)
    self:setStep("parseRunUpgrade", "parse upgrade..")
end

function BosHttpLuci:parseRunUpgrade(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        self:setStep("end", "failed: " .. response.statMsg)
        return
    end

    self.context:miner():setOpt("check-reboot-finish-times", "0")

    self:setStep("waitFinish")
end

function BosHttpLuci:waitFinish()
    self.context:setRequestDelayTimeout(5)
    self.context:setRequestSessionTimeout(5)

    local request = {
        method = "GET",
        path = "/"
    }

    self:makeBasicHttpReq(request)
    self:setStep("runWaitFinish", "wait finish..")
end

function BosHttpLuci:runWaitFinish(httpResponse, stat)
    local miner = self.context:miner()

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
