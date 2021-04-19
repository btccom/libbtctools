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
    if context:miner():opt('minerTypeFound') ~= 'true' then
        miner:setFullTypeStr("WhatsMiner")
    end
    miner:setTypeStr("WhatsMinerHttpsLuci")
    miner:setOpt("settings_pasword_key", "WhatsMiner")

    context:setRequestHost("tls://"..ip)
    context:setRequestPort("443")

    if (miner:opt("httpsPortAvailable") == "true") then
        local timeout = context:requestSessionTimeout() * 5
        if (timeout < 5) then
            timeout = 5
        end
        context:setRequestSessionTimeout(timeout)
    end

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep("getSession")
    return obj
end

function WhatsMinerHttpsLuci:getSession()
    self:setStep("parseSession", "get session...")
    self:makeLuciSessionReq()
end

function WhatsMinerHttpsLuci:parseSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        self:setStep("getNoPswdSession")
    else
        self:setStep("getMinerStat")
    end
end

function WhatsMinerHttpsLuci:getNoPswdSession()
    self:setStep("parseNoPswdSession", "get session...")
    self:makeLuciSessionReq(true)
end

function WhatsMinerHttpsLuci:parseNoPswdSession(httpResponse, stat)
    local response = self:parseLuciSessionReq(httpResponse, stat)
    if (not response) then
        return
    end
    self:setStep("getMinerStat")
end

function WhatsMinerHttpsLuci:getMinerStat()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/status/overview",
    }

    self:setStep("parseMinerStat", "find type...")
    self:makeSessionedHttpReq(request)
end

function WhatsMinerHttpsLuci:parseMinerStat(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (response) then
        local model = string.match(response.body, '<tr><td[^>]*>Model</td><td>%s*(WhatsMiner%s*[^<]*)%s*</td></tr>') or 
                    string.match(response.body, '<tr><td[^>]*>主机型号</td><td>%s*(WhatsMiner%s*[^<]*)%s*</td></tr>');

        local hardware = string.match(response.body, '<tr><td[^>]*>Hostname</td><td>%s*([^<]*)%s*</td></tr>') or 
                        string.match(response.body, '<tr><td[^>]*>主机名</td><td>%s*([^<]*)%s*</td></tr>');

        local firmware = string.match(response.body, '<tr><td[^>]*>Firmware Version</td><td>%s*([^<]*)%s*</td></tr>') or 
                        string.match(response.body, '<tr><td[^>]*>固件版本</td><td>%s*([^<]*)%s*</td></tr>');
        
        local software = string.match(response.body, '<tr><td[^>]*>CGMiner Version</td><td>%s*([^<]*)%s*</td></tr>') or 
                        string.match(response.body, '<tr><td[^>]*>CGMiner%s*版本</td><td>%s*([^<]*)%s*</td></tr>');

        if model ~= nil and model ~= "" then
            context:miner():setFullTypeStr(model)
            miner:setOpt('minerTypeFound', 'true')
        end
        if hardware ~= nil and hardware ~= "" then
            miner:setOpt('hardware_version', hardware)
        end
        if firmware ~= nil and firmware ~= "" then
            miner:setOpt('firmware_version', firmware)
        end
        if software ~= nil and software ~= "" then
            miner:setOpt('software_version', "cgminer "..software)
        end
    end

    self:setStep("getMinerNetwork", "success")
end

function WhatsMinerHttpsLuci:getMinerNetwork()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/network/iface_status/lan",
    }

    self:setStep("parseMinerNetwork", "read network...")
    self:makeSessionedHttpReq(request)
end

function WhatsMinerHttpsLuci:parseMinerNetwork(httpResponse, stat)
    local context = self.context
    local miner = context:miner()
    local obj = self:parseHttpResponseJson(httpResponse, stat)

    if type(obj) == "table" then
        if type(obj[1]) == "table" then
            obj = obj[1]
        end
        if type(obj.proto) == "string" then
            miner:setOpt("network_type", string.upper(obj.proto))
        end
        if type(obj.macaddr) == "string" then
            miner:setOpt("mac_address", obj.macaddr)
        end
    end
    self:setStep("getMinerPool", "success")
end

function WhatsMinerHttpsLuci:getMinerPool()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/network/cgminer",
    }

    self:setStep("parseMinerPool", "find pools...")
    self:makeSessionedHttpReq(request)
end

