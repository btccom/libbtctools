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
    miner:setFullTypeStr("Antminer (BOS)")
    miner:setTypeStr("BosHttpLuci")
    miner:setOpt("settings_pasword_key", "Antminer")

    if (miner:opt("httpPortAvailable") == "true") then
        local timeout = context:requestSessionTimeout() * 5
        if (timeout < 5) then
            timeout = 5
        end
        context:setRequestSessionTimeout(timeout)
    end

    local obj = ExecutorBase.__init(self, parent, context)
    obj.default_power_limit = 0
    obj:setStep("checkBos")
    return obj
end

function BosHttpLuci:checkBos()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci"
    }
    self:makeBasicHttpReq(request)
    self:setStep("parseCheckBos", "check if BOS...")
end

function BosHttpLuci:parseCheckBos(httpResponse, stat)
    local context = self.context
    local response = self:parseHttpResponse(httpResponse, stat, false)
    if (not response) then
        return
    end

    if (not string.match(response.body, "Braiins")) then
        utils.debugInfo("BosHttpLuci:parseCheckBos", "It is not a BOS")
        self:setStep("end", "It is not a BOS")
        return
    end

    self:setStep("getSession", "success") -- set success to show in table if found
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
        self:setStep("getMinerMetaCfg")
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
    self:setStep("getMinerMetaCfg")
end

function BosHttpLuci:getMinerMetaCfg()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/miner/cfg_metadata/",
        headers = {
            ["content-type"] = "application/json,*/*"
        }
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseMinerMetaCfg", "get meta cfg...")
end

function BosHttpLuci:parseMinerMetaCfg(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    if obj.data ~= nil then
        for k, v in pairs(obj.data) do
            if v[1] == "autotuning" then
                for k, vv in pairs(v[2].fields) do
                    if vv[1] == "psu_power_limit" then
                        self.default_power_limit = vv[2].default
                    end
                end
            end
        end
    end

    self:setStep("getMinerCfg")
end

function BosHttpLuci:getMinerCfg()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/miner/cfg_data/",
        headers = {
            ["content-type"] = "application/json,*/*"
        }
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseMinerCfg", "get cfg...")
end

function BosHttpLuci:parseMinerCfg(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    if (obj.data ~= nil) then
        if obj.data.format ~= nil then
            miner:setOpt("minerTypeFound", "true")
            if obj.data.format.model ~= nil then
                miner:setFullTypeStr(obj.data.format.model .. " (BOS)")
            end
        end

        if (obj.data.group ~= nil and obj.data.group[1] ~= nil and obj.data.group[1].pool ~= nil) then
            local pools = obj.data.group[1].pool
            local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

            if pools[1] then
                pool1:setUrl(pools[1].url)
                pool1:setWorker(pools[1].user)
                if pools[1].password ~= nil then
                    pool1:setPasswd(pools[1].password)
                end
            end

            if pools[2] then
                pool2:setUrl(pools[2].url)
                pool2:setWorker(pools[2].user)
                if pools[2].password ~= nil then
                    pool2:setPasswd(pools[2].password)
                end
            end

            if pools[3] then
                pool3:setUrl(pools[3].url)
                pool3:setWorker(pools[3].user)
                if pools[3].password ~= nil then
                    pool3:setPasswd(pools[3].password)
                end
            end
        end

        local working_mode = ""
        if obj.data.hash_chain_global == nil then
            working_mode = "LPM"
        end

        if obj.data.hash_chain_global ~= nil and obj.data.hash_chain_global.asic_boost ~= false then
            working_mode = "LPM"
        end

        if obj.data.autotuning ~= nil then
            if
                obj.data.autotuning.psu_power_limit ~= nil and
                    obj.data.autotuning.psu_power_limit < self.default_power_limit
             then
                if working_mode ~= "" then
                    working_mode = working_mode .. ", "
                end
                working_mode = working_mode .. "Enhanced LPM"
            end
        end

        if working_mode == "" then
            working_mode = "Normal"
        end

        miner:setOpt("antminer.overclock_working_mode", working_mode)
    end

    self:setStep("getBosInfo", "success")
end

function BosHttpLuci:getBosInfo()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/bos/info",
        headers = {
            ["content-type"] = "application/json,*/*"
        }
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseBosInfo", "get BOS info...")
end

function BosHttpLuci:parseBosInfo(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    if obj.version ~= nil then
        miner:setOpt("firmware_version", obj.version)
    end

    self:setStep("getMinerNetwork", "success")
end

function BosHttpLuci:getMinerNetwork()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/network/iface_status/lan",
        headers = {
            ["content-type"] = "application/json,*/*"
        }
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseMinerNetwork", "get network info...")
end

function BosHttpLuci:parseMinerNetwork(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    if (obj.macaddr ~= nil) then
        miner:setOpt("mac_address", obj.macaddr)
    end

    self:setStep("getMinerOverview", "success")
end

function BosHttpLuci:getMinerOverview()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/status/overview?status=1",
        headers = {
            ["content-type"] = "application/json,*/*"
        }
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseMinerOverview", "read summary...")
end

function BosHttpLuci:parseMinerOverview(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    if (obj.wan ~= nil and obj.wan.proto ~= nil) then
        miner:setOpt("network_type", string.upper(obj.wan.proto))
    end

    if obj.uptime ~= nil then
        miner:setOpt("elapsed", utils.formatTime(obj.uptime, "d :h :m :s "))
    end

    self:setStep("getMinerStat", "success")
end

function BosHttpLuci:getMinerStat()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/miner/api_status/",
        headers = {
            ["content-type"] = "application/json,*/*"
        }
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseMinerStat", "read status...")
end

function BosHttpLuci:parseMinerStat(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    if (obj.summary ~= nil and obj.summary[1] ~= nil) then
        if obj.summary[1].STATUS ~= nil and obj.summary[1].STATUS[1] ~= nil then
            miner:setOpt("software_version", obj.summary[1].STATUS[1].Description)
        end
        if obj.summary[1].SUMMARY ~= nil and obj.summary[1].SUMMARY[1] ~= nil then
            local summary = obj.summary[1].SUMMARY[1]
            hashrateUnit = " TH/s"
            miner:setOpt("hashrate_5s", string.format("%.2f", tonumber(summary["MHS 5s"]) / 10 ^ 6) .. hashrateUnit)
            miner:setOpt("hashrate_avg", string.format("%.2f", tonumber(summary["MHS av"]) / 10 ^ 6) .. hashrateUnit)
        end
    end

    if (obj.fans ~= nil and obj.fans[1] ~= nil and obj.fans[1].FANS ~= nil) then
        local fans = obj.fans[1].FANS
        local fan = {}
        local i = 1
        while (fans[i] ~= nil) do
            local rpm = tonumber(fans[i]["RPM"])
            if rpm > 0 then
                table.insert(fan, string.format("%d", rpm))
            end
            i = i + 1
        end
        miner:setOpt("fan_speed", table.concat(fan, " / "))
    end

    if (obj.temps ~= nil and obj.temps[1] ~= nil and obj.temps[1].TEMPS ~= nil) then
        temps = obj.temps[1].TEMPS
        local temp = {}
        local i = 1
        while (temps[i] ~= nil) do
            local value = string.format("%.2f", tonumber(temps[i]["Chip"])) .. "°"
            table.insert(temp, value)
            i = i + 1
        end
        miner:setOpt("temperature", table.concat(temp, " / "))
    end

    self:setStep("end", "success")
end
