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
    local miner = context:miner()

    local obj = ExecutorBase.__init(self, parent, context)

    obj:setStep('getSession')

    return obj
end

function AnthillOS:isKeepSettings()
    if OOLuaHelper.opt("upgrader.keepSettings") == "0" then
        return "false"
    end
    return "true"
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

    self:setStep('uploadFile')
end

function AnthillOS:setFormDataRequest(request, fields)
    local boundary = "-----------------------BTCTools" .. tostring(os.time())
    request.headers['content-type'] = 'multipart/form-data; boundary=' .. boundary
    request.body = ''
    for name, item in pairs(fields) do
		request.body = request.body .. "--" .. boundary .. "\r\n"
		request.body = request.body .. 'Content-Disposition: form-data; name="' .. name .. '"'
		
		if (item['filename'] ~= nil) then
			request.body = request.body .. '; filename="' .. item['filename'] .. '"'
		end

		if (item['content-type'] ~= nil) then
			request.body = request.body .. "\r\nContent-Type: " .. item['content-type']
		end

		request.body = request.body .. "\r\n\r\n" .. item['data'] .. "\r\n"
	end

	request.body = request.body .. "--" .. boundary .. "--\r\n"
end

function AnthillOS:uploadFile()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = "POST",
        path = "/api/v1/firmware/update",
        headers = {
            ["Authorization"]="Bearer "..miner:opt("anthill_token")
        }
    }

    local filePath = OOLuaHelper.opt("upgrader.firmwareName")
    local replaceTag = "{file-data}"

    local fields = {
        ["keep_settings"] = {
            ["data"] = self:isKeepSettings()
        },
        ["file"] = {
            ["filename"] = filePath,
            ["data"] = replaceTag,
            ["content-type"] = "text/plain"
        }
    }

    self:setFormDataRequest(request, fields)
    context:setFileUpload(filePath, replaceTag)
    request.headers["content-length"] = string.len(request.body) + utils.getFileSize(filePath) - string.len(replaceTag)

    self:makeBasicHttpReq(request)
    self:setStep("doUpgrade", "upload file...")

    local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
    OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize - 1))
end

function AnthillOS:doUpgrade(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local response = self:parseHttpResponse(httpResponse, stat)

    -- uploading finished, add the step size
	local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
	OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize + 1))

    if (response.statCode ~= "200") then
        self:setStep("end", "perform reboot failed")
        return
    end

    if (response.statCode ~= "200") then
        self:setStep("end", "failed: " .. response.statMsg)
        return
    end

    local result = utils.trim(response.body)
    local first = string.sub(result, 1, 1)

    if first == '{' then
        local obj, pos, err = utils.jsonDecode(result)

        if err or not obj or not obj.after then
            err = err or 'unknown JSON result'
            utils.debugInfo('AnthillOS:doUpgrade', err)
            self:setStep("end", err .. ': ' .. result)
            return
        end
    end

    miner:setOpt("check-reboot-finish-times", "0")
    self:setStep("waitFinish")
    self:disableRetry()
end

function AnthillOS:waitFinish()
    local context = self.context
    context:clearFileUpload()
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
        self:setStep("end", "upgraded")
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