function WhatsMinerHttpsLuci:parseMinerPool(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (response) then
        local pool1url = string.match(response.body, 'name="cbid%.pools%.default%.pool1url" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""
        local pool2url = string.match(response.body, 'name="cbid%.pools%.default%.pool2url" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""
        local pool3url = string.match(response.body, 'name="cbid%.pools%.default%.pool3url" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""

        local pool1user = string.match(response.body, 'name="cbid%.pools%.default%.pool1user" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""
        local pool2user = string.match(response.body, 'name="cbid%.pools%.default%.pool2user" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""
        local pool3user = string.match(response.body, 'name="cbid%.pools%.default%.pool3user" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""

        local pool1pw = string.match(response.body, 'name="cbid%.pools%.default%.pool1pw" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""
        local pool2pw = string.match(response.body, 'name="cbid%.pools%.default%.pool2pw" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""
        local pool3pw = string.match(response.body, 'name="cbid%.pools%.default%.pool3pw" type="text" class="cbi%-input%-text" value="([^"]*)"') or ""

        local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()
        pool1:setUrl(pool1url)
        pool1:setWorker(pool1user)
        pool1:setPasswd(pool1pw)

        pool2:setUrl(pool2url)
        pool2:setWorker(pool2user)
        pool2:setPasswd(pool2pw)
        
        pool3:setUrl(pool3url)
        pool3:setWorker(pool3user)
        pool3:setPasswd(pool3pw)
    end

    self:setStep("end", "success")

    -- try to find hashrate
    if miner:opt("hashrate_5s") == "" and miner:opt("hashrate_avg") == "" then
        self:setStep('getHashrate')
        return
    end
end

function WhatsMinerHttpsLuci:getHashrate()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/status/cgminerstatus",
    }

    self:setStep("parseHashrate", "read hashrate...")
    self:makeSessionedHttpReq(request)
end

function WhatsMinerHttpsLuci:parseHashrate(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (response) then
        local unit = string.match(response.body, '<th class="cbi%-section%-table%-cell">%s*([^<]+)Sav%s*</th>') or 'H'
        local mhs5s = string.match(response.body, '<input type="hidden" id="cbid%.table%.4%.mhs5s" value="%s*([^"]+)%s*" />')
        local mhsav = string.match(response.body, '<input type="hidden" id="cbid%.table%.4%.mhsav" value="%s*([^"]+)%s*" />')
        if type(mhs5s) == 'string' then
            miner:setOpt('hashrate_5s', mhs5s..' '..unit..'/s')
        end
        if type(mhsav) == 'string' then
            miner:setOpt('hashrate_avg', mhsav..' '..unit..'/s')
        end

        local fanSpeedIn = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.fanspeedin" value="%s*([^"]+)%s*" />')
        local fanSpeedOut = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.fanspeedout" value="%s*([^"]+)%s*" />')
        local fan = {}
        if fanSpeedIn then
            table.insert(fan, fanSpeedIn)
        end
        if fanSpeedOut then
            table.insert(fan,fanSpeedOut)
        end
        miner:setOpt('fan_speed', string.gsub(table.concat(fan, ' / '), ',', ''))

        local temp1 = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.temp" value="%s*([^"]+)%s*" />')
        local temp2 = string.match(response.body, '<input type="hidden" id="cbid%.table%.2%.temp" value="%s*([^"]+)%s*" />')
        local temp3 = string.match(response.body, '<input type="hidden" id="cbid%.table%.3%.temp" value="%s*([^"]+)%s*" />')
        local formatTemp = function(temp)
            temp = string.gsub(temp, ',', '')
            temp = tonumber(temp)
            return string.format('%g', temp)
        end
        local temp = {}
        if temp1 then
            table.insert(temp, formatTemp(temp1))
        end
        if temp2 then
            table.insert(temp, formatTemp(temp2))
        end
        if temp3 then
            table.insert(temp, formatTemp(temp3))
        end
        miner:setOpt('temperature', table.concat(temp, ' / '))

        local elapsed = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.elapsed" value="%s*([^"]+)%s*" />')
        if elapsed then
            miner:setOpt('elapsed', elapsed)
        end

        local workmode = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.workmode" value="%s*([^"]+)%s*" />')
        if workmode then
            miner:setOpt('antminer.overclock_working_mode', workmode)
        end
    end

    self:setStep("end", "success")
end
