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
    local miner = context:miner();
    miner:setTypeStr("AnthillOS")

    if(miner:opt("httpPortAvailable") == "true") then 
        local timeout = context:requestSessionTimeout() * 5
        if(timeout < 5) then
            timeout = 5
        end
        context:setRequestSessionTimeout(timeout)
    end

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep("getMinerInfo")
    return obj
end

function AnthillOS:getMinerInfo()
    local request = {
        method = "GET",
        path = "/api/v1/info"
    }

    self:makeBasicHttpReq(request)
    self:setStep("parseMinerInfo", "parse miner info...")
end

function AnthillOS:parseMinerInfo(httpResponse, stat)
    local fullTypeStr = 'unknown'
    local miner = self.context:miner();
    local obj = self:parseHttpResponseJson(httpResponse, stat)
    local system = obj.system;
    local network = system.network_status;

    if (not obj) then
        return
    end

    if type(obj) == "table" then     
        --------------------
        --set full miner type
        --------------------
        if (obj.miner ~= nil and type(obj.miner) == "string") then
            if (obj.fw_name ~= nil and type(obj.fw_name) == "string"
                and obj.fw_version ~= nil and type(obj.fw_version) == "string") then
                fullTypeStr = string.format("%s (%s %s)", obj.miner, obj.fw_name, obj.fw_version);
                miner:setOpt('minerTypeFound', 'true')
            end
        end
        --------------------
        --set fw version
        --------------------
        if(obj.build_time ~= nil and type(obj.build_time) == "string") then
            local ok, firmwareVer = pcall(date, obj.build_time)

            if(ok) then
                miner:setOpt('firmware_version', firmwareVer:fmt("%Y%m%d"))
            end
        end
        --------------------
        --set hw version
        --------------------
        if (obj.hw_version ~= nil and type(obj.hw_version) == "string") then
            miner:setOpt('hardware_version', obj.hw_version)
        end
        --------------------
        --set mac address
        -------------------
        if (type(network) == "table") then
            if (network.mac ~= nil and type(network.mac) == "string") then
                miner:setOpt('mac_address', network.mac)
            end

            local network_type = 'Static'
            
            if(network.dhcp ~= nil and network.dhcp == true) then
                network_type = 'DHCP'
            end

            miner:setOpt('network_type', network_type)
        end
    end

    miner:setFullTypeStr(fullTypeStr)

    --------------------
    --set success to show in table if found
    -------------------
    self:setStep("getSummary", "success")
end

function AnthillOS:getSummary()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = 'GET',
        path = '/api/v1/summary',
        headers = {
            ['Accept-Encoding']='identity'
        }
    }

    self:makeBasicHttpReq(request)

    self:setStep('parseSummary')
end

function AnthillOS:parseSummary(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)

    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    if (type(obj) ~= "table") then
        return;
    end

    local miner_json = obj.miner

    if (type(miner_json) == "table") then
        if (miner_json.cgminer_version ~= nil) then
            miner:setOpt('software_version', 'cgminer '..miner_json.cgminer_version)
        end

        local miner_status = miner_json.miner_status;

        if (type(miner_status) == "table") then   
            if(miner_status.miner_state_time ~= nil) then
                miner:setOpt('elapsed', utils.formatTime(miner_status.miner_state_time, 'd :h :m :s '))
            end

            if (miner_status.last_error_code ~= nil) then
               miner:setOpt("antminer.overclock_working_mode", 'Error '..miner_status.last_error_code)
            end
        end

        local hashrateUnit = ' GH/s'

        if (miner_json.instant_hashrate ~= nil) then
            miner:setOpt('hashrate_5s', string.format("%.2f %s", miner_json.instant_hashrate * 1000.0, hashrateUnit))
        end

        if (miner_json.average_hashrate ~= nil) then
            miner:setOpt('hashrate_avg', string.format("%.2f %s" , miner_json.average_hashrate * 1000.0, hashrateUnit))
        end

        local cooling = miner_json.cooling

        if (type(cooling) == "table") then
            local fans = cooling.fans
            local fan = {}
            local i = 1

            while(fans[i] ~= nil) do
                if (fans[i].rpm ~= nil) then
                    table.insert(fan, fans[i].rpm)
                end

                i = i + 1
            end

            miner:setOpt('fan_speed', table.concat(fan, ' / '))
        end

        local chains = miner_json.chains

        if (type(chains) == "table") then
            local temp = {}
            local i = 1

            while(chains[i] ~= nil) do
                local chip_temp = chains[i].chip_temp

                if(chip_temp ~= nil) then 
                    if(type(chip_temp) == "table") then
                        if(chip_temp.max ~= nil) then
                            table.insert(temp, chip_temp.max)
                        else
                            table.insert(temp, '--')
                        end
                    else 
                        table.insert(temp, '--')
                    end
                else
                    table.insert(temp, '--')
                end

                i = i + 1
            end

            miner:setOpt('temperature', table.concat(temp, ' / '))
        end

        local pools = miner_json.pools

        if (type(pools) == "table") then
            local pool1, pool2, pool3 =  miner:pool1(), miner:pool2(), miner:pool3()
    
            if (pools[1] ~= nil) then
                if (not string.match(pools[1].url, 'DevFee')) then
                    pool1:setUrl(pools[1].url)
                    pool1:setWorker(pools[1].user)
                end
            end
    
            if (pools[2] ~= nil) then
                if (not string.match(pools[2].url, 'DevFee')) then
                    pool2:setUrl(pools[2].url)
                    pool2:setWorker(pools[2].user)
                end
            end
    
            if (pools[3] ~= nil) then
                if (not string.match(pools[3].url, 'DevFee')) then
                    pool3:setUrl(pools[3].url)
                    pool3:setWorker(pools[3].user)
                end
            end
        end
    end

    self:setStep('getSession', 'success')
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

    self:setStep('getMinerSettings')
