local configurator = {}

local utils = require ("utils")
local http = require ("http")

function configurator.doMakeRequest(context)
    local step = context:stepName()
    local ip = context:miner():ip()
    local miner = context:miner()
	local typeStr = miner:typeStr()
    
    context:setCanYield(true)
    
    if (step == "begin") then
        local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/minerConfiguration.cgi',
		}
		
		context:setRequestHost(ip)
		context:setRequestPort("80")
		context:setRequestContent(http.makeRequest(request))
		context:setStepName("auth")
        miner:setStat('login...')
	elseif (step == "getMinerConf") then
		context:setStepName("parseMinerConf")
        miner:setStat('read config...')
    elseif (step == "setMinerConf") then
		context:setStepName("parseResult")
        miner:setStat('update config...')
	else
		context:setStepName("end")
		context:miner():setStat("inner error: unknown step name: " .. step)
    end
end

function configurator.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
    
    context:setCanYield(true)
    miner:setStat(stat)
    
	response = http.parseResponse(response)
    
    if (step == "auth") then
		if (response.statCode == "401") then
			local request = http.parseRequest(context:requestContent())
			local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
            
            if (loginPassword == nil) then
                context:setStepName("end")
                context:miner():setStat("require password")
            else
			    local request = http.parseRequest(context:requestContent())
			    local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
			
                if (err) then
                    context:setStepName("end")
                    context:miner():setStat('failed: ' .. err)
                else
                    context:setStepName("getMinerConf")
                    context:setRequestContent(requestContent)
                end
            end
		else
			context:setStepName("end")
			context:miner():setStat("read config failed")
		end
	elseif (step == "parseMinerConf") then
		if (response.statCode == "401") then
			context:setStepName("end")
			context:miner():setStat("login failed")
		else
            local request = http.parseRequest(context:requestContent())
            local miner = context:miner()
            local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()
            
            -- the default failed order of keys
            local formKeys = {
                "_ant_pool1url",
                "_ant_pool1user",
                "_ant_pool1pw",
                "_ant_pool2url",
                "_ant_pool2user",
                "_ant_pool2pw",
                "_ant_pool3url",
                "_ant_pool3user",
                "_ant_pool3pw",
                "_ant_nobeeper",
                "_ant_notempoverctrl",
                "_ant_fan_customize_switch",
                "_ant_fan_customize_value",
                "_ant_freq",
                "_ant_voltage",
                "_ant_asic_boost",
                "_ant_low_vol_freq",
                "_ant_economic_mode",
                "_ant_multi_level"
            }
            
            -- Auto detecting the order of keys.
            -- It's so important because the miner's cgi script hardcoded the orders when parse params.

            local formKeysJsonStr = string.match(response.body, "data%s*:%s*{(.-)}%s*,%s*[\r\n]")
            formKeysJsonStr = '[' .. string.gsub(formKeysJsonStr, "([a-zA-Z0-9_-]+):[a-zA-Z0-9_-]+", '"%1"') .. ']'
            local newFormKeys, pos, err = utils.jsonDecode (formKeysJsonStr)
            
            if (not err) and (type(newFormKeys) == "table") then
                formKeys = newFormKeys
            else
                print("inexpectant newFormKeys:")
                utils.print(newFormKeys)
            end
            
            -- All known form params from Antminer S4 to S9
            local formParams = {
                _ant_pool1url = pool1:url(),
                _ant_pool1user = pool1:worker(),
                _ant_pool1pw = pool1:passwd(),
                _ant_pool2url = pool2:url(),
                _ant_pool2user = pool2:worker(),
                _ant_pool2pw = pool2:passwd(),
                _ant_pool3url = pool3:url(),
                _ant_pool3user = pool3:worker(),
                _ant_pool3pw = pool3:passwd(),
                _ant_nobeeper = "false",
                _ant_notempoverctrl = "false",
                _ant_fan_customize_switch = "false",
                _ant_fan_customize_value = "",
                _ant_freq = "",
                _ant_voltage = "",

                -- Some models have these configurations
                _ant_asic_boost = "false", -- false: enable ASICBoost; true: disable ASICBoost
                _ant_low_vol_freq = "true", -- true: normal freq; false: low freq
                _ant_economic_mode = "false", -- not use in AntMiner S9
                _ant_multi_level = "1", -- for AntMiner S9 overclocking

                -- Other models have these configurations
                _ant_work_mode = ""
            }
            
            local bmconfJsonStr = string.match(response.body, "ant_data%s*=%s*({.-})%s*;%s*[\r\n]")
            local bmconf, pos, err = utils.jsonDecode (bmconfJsonStr)
            
            -- Origin values of params
            if not (err) then
                if (bmconf['bitmain-nobeeper'] ~= nil) then
                    formParams._ant_nobeeper = bmconf['bitmain-nobeeper']
                end
                
                if (bmconf['bitmain-notempoverctrl'] ~= nil) then
                    formParams._ant_notempoverctrl = bmconf['bitmain-notempoverctrl']
                end
                
                if (bmconf['bitmain-fan-ctrl'] ~= nil) then
                    formParams._ant_fan_customize_switch = bmconf['bitmain-fan-ctrl']
                end

                if (bmconf['bitmain-fan-pwm'] ~= nil) then
                    formParams._ant_fan_customize_value = bmconf['bitmain-fan-pwm']
                end
                
                if (bmconf['bitmain-freq'] ~= nil) then
                    formParams._ant_freq = bmconf['bitmain-freq']
                end
                
                if (bmconf['bitmain-voltage'] ~= nil) then
                    formParams._ant_voltage = bmconf['bitmain-voltage']
                end

                if (bmconf['bitmain-close-asic-boost'] ~= nil) then
                    formParams._ant_asic_boost = bmconf['bitmain-close-asic-boost']
                end
                
                if (bmconf['bitmain-close-low-vol-freq'] ~= nil) then
                    formParams._ant_low_vol_freq = bmconf['bitmain-close-low-vol-freq']
                end
                
                if (bmconf['bitmain-economic-mode'] ~= nil) then
                    formParams._ant_economic_mode = bmconf['bitmain-economic-mode']
                end

                if (bmconf['bitmain-low-vol'] ~= nil) then
                    formParams._ant_multi_level = bmconf['bitmain-low-vol']
                end

                if (bmconf['bitmain-work-mode'] ~= nil) then
                    formParams._ant_work_mode = bmconf['bitmain-work-mode']
                end
            end

            -- Custom values of params
            if (miner:opt("config.antminer.asicBoost") ~= "") then
                if (miner:opt("config.antminer.asicBoost") == "true") then
                    formParams._ant_asic_boost = "false"
                else
                    formParams._ant_asic_boost = "true"
                end
            end

            if (miner:opt("config.antminer.lowPowerMode") ~= "") then
                if (miner:opt("config.antminer.lowPowerMode") == "true") then
                    formParams._ant_low_vol_freq = "false"
                else
                    formParams._ant_low_vol_freq = "true"
                end
            end

            if (miner:opt("config.antminer.economicMode") ~= "") then
                formParams._ant_economic_mode = miner:opt("config.antminer.economicMode")
            end

            if (miner:opt("config.antminer.overclockWorkingMode") ~= "") then
                formParams._ant_multi_level = miner:opt("config.antminer.overclockWorkingMode")
                
                if (miner:opt("antminer.overclock_to_freq") == "true") then
                    formParams._ant_freq = formParams._ant_multi_level
                end

                if (miner:opt("antminer.overclock_to_work_mode") == "true") then
                    formParams._ant_work_mode = formParams._ant_multi_level
                end
            end
            
            request.method = 'POST';
            request.path = '/cgi-bin/set_miner_conf.cgi';
            request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
            request.body = utils.makeUrlQueryString(formParams, formKeys)
            
            local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
            
            if (loginPassword == nil) then
                context:setStepName("end")
                context:miner():setStat("require password")
            else
                local requestContent, err = http.makeAuthRequest(request, response, loginPassword.userName, loginPassword.password)
        
			    if (err) then
			    	context:setStepName("end")
			    	context:miner():setStat('failed: ' .. err)
			    else
			    	context:setStepName("setMinerConf")
			    	context:setRequestContent(requestContent)
                end
            end
		end
    elseif (step == "parseResult") then
        if (response.statCode == "401") then
			context:setStepName("end")
			context:miner():setStat("login failed")
		else
            context:setStepName("end")
            context:miner():setStat(utils.trimAll(response.body))
            if (context:miner():opt("config.antminer.overclockWorkingMode") ~= "") then
                context:miner():setStat(context:miner():stat().." (OC√)")
            end
        end
	else
		context:setStepName("end")
		context:miner():setStat("inner error: unknown step name: " .. step)
    end
end

return configurator
