AntminerHttpCgi = oo.class({}, ExecutorBase)


function AntminerHttpCgi:__init(parent, context)
    local obj = {
        parent = parent,
        context = context
    }
    obj = oo.rawnew(self, obj)
    obj:setStep('begin')
    return obj
end

function AntminerHttpCgi:isKeepSettings()
    return OOLuaHelper.opt("upgrader.keepSettings") ~= "0"
end

function AntminerHttpCgi:getUpgradePath()
    if (self:isKeepSettings()) then
		return '/cgi-bin/upgrade.cgi'
	else
		return '/cgi-bin/upgrade_clear.cgi'
	end
end

function AntminerHttpCgi:getRebootPath(httpBody)
    if (self:isKeepSettings() or
        string.find(httpBody, 'onload="f_submit_reboot();"') == nil)
    then
		return '/cgi-bin/reboot.cgi'
	else
		return '/cgi-bin/reset_conf.cgi'
	end
end

function AntminerHttpCgi:begin()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()

    local request = {
        method = 'GET',
        host = ip,
        path = '/',
    }

    context:setRequestHost(ip)
    context:setRequestPort("80")
    context:setRequestContent(http.makeRequest(request))
    self:setStep('auth', 'login...')
end

function AntminerHttpCgi:auth(httpResponse, stat)
    local context = self.context

    local response = self:parseHttpResponse(httpResponse, stat, false)
    if (not response) then return end
    if (response.statCode ~= "401") then
        utils.debugInfo('AntminerHttpCgi:auth', 'statCode ~= 401', context, httpResponse, stat)
        self:setStep('end', 'read config failed')
        return
    end

    local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
	if (stepSize <= 0) then
		-- The number of concurrent uploads exceeds the limit, waiting
        context:setRequestDelayTimeout(5)
        self:setStep('waiting')
        return
    end

    self:setStep("upgrade")
end

function AntminerHttpCgi:waiting()
    self:makeAuthRequest()
    self:setStep("auth", "waiting...")
end

function AntminerHttpCgi:upgrade()
    local context = self.context

    local request = http.parseRequest(context:requestContent())
    request.path = self:getUpgradePath()

	-- make the firmware POST data
	local filePath = OOLuaHelper.opt("upgrader.firmwareName")
	local replaceTag = '{file-data}'
	local fields = {
		["datafile"] = {
			["filename"] = filePath,
			["data"] = replaceTag,
			["content-type"] = "application/x-gzip"
		}
	}
	http.setFileUploadRequest(request, fields)
	context:setFileUpload(filePath, replaceTag)

    request.headers['content-length'] = string.len(request.body) + utils.getFileSize(filePath) - string.len(replaceTag)

    self:makeAuthRequest(request)
    self:setStep("doUpgrade", "upgrading...")

    -- Reduce the available step size
    local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
	OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize - 1))
end

function AntminerHttpCgi:doUpgrade(httpResponse, stat)
    local context = self.context

    -- uploading finished, add the step size
	local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
	OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize + 1))

    local response = self:parseHttpResponse(httpResponse, stat)
    if (not response) then return end

	if (response.statCode ~= "200") then
        self:setStep("end", "failed: " .. response.statMsg)
        return
    end

	local result = response.body
	local pos = string.find(result, "\n")
	local first = string.sub(result, 1, 1)
	local rebooting = string.find(result, "Rebooting System ...")

	if (first ~= "<") then
		if (pos ~= nil) then
			result = string.sub(result, 1, pos)
		end
        self:setStep("end", "failed: " .. result)
        return
    end

    if(rebooting == nil) then
        self:setStep("end", "failed: " .. result)
    end

	self:setStep("reboot")
end

function AntminerHttpCgi:reboot()
    local context = self.context

	context:clearFileUpload()
    context:setRequestSessionTimeout(10)

    local request = http.parseRequest(context:requestContent())
	request.method = 'GET'
	request.path = self:getRebootPath(self.response.body)
	request.headers['content-type'] = nil
	request.headers['content-length'] = nil
    request.body = nil
    self:makeAuthRequest(request)

    self:setStep("doReboot", 'rebooting...')
end

function AntminerHttpCgi:doReboot(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)
    if (response and response.statCode == "401") then return end

    self.context:miner():setOpt('check-reboot-finish-times', '0')
    self:setStep("waitFinish")
end

function AntminerHttpCgi:waitFinish()
    self.context:setRequestDelayTimeout(5)
    self.context:setRequestSessionTimeout(5)
    self:makeAuthRequest('/cgi-bin/get_system_info.cgi')
    self:setStep("doWaitFinish", 'wait finish...')
end

function AntminerHttpCgi:doWaitFinish(httpResponse, stat)
    local miner = self.context:miner()

    if (stat == 'success') then
        self:setStep('end', 'upgraded')
        return
    end

    local times = tonumber(miner:opt('check-reboot-finish-times'))
    if (times > 30) then
        self:setStep('end', 'timeout, may succeeded')
        return
    end

    miner:setOpt('check-reboot-finish-times', tostring(times + 1))
    self:setStep('waitFinish', 'not finish')
end
