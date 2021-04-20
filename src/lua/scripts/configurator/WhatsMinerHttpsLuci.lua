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

WhatsMinerHttpsLuci = oo.class({}, ExecutorBase)

function WhatsMinerHttpsLuci:__init(parent, context)
    local miner = context:miner()
    local ip = miner:ip()
    miner:setOpt("settings_pasword_key", "WhatsMiner")

    context:setRequestHost("tls://"..ip)
    context:setRequestPort("443")

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep("getSession")
    return obj
end

function WhatsMinerHttpsLuci:getSession()
    self:makeLuciSessionReq()
    self:setStep("parseSession", "login...")
end

function WhatsMinerHttpsLuci:parseSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        self:setStep("getNoPswdSession")
    else
        self:setStep("getToken")
    end
end

function WhatsMinerHttpsLuci:getNoPswdSession()
    self:makeLuciSessionReq(true)
    self:setStep("parseNoPswdSession", "login without pwd...")
end

function WhatsMinerHttpsLuci:parseNoPswdSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        return
    end
    self:setStep("getToken")
end

function WhatsMinerHttpsLuci:getToken()
    self:makeLuciConfigTokenReq()
    self:setStep("parseToken", "get token...")
end

function WhatsMinerHttpsLuci:makeLuciConfigTokenReq()
    local request = {
        method = 'GET',
        path = '/cgi-bin/luci/admin/network/cgminer',
    }
    self:makeSessionedHttpReq(request)
end

function WhatsMinerHttpsLuci:parseToken(httpResponse, stat)
    local token = self:parseLuciConfigTokenReq(httpResponse, stat)
    if (not token) then
        return
    end
    self:setStep("setMinerConf")
end

function WhatsMinerHttpsLuci:parseLuciConfigTokenReq(httpResponse, stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat,false)
    if response.statCode~='200' then
        utils.debugInfo('WhatsMinerHttpsLuci:parseLuciConfigTokenReq', 'Bad return code:'..response.statCode)
        self:setStep('end', 'get token failed')
        return
    end

    local token = string.match(response.body, 'name="token"%s*value="%s*([^"]-)%s*"')

    if token == '' or token == nil then
        utils.debugInfo('WhatsMinerHttpsLuci:parseLuciConfigTokenReq', 'Cant find token in body')
        self:setStep('end', 'get token failed')
        return
    end

    local miner=context:miner()
    miner:setOpt('_luci_token', token)

    -- find Coin Type
    self._default_coin_type = string.match(response.body, '<option%s*id="cbid%.pools%.default%.coin_type[^"]-"%s*value="%s*([^"]-)%s*"[^>]-selected="selected">')

    return token
end

function WhatsMinerHttpsLuci:setMinerConf()
    local context = self.context
    local miner = context:miner()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    local formParams = {
        ["token"] = miner:opt("_luci_token"),
        ["cbi.submit"] = "1",
        ["cbi.apply"] = "1",
        ["cbid.pools.default.coin_type"] = self._default_coin_type or "",
        ["cbid.pools.default.pool1url"]  = pool1:url(),
        ["cbid.pools.default.pool1user"] = pool1:worker(),
        ["cbid.pools.default.pool1pw"]   = pool1:passwd(),
        ["cbid.pools.default.pool2url"]  = pool2:url(),
        ["cbid.pools.default.pool2user"] = pool2:worker(),
        ["cbid.pools.default.pool2pw"]   = pool2:passwd(),
        ["cbid.pools.default.pool3url"]  = pool3:url(),
        ["cbid.pools.default.pool3user"] = pool3:worker(),
        ["cbid.pools.default.pool3pw"]   = pool3:passwd(),
    }

    local request = {
        method = "POST",
        path = "/cgi-bin/luci/admin/network/cgminer",
        headers = {
            ["content-type"] = "application/x-www-form-urlencoded"
        },
        body = utils.makeUrlQueryString(formParams)
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseSetMinerConf", "update config...")
end

function WhatsMinerHttpsLuci:parseSetMinerConf(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local response = self:parseHttpResponse(httpResponse, stat, false)

    if (response.statCode ~= "200") then
        utils.debugInfo("WhatsMinerHttpsLuci:parseSetMinerConf", "statCode ~= 200")
        self:setStep("end", "failed to update config: "..httpResponse)
        return
    end

    if (miner:opt("config.antminer.overclockWorkingMode") ~= "") then

        local workingModeName = miner:opt("config.antminer.overclockWorkingMode")
        local workingMode = nil

        local options, _, optionErr = utils.jsonDecode (miner:opt('antminer.overclock_option'))
        if not (optionErr) then
            for _, mode in ipairs(options.ModeInfo) do
                if mode.ModeName == workingModeName then
                    workingMode = mode
                    break
                end
            end
        end

        if workingMode ~= nil and workingMode.ModeValue ~= miner:opt('whatsminer.power_mode') then
            miner:setOpt('whatsminer.new_power_mode', workingMode.ModeValue)
            self:setStep("setPowerMode")
            return
        end
    end

    self:setStep("restartCGMiner")
end

function WhatsMinerHttpsLuci:setPowerMode()
    local context = self.context
    local miner = context:miner()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    local formParams = {
        ["token"] = miner:opt("_luci_token"),
        ["cbi.submit"] = "1",
        ["cbi.apply"] = "1",
        ["cbid.cgminer.default.miner_type"] = miner:opt('whatsminer.new_power_mode'),
    }

    local request = {
        method = "POST",
        path = "/cgi-bin/luci/admin/network/cgminer/power",
        headers = {
            ["content-type"] = "application/x-www-form-urlencoded"
        },
        body = utils.makeUrlQueryString(formParams)
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseSetPowerMode", "set power mode...")
end

function WhatsMinerHttpsLuci:parseSetPowerMode(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local response = self:parseHttpResponse(httpResponse, stat, false)

    if (response.statCode ~= "200") then
        utils.debugInfo("WhatsMinerHttpsLuci:parseSetPowerMode", "statCode ~= 200")
        self:setStep("restartCGMiner", "set power mode failed: "..httpResponse)
        return
    end

    self:setStep("restartCGMiner")
end

function WhatsMinerHttpsLuci:restartCGMiner()
    local request = {
        method = 'GET',
        path = '/cgi-bin/luci/admin/status/cgminerstatus/restart',
    }
    self:makeSessionedHttpReq(request)
    self:setStep("parseRestartCGMiner", "restart cgminer...")
end

function WhatsMinerHttpsLuci:parseRestartCGMiner(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local response = self:parseHttpResponse(httpResponse, stat, false)

    if (response.statCode ~= "302") then
        utils.debugInfo("WhatsMinerHttpsLuci:parseRestartCGMiner", "statCode ~= 200")
        self:setStep("end", "failed to restart cgminer: "..httpResponse)
        return
    end

    self:setStep("end", "ok")
end
