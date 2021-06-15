AvalonHttpLuci = oo.class({}, ExecutorBase)

function AvalonHttpLuci:__init(parent, context)
    local miner = context:miner()
    local ip = miner:ip()
    if context:miner():opt('minerTypeFound') ~= 'true' then
        miner:setFullTypeStr("Avalon")
    end
    miner:setTypeStr("AvalonHttpLuci")
    miner:setOpt("upgrader.disabled", "true")

    if (miner:opt("httpPortAvailable") == "true") then
        local timeout = context:requestSessionTimeout() * 5
        if (timeout < 5) then
            timeout = 5
        end
        context:setRequestSessionTimeout(timeout)
    end

    local obj = ExecutorBase.__init(self, parent, context)
    obj:setStep("login")
    return obj
end

function AvalonHttpLuci:login()
    local context = self.context
    local miner = context:miner()
    local ip = miner:ip()
    local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())

    if (loginPassword == nil) then
        self:setStep("end", "require password")
        return
    end

    local request = {
        method = 'POST',
        host = ip,
        path = '/cgi-bin/luci/avalon/page/index',
        body = 'username='..loginPassword.userName..'&password='..loginPassword.password,
        headers = {
            ['Content-Type'] = 'application/x-www-form-urlencoded'
        }
    }

    context:setRequestHost(ip)
    context:setRequestPort("80")
    context:setRequestContent(http.makeRequest(request))

    self:setStep("doLogin", "login...")
end

function AvalonHttpLuci:doLogin(response, stat)
    response = http.parseResponse(response)
    if (response.statCode ~= "302") then
        self:setStep("end", "login failed")
        return
    end

    local cookie = response.headers['set-cookie']
    local url = response.headers['location']

    if type(cookie) ~= 'table' or cookie[1] == nil
        or type(url) ~= 'table' or url[1] == nil
    then
        self:setStep("end", "login failed")
        return
    end

    self.cookie = string.gsub(cookie[1], ';.*', '')
    self.stok = string.match(url[1], '/;stok=([^/]*)/')

    self:setStep("getStat", "success")
end

function AvalonHttpLuci:makeLuciRequest(apiPath)
    local request = {
        method = 'GET',
        host = self.context:miner():ip(),
        path = '/cgi-bin/luci/;stok=' .. self.stok .. apiPath,
        headers = {
            ['Cookie'] = self.cookie
        }
    }
    self.context:setRequestContent(http.makeRequest(request))
end

function AvalonHttpLuci:getStat()
    self:makeLuciRequest('/avalon/api/getstatus')
    self:setStep('readStat', 'get status...')
end

function AvalonHttpLuci:readStat(response, stat)
    response = http.parseResponse(response)
    self:parseAvalonStat(response.body)
    self:setStep('getPools')
end

function AvalonHttpLuci:parseAvalonStat(jsonStr)
    local miner = self.context:miner()
    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()

    local stat, pos, err = utils.jsonDecode (jsonStr)

    if err then
        miner:setStat("failed: "..err)
        utils.debugInfo('AvalonHttpLuci:parseAvalonStat', err)
        return
    end
    if not stat or type(stat) ~= 'table' then
        miner:setStat("failed: Unexpected response: "..jsonStr)
        utils.debugInfo('AvalonHttpLuci:parseAvalonStat', "Unexpected response")
        return
    end

    if (stat['openwrtver']) then
        miner:setFullTypeStr(stat['openwrtver'])
        miner:setOpt('minerTypeFound', 'true')
    end

    if (stat['elapsed']) then
        miner:setOpt('elapsed', utils.formatTime(stat['elapsed'], 'd :h :m :s '))
    end

    if (stat['ghsmm']) then
        miner:setOpt('hashrate_5s', stat['ghsmm']..' GH/s')
    end

    if (stat['ghsav']) then
        miner:setOpt('hashrate_avg', stat['ghsav']..' GH/s')
    end

    if (stat['temp']) then
        miner:setOpt('temperature', tostring(stat['temp']))
    end

    if (stat['fan']) then
        miner:setOpt('fan_speed', tostring(stat['fan']))
    end

    if (type(stat['pool']) == 'table') then
        local pools = stat['pool']

        if (type(pools[1]) == 'table') then
            if (pools[1].user) then
                pool1:setWorker(pools[1].user)
            end

            if (pools[1].url) then
                pool1:setUrl(pools[1].url)
            end
        end

        if (type(pools[2]) == 'table') then
            if (pools[2].user) then
                pool1:setWorker(pools[2].user)
            end

            if (pools[2].url) then
                pool1:setUrl(pools[2].url)
            end
        end

        if (type(pools[3]) == 'table') then
            if (pools[3].user) then
                pool1:setWorker(pools[3].user)
            end

            if (pools[3].url) then
                pool1:setUrl(pools[3].url)
            end
        end

    end

    miner:setStat("success")
end

function AvalonHttpLuci:getPools()
    self:makeLuciRequest('/avalon/page/configure')
    self:setStep('readPools', 'get pools...')
end

function AvalonHttpLuci:readPools(response, stat)
    response = http.parseResponse(response)
    self:parseAvalonPools(response.body)
    self:setStep('getNetwork')
end

