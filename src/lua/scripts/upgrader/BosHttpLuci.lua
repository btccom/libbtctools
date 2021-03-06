--[[
MIT License

Copyright (c) 2021 Braiins Systems s.r.o.

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

BosHttpLuci = oo.class({}, ExecutorBase)

function BosHttpLuci:__init(parent, context)
    local miner = context:miner()
    miner:setOpt("settings_pasword_key", "Antminer")

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep("getSession")
    return obj
end

function BosHttpLuci:isKeepSettings()
    if OOLuaHelper.opt("upgrader.keepSettings") == "0" then
        return ""
    end
    return "1"
end

function BosHttpLuci:getSession()
    self:setStep("parseSession", "login...")
    self:makeLuciSessionReq()
end

function BosHttpLuci:parseSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        self:setStep("getNoPswdSession")
    else
        self:setStep("getToken")
    end
end

function BosHttpLuci:getNoPswdSession()
    self:makeLuciSessionReq(true)
    self:setStep("parseNoPswdSession", "login without pwd...")
end

function BosHttpLuci:parseNoPswdSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        return
    end
    self:setStep("getToken")
end

function BosHttpLuci:getToken()
    self:makeLuciTokenReq()
    self:setStep("parseToken", "get token...")
end

function BosHttpLuci:parseToken(httpResponse, stat)
    local token = self:parseLuciTokenReq(httpResponse, stat)
    if (not token) then
        return
    end
    self:setStep("uploadFile")
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
    self:setStep("parseUploadFile", "upload file...")
end

function BosHttpLuci:parseUploadFile(httpResponse, stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        utils.debugInfo("BosHttpLuci:parseUploadFile", "statCode ~= 200")
        self:setStep("end", "perform reboot failed")
        return
    end

    local formatErr =
        "The uploaded image file does not contain a supported format. Make sure that you choose the generic image format for your platform."
    s = string.find(response.body, formatErr)

    if (s ~= nil) then
        utils.debugInfo("BosHttpLuci:parseUploadFile", "format err")
        self:setStep("end", formatErr)
        return
    end

    context:clearFileUpload()
    self:setStep("runUpgrade")
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
    self:setStep("parseRunUpgrade", "upgrading...")
end

function BosHttpLuci:parseRunUpgrade(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        self:setStep("end", "failed: " .. response.statMsg)
        return
    end

    self.context:miner():setOpt("check-reboot-finish-times", "0")

    self:setStep("waitFinish")
    self:disableRetry()
end

function BosHttpLuci:waitFinish()
    self.context:setRequestDelayTimeout(5)
    self.context:setRequestSessionTimeout(5)

    local request = {
        method = "GET",
        path = "/"
    }

    self:makeBasicHttpReq(request)
    self:setStep("runWaitFinish", "wait finish...")
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
