--[[
MIT License

Copyright (c) 2021 Braiins Systems s.r.o.
Copyright (c) 2021 BTC.COM.

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
    miner:setOpt("upgrader.disabled", "true")

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
    self:setStep("parseSession", "login...")
    self:makeLuciSessionReq()
end

function WhatsMinerHttpsLuci:parseSession(httpResponse, stat)
    local miner = self.context:miner()
    local response = self:parseLuciSessionReq(httpResponse, stat)

    if (not response) then
        -- Since https detection is skipped, 
        -- it may not be a WhatsMiner but any device with https service enabled.
        if miner:opt('minerTypeFound') ~= 'true' 
            and not string.match(httpResponse, 'WhatsMiner')
        then
            utils.debugInfo('WhatsMinerHttpsLuci:parseSession', 'Not a WhatsMiner')

            miner:setOpt('httpDetect', 'unknown')
            miner:setTypeStr('unknown')
            miner:setFullTypeStr('')

            self:setStep("end", "unknown device")
            return
        end

        self:setStep("getNoPswdSession")
    else
        self:setStep("getMinerStat")
    end

    -- Set them only after confirming that the device is a WhatsMiner.
    if miner:opt('minerTypeFound') ~= 'true' then
        miner:setFullTypeStr("WhatsMiner")
    end
    miner:setTypeStr("WhatsMinerHttpsLuci")
end

function WhatsMinerHttpsLuci:getNoPswdSession()
    self:setStep("parseNoPswdSession", "login without pwd...")
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
        local model = string.match(response.body, '<td[^>]*>%s*Model%s*</td>%s*<td>%s*(WhatsMiner%s-[^<]-)%s*</td>') or 
                      string.match(response.body, '<td[^>]*>%s*主机型号%s*</td>%s*<td>%s*(WhatsMiner%s-[^<]-)%s*</td>');

        local hardware = string.match(response.body, '<td[^>]*>%s*Hostname%s*</td>%s*<td>%s*([^<]-)%s*</td>') or 
                         string.match(response.body, '<td[^>]*>%s*主机名%s*</td>%s*<td>%s*([^<]-)%s*</td>');

        local firmware = string.match(response.body, '<td[^>]*>%s*Firmware Version%s*</td>%s*<td>%s*([^<]-)%s*</td>') or 
                         string.match(response.body, '<td[^>]*>%s*固件版本%s*</td>%s*<td>%s*([^<]-)%s*</td>');
        
        local software = string.match(response.body, '<td[^>]*>%s*CGMiner%s*Version%s*</td>%s*<td>%s*([^<]-)%s*</td>') or 
                         string.match(response.body, '<td[^>]*>%s*CGMiner%s*版本%s*</td>%s*<td>%s*([^<]-)%s*</td>');

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

    self:setStep("parseMinerNetwork", "get network info...")
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
        local pool1url = string.match(response.body, 'name="cbid%.pools%.default%.pool1url"[^>]-%s+value="%s*([^"]-)%s*"') or ""
        local pool2url = string.match(response.body, 'name="cbid%.pools%.default%.pool2url"[^>]-%s+value="%s*([^"]-)%s*"') or ""
        local pool3url = string.match(response.body, 'name="cbid%.pools%.default%.pool3url"[^>]-%s+value="%s*([^"]-)%s*"') or ""

        local pool1user = string.match(response.body, 'name="cbid%.pools%.default%.pool1user"[^>]-%s+value="%s*([^"]-)%s*"') or ""
        local pool2user = string.match(response.body, 'name="cbid%.pools%.default%.pool2user"[^>]-%s+value="%s*([^"]-)%s*"') or ""
        local pool3user = string.match(response.body, 'name="cbid%.pools%.default%.pool3user"[^>]-%s+value="%s*([^"]-)%s*"') or ""

        local pool1pw = string.match(response.body, 'name="cbid%.pools%.default%.pool1pw"[^>]-%s+value="%s*([^"]-)%s*"') or ""
        local pool2pw = string.match(response.body, 'name="cbid%.pools%.default%.pool2pw"[^>]-%s+value="%s*([^"]-)%s*"') or ""
        local pool3pw = string.match(response.body, 'name="cbid%.pools%.default%.pool3pw"[^>]-%s+value="%s*([^"]-)%s*"') or ""

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

    self:setStep("getPowerMode", "success")
end

function WhatsMinerHttpsLuci:getPowerMode()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/network/cgminer/power",
    }

    self:setStep("parsePowerMode", "read power mode...")
    self:makeSessionedHttpReq(request)
end

function WhatsMinerHttpsLuci:parsePowerMode(httpResponse, stat)
    local context = self.context
    local miner = context:miner()

    local response = self:parseHttpResponse(httpResponse, stat)
    if (response) then
        local overclockOption = { ModeInfo = {} }
        local options = string.gmatch(response.body, 'name="cbid%.cgminer%.default%.miner_type"%s+value="%s*([^"]-)%s*"%s*([^%s]-)%s*/>%s*([^<]-)%s*</label>')
        local optionLocales = {
            ["低"] = "Low",
            ["正常"] = "Normal",
            ["高"] = "High",
        }
        for value, checked, name in options do
            -- Converting localed name to English
            if name and optionLocales[name] then
                name = optionLocales[name]
            end
            if checked and string.match(checked, 'checked="checked"') then
                miner:setOpt('whatsminer.power_mode', value)
            end
            table.insert(overclockOption.ModeInfo, {
                ModeName = name,
                ModeValue = value,
                Level = {
                    [name..' Power Mode'] = value
                }
            })
        end
        miner:setOpt('antminer.overclock_option', utils.jsonEncode(overclockOption))
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
        local unit = string.match(response.body, '<th class="cbi%-section%-table%-cell">%s*([^<]-)Sav%s*</th>') or 'H'
        local mhs5s = string.match(response.body, '<input type="hidden" id="cbid%.table%.4%.mhs5s" value="%s*([^"]-)%s*" />')
        local mhsav = string.match(response.body, '<input type="hidden" id="cbid%.table%.4%.mhsav" value="%s*([^"]-)%s*" />')
        if type(mhs5s) == 'string' then
            miner:setOpt('hashrate_5s', mhs5s..' '..unit..'/s')
        end
        if type(mhsav) == 'string' then
            miner:setOpt('hashrate_avg', mhsav..' '..unit..'/s')
        end

        local fanSpeedIn = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.fanspeedin" value="%s*([^"]-)%s*" />')
        local fanSpeedOut = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.fanspeedout" value="%s*([^"]-)%s*" />')
        local fan = {}
        if fanSpeedIn then
            table.insert(fan, fanSpeedIn)
        end
        if fanSpeedOut then
            table.insert(fan,fanSpeedOut)
        end
        miner:setOpt('fan_speed', string.gsub(table.concat(fan, ' / '), ',', ''))

        local temp1 = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.temp" value="%s*([^"]-)%s*" />')
        local temp2 = string.match(response.body, '<input type="hidden" id="cbid%.table%.2%.temp" value="%s*([^"]-)%s*" />')
        local temp3 = string.match(response.body, '<input type="hidden" id="cbid%.table%.3%.temp" value="%s*([^"]-)%s*" />')
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

        local elapsed = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.elapsed" value="%s*([^"]-)%s*" />')
        if elapsed then
            miner:setOpt('elapsed', elapsed)
        end

        local workmode = string.match(response.body, '<input type="hidden" id="cbid%.table%.1%.workmode" value="%s*([^"]-)%s*" />')
        if workmode then
            miner:setOpt('antminer.overclock_working_mode', workmode)
        end
    end

    self:setStep("end", "success")
end