function AvalonHttpLuci:parseAvalonPools(html)
    local miner = self.context:miner()
    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()

    if not string.match(html, 'id="cbid.cgminer.default.pool1url"') then
        miner:setStat("parse pools failed")
        return
    end

    local url, worker, passwd = nil, nil, nil

    -- pool 1
    url = string.match(html, 'id="cbid.cgminer.default.pool1url"%s+value="(.-)"')
    worker = string.match(html, 'id="cbid.cgminer.default.pool1user"%s+value="(.-)"')
    passwd = string.match(html, 'id="cbid.cgminer.default.pool1pw"%s+value="(.-)"')

    if (url ~= nil) then pool1:setUrl(url) end
    if (worker ~= nil) then pool1:setWorker(worker) end
    if (passwd ~= nil) then pool1:setPasswd(passwd) end

    -- pool 2
    url = string.match(html, 'id="cbid.cgminer.default.pool2url"%s+value="(.-)"')
    worker = string.match(html, 'id="cbid.cgminer.default.pool2user"%s+value="(.-)"')
    passwd = string.match(html, 'id="cbid.cgminer.default.pool2pw"%s+value="(.-)"')

    if (url ~= nil) then pool2:setUrl(url) end
    if (worker ~= nil) then pool2:setWorker(worker) end
    if (passwd ~= nil) then pool2:setPasswd(passwd) end

    -- pool 3
    url = string.match(html, 'id="cbid.cgminer.default.pool3url"%s+value="(.-)"')
    worker = string.match(html, 'id="cbid.cgminer.default.pool3user"%s+value="(.-)"')
    passwd = string.match(html, 'id="cbid.cgminer.default.pool3pw"%s+value="(.-)"')

    if (url ~= nil) then pool3:setUrl(url) end
    if (worker ~= nil) then pool3:setWorker(worker) end
    if (passwd ~= nil) then pool3:setPasswd(passwd) end

    -- ntp service
    ntpEnable = string.match(html, 'id="cbi%-cgminer%-default%-ntp_enable%-[^"]-"%s+value="([^"]-)"%s+selected="selected"')
    if (ntpEnable ~= nil) then miner:setOpt('luci.config.cgminer.ntp_enable', ntpEnable) end

    miner:setStat("success")
end

function AvalonHttpLuci:getNetwork()
    self:makeLuciRequest('/admin/network/iface_status/lan')
    self:setStep('readNetwork', 'get network info...')
end

function AvalonHttpLuci:readNetwork(response, stat)
    response = http.parseResponse(response)
    self:parseAvalonNetwork(response.body)
    self:setStep('getModel')
end

function AvalonHttpLuci:parseAvalonNetwork(jsonStr)
    local miner = self.context:miner()

    local obj, pos, err = utils.jsonDecode (jsonStr)
    if err then
        miner:setStat("failed: "..err)
        utils.debugInfo('AvalonHttpLuci:parseAvalonNetwork', err)
        return
    end
    if not obj or type(obj) ~= 'table' then
        miner:setStat("failed: Unexpected response: "..jsonStr)
        utils.debugInfo('AvalonHttpLuci:parseAvalonNetwork', "Unexpected response")
        return
    end

    -- Due to the problem of the JSON parser, 
    -- if the array obj has only one member, 
    -- it will be located directly in the outer layer.
    if not obj.ifname then
        for _, v in pairs(obj) do
            if v.ifname == 'br-lan' then
                obj = v
                break
            end
        end
        if not obj.ifname and obj[1] then
            obj = obj[1]
        end
    end

    if type(obj.proto) == 'string' then
        miner:setOpt('network_type', string.upper(obj.proto))
    end
    if type(obj.macaddr) == 'string' then
        miner:setOpt('mac_address', string.upper(obj.macaddr))
    end
    miner:setStat("success")
end

function AvalonHttpLuci:getModel()
    self:makeLuciRequest('/admin/status/overview')
    self:setStep('readModel', 'find type...')
end

function AvalonHttpLuci:readModel(response, stat)
    response = http.parseResponse(response)
    self:parseAvalonModel(response.body)
    self:setStep('end')
end

function AvalonHttpLuci:parseAvalonModel(response, stat)
    local context = self.context
    local miner = context:miner()

    local hardware = string.match(response, '<td[^>]*>%s*Model%s*</td>%s*<td>%s*([^<]-)%s*</td>') or 
                     string.match(response, '<td[^>]*>%s*主机型号%s*</td>%s*<td>%s*([^<]-)%s*</td>');

    local firmware = string.match(response, '<td[^>]*>%s*Firmware%s*Version%s*</td>%s*<td>%s*([^<]-)%s*</td>') or 
                     string.match(response, '<td[^>]*>%s*固件版本%s*</td>%s*<td>%s*([^<]-)%s*</td>');
    
    local software = string.match(response, '<td[^>]*>%s*Kernel%s*Version%s*</td>%s*<td>%s*([^<]-)%s*</td>') or 
                     string.match(response, '<td[^>]*>%s*内核版本%s*</td>%s*<td>%s*([^<]-)%s*</td>');

    if hardware ~= nil and hardware ~= "" then
        miner:setOpt('hardware_version', string.gsub(hardware, '%s+', ' '))
    end
    if firmware ~= nil and firmware ~= "" then
        miner:setOpt('firmware_version', string.gsub(firmware, '%s+', ' '))
    end
    if software ~= nil and software ~= "" then
        miner:setOpt('software_version', string.gsub(software, '%s+', ' '))
    end

    miner:setStat("success")
end
