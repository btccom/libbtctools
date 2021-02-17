BosHttpLuci = oo.class({}, ExecutorBase)

function BosHttpLuci:__init(parent, context)
    local miner = context:miner()
    miner:setOpt("settings_pasword_key", "Antminer")

    local obj = {
        parent = parent,
        context = context,
        conf = {
            data = {
                group = nil,
                hash_chain_global = nil,
                autotuning = nil
            }
        }
    }

    obj = oo.rawnew(self, obj)
    obj:setStep("getSession", "get session")
    return obj
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
        self:setStep("getMinerCfg", "get miner cfg..")
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
    self:setStep("getMinerCfg", "get miner cfg..")
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
    self:setStep("parseMinerCfg", "parse miner cfg..")
end

function BosHttpLuci:parseMinerCfg(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()
    local pool1, pool2, pool3 = miner:pool1(), miner:pool2(), miner:pool3()

    self.conf.data.group = {
        [1] = {
            ["name"] = "mygroup",
            pool = {}
        }
    }

    if obj.data ~= nil and obj.data.group ~= nil and obj.data.group[1] ~= nil then
        self.conf.data.group[1].name = obj.data.group[1].name
    end

    if pool1:url() ~= "" and pool1:worker() ~= "" then
        self.conf.data.group[1].pool[1] = {
            url = pool1:url(),
            user = pool1:worker(),
            password = pool1:passwd()
        }
    end

    if pool2:url() ~= "" and pool2:worker() ~= "" then
        self.conf.data.group[1].pool[2] = {
            url = pool2:url(),
            user = pool2:worker(),
            password = pool2:passwd()
        }
    end

    if pool3:url() ~= "" and pool3:worker() ~= "" then
        self.conf.data.group[1].pool[3] = {
            url = pool3:url(),
            user = pool3:worker(),
            password = pool3:passwd()
        }
    end

    if (obj.data ~= nil and obj.data.format ~= nil and obj.data.format.model ~= nil) then
        miner:setOpt("_model", obj.data.format.model)
    end

    self:setStep("getMinerMetaCfg", "get miner meta cfg..")
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
    self:setStep("parseMinerMetaCfg", "parse miner cfg..")
end

function BosHttpLuci:parseMinerMetaCfg(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    local lpm = miner:opt("config.antminer.asicBoost")
    local elpm = miner:opt("config.antminer.lowPowerMode")

    local asic_boost = false
    if lpm == "true" then
        asic_boost = true
    end

    local psu_power_limit = nil
    if elpm == "true" then
        local default_power_limit = 0
        local min_power_limit = 0
        if obj.data ~= nil then
            for k, v in pairs(obj.data) do
                if v[1] == "autotuning" then
                    for k, vv in pairs(v[2].fields) do
                        if vv[1] == "psu_power_limit" then
                            default_power_limit = vv[2].default
                            min_power_limit = vv[2].min
                        end
                    end
                end
            end
        end

        if default_power_limit > 0 then
            psu_power_limit = math.floor(default_power_limit * 0.6666)
            if psu_power_limit < min_power_limit then
                psu_power_limit = min_power_limit
            end
        end
    end

    if miner:opt("_model") == "Antminer S9" then
        self.conf.data.hash_chain_global = {
            asic_boost = asic_boost
        }
    end

    if psu_power_limit then
        self.conf.data.autotuning={
            enabled=true,
            psu_power_limit=psu_power_limit
        }
    end

    self:setStep("saveMinerConf", "parse save cfg..")
end

function BosHttpLuci:saveMinerConf()
    local request = {
        method = "POST",
        path = "/cgi-bin/luci/admin/miner/cfg_save/",
        headers = {
            ["content-type"] = "application/json,*/*"
        },
        body = utils.jsonEncode(self.conf)
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseSaveResult", "parse save cfg..")
end

function BosHttpLuci:parseSaveResult(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        self:setStep("end", "failed: " .. response.statMsg)
        return
    end
    self:setStep("applyMinerConf", "apply miner cfg..")
end

function BosHttpLuci:applyMinerConf()
    local request = {
        method = "GET",
        path = "/cgi-bin/luci/admin/miner/cfg_apply/"
    }

    self:makeSessionedHttpReq(request)
    self:setStep("parseApplyResult", "parse apply cfg..")
end

function BosHttpLuci:parseApplyResult(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        self:setStep("end", "failed: " .. response.statMsg)
        return
    end
    self:setStep("end", "success")
end