end

function AnthillOS:getMinerSettings()
    local context = self.context
    local miner = context:miner()

    local request = {
        method = 'GET',
        path = '/api/v1/settings',
        headers = {
            ['Authorization']=miner:opt('anthill_token'),
            ['content-type']='application/json; charset=utf-8'
        }
    }

    self:makeBasicHttpReq(request)

    self:setStep('parseMinerSettings')
end

function AnthillOS:parseMinerSettings(httpResponse, stat)
    local obj = self:parseHttpResponseJson(httpResponse, stat)

    if (not obj) then
        return
    end

    local context = self.context
    local miner = context:miner()

    if (type(obj) ~= "table") then
        return;
    end

    local overclock = obj.miner.overclock

    local pools = obj.miner.pools

    if (type(pools) == "table") then
        local pool1, pool2, pool3 =  miner:pool1(), miner:pool2(), miner:pool3()

        if (pools[1] ~= nil) then
            pool1:setUrl(pools[1].url)
            pool1:setWorker(pools[1].user)
            if (pools[1].password ~= nil) then
                pool1:setPasswd(pools[1].password)
            end
        end

        if (pools[2] ~= nil) then
            pool2:setUrl(pools[2].url)
            pool2:setWorker(pools[2].user)
            if (pools[2].password ~= nil) then
                pool2:setPasswd(pools[2].password)
            end
        end

        if (pools[3] ~= nil) then
            pool3:setUrl(pools[3].url)
            pool3:setWorker(pools[3].user)
            if (pools[1].password ~= nil) then
                pool3:setPasswd(pools[3].password)
            end
        end
    end

    if(string.len(miner:opt("antminer.overclock_working_mode")) <= 0) then
        if (type(overclock) == "table") then
            if(overclock.preset ~= nil) then
                if(string.match(overclock.preset, 'disabled')) then
                    miner:setOpt("antminer.overclock_working_mode", 'User')
                else
                    miner:setOpt("antminer.overclock_working_mode", overclock.preset)
                end 
            else
                miner:setOpt("antminer.overclock_working_mode", 'User')
            end
        end
    end

    self:setStep('closeSession')
end


function AnthillOS:closeSession()
    local context = self.context
    local miner = context:miner()
    
    local request = {
        method = 'POST',
        path = '/api/v1/lock',
        headers = {
            ['Authorization']='Bearer '..miner:opt('anthill_token')
        }
    }

    self:makeBasicHttpReq(request);

    self:setStep('parseCloseSession')
end

function AnthillOS:parseCloseSession(httpResponse, stat)
    local response = self:parseHttpResponse(httpResponse, stat)

    if (response.statCode ~= "200") then
        self:setStep("end", "Close session error")
        return
    end

    self:setStep('end', 'success')
end
