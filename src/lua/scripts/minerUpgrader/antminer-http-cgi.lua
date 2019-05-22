local configurator = {}

local utils = require ("utils")
local http = require ("http")

local isKeepSettings = function()
	return OOLuaHelper.opt("upgrader.keepSettings") ~= "0"
end

local getUpgradePath = function()
	if (isKeepSettings()) then
		return '/cgi-bin/upgrade.cgi'
	else
		return '/cgi-bin/upgrade_clear.cgi'
	end
end

local getRebootPath = function(httpBody)
	if (isKeepSettings() or string.find(httpBody, 'onload="f_submit_reboot();"') == nil) then
		return '/cgi-bin/reboot.cgi'
	else
		return '/cgi-bin/reset_conf.cgi'
	end
end

function configurator.doMakeRequest(context)
    local step = context:stepName()
    local miner = context:miner()
    local ip = miner:ip()
	local typeStr = miner:typeStr()
    
    context:setCanYield(true)

	if (step == "begin") then
		-- try a GET first to avoid resending the large firmware data
        local request = {
			method = 'GET',
			host = ip,
			path = getUpgradePath(),
		}
		
		context:setRequestHost(ip)
		context:setRequestPort("80")
		context:setRequestContent(http.makeRequest(request))
		context:setStepName("auth")
		miner:setStat('login...')
	elseif (step == "waiting") then
		context:setStepName("auth")
		miner:setStat("waiting...")
	elseif (step == "upgrade") then
		context:setStepName("doUpgrade")
		miner:setStat('upgrading...')
	elseif (step == "reboot") then
		context:setStepName("doReboot")
		miner:setStat('rebooting...')
    elseif (step == "waitFinish") then
		context:setStepName("doWaitFinish")
        miner:setStat('wait finish...')
	else
		context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

function configurator.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
    
    context:setCanYield(true)
    miner:setStat(stat)
    
    if (step ~= "doWaitFinish") then
        response = http.parseResponse(response)
    end
    
    if (step == "auth") then
		if (response.statCode == "401") then
			local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
            
            if (loginPassword == nil) then
                context:setStepName("end")
                miner:setStat("require password")
			else
				local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
				if (stepSize <= 0) then
					-- The number of concurrent uploads exceeds the limit, waiting
					context:setRequestDelayTimeout(5)
					context:setStepName("waiting")
				else
					-- Reduce the available step size
					OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize - 1))

					local request = http.parseRequest(context:requestContent())

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

					local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
					
					if (err) then
						context:setStepName("end")
						miner:setStat('failed: ' .. err)
					else
						context:setStepName("upgrade")
						context:setRequestContent(requestContent)
					end
				end
			end
		else
			context:setStepName("end")
			miner:setStat("read config failed")
		end
	elseif (step == "doUpgrade") then
		-- uploading finished, add the step size
		local stepSize = tonumber(OOLuaHelper.opt("upgrader.sendFirmwareStepSize"))
		OOLuaHelper.setOpt("upgrader.sendFirmwareStepSize", tostring(stepSize + 1))

		if (response.statCode == "401") then
			context:setStepName("end")
			miner:setStat("login failed")
		elseif (response.statCode ~= "200") then
			context:setStepName("end")
			miner:setStat("failed: " .. response.statMsg)
		else
			local result = response.body
			local pos = string.find(result, "\n")
			local first = string.sub(result, 1, 1)
			local rebooting = string.find(result, "Rebooting System ...")

			if (err) then
				context:setStepName("end")
				miner:setStat('failed: ' .. err)
			elseif (first ~= "<") then
				if (pos ~= nil) then
					result = string.sub(result, 1, pos)
				end
				context:setStepName("end")
				miner:setStat('failed: '.. result)
			elseif(rebooting == nil) then
				context:setStepName("end")
				miner:setStat('failed: ' .. result)
			else
				context:setStepName("reboot")
				local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
				local request = http.parseRequest(context:requestContent())
				request.method = 'GET'
				request.path = getRebootPath(response.body)
				request.headers['content-type'] = nil
				request.headers['content-length'] = nil
				request.body = nil
				local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
				context:setRequestContent(requestContent)
				context:setRequestSessionTimeout(10)
				context:clearFileUpload()
			end
		end
	elseif (step == "doReboot") then
		local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/get_system_info.cgi',
		}
		context:setStepName("waitFinish")
		context:setRequestContent(http.makeRequest(request))
		context:setRequestDelayTimeout(5)
		context:setRequestSessionTimeout(5)
		miner:setOpt('check-upgrade-finish-times', '0')
        
    elseif (step == "doWaitFinish") then
    
        if (stat == "success") then
            context:setStepName("end")
			miner:setStat("upgraded")
        else
			local times = tonumber(miner:opt('check-upgrade-finish-times'))
			
			if (isKeepSettings()) then
				if (times > 10) then
					miner:setStat("wait finish timeout")
					context:setStepName("end")
				else
					miner:setOpt('check-upgrade-finish-times', tostring(times + 1))
					miner:setStat("not finish")
					context:setStepName("waitFinish")
				end
			else
				context:setStepName("end")
				miner:setStat("upgraded")
			end
        end
	else
		context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

return configurator
