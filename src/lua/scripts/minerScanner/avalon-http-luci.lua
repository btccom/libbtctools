local scanner = {}

local utils = require ("utils")
local http = require ("http")

local parseAvalonStat = function (jsonStr, context)
    local miner = context:miner()
    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()

    local stat, pos, err = utils.jsonDecode (jsonStr)
    
    if not (err) then
    
        if (stat['openwrtver']) then
            miner:setFullTypeStr(stat['openwrtver'])
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
        
        miner:setTypeStr('avalon-http-luci')
        miner:setStat("success")
    else
		miner:setStat("failed: " .. err)
    end
end

local parseAvalonPools = function (html, context)
    local miner = context:miner()
    local pool1 = miner:pool1()
    local pool2 = miner:pool2()
    local pool3 = miner:pool3()

    if (string.match(html, 'id="cbid.cgminer.default.pool1url"')) then
        miner:setStat("success")
        
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

    else
		miner:setStat("parse pools failed")
    end
end

function scanner.doMakeRequest(context)
    local step = context:stepName()
    local miner = context:miner()
    local ip = miner:ip()
    
    context:setCanYield(true)

    if (step == "begin") then
        local loginPassword = utils.getMinerLoginPassword(miner:fullTypeStr())
        
        if (loginPassword == nil) then
            context:setStepName("end")
            context:miner():setStat("require password")
        else
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
		    context:setStepName("login")
            miner:setStat('login...')
        end
        
    elseif (step == "getStat") then
        local cookie = miner:opt('cookie')
        local stok = miner:opt('stok')
        
        local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/luci/;stok=' .. stok .. '/avalon/api/getstatus',
            headers = {
                ['Cookie'] = cookie
            }
		}
        
        context:setRequestContent(http.makeRequest(request))
		context:setStepName("readStat")
        miner:setStat('get status...')
        
    elseif (step == "getPools") then
        local cookie = miner:opt('cookie')
        local stok = miner:opt('stok')
        
        local request = {
			method = 'GET',
			host = ip,
			path = '/cgi-bin/luci/;stok=' .. stok .. '/avalon/page/configure',
            headers = {
                ['Cookie'] = cookie
            }
		}
        
        context:setRequestContent(http.makeRequest(request))
		context:setStepName("readPools")
        miner:setStat('get pools...')
        
    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
		context:setCanYield(true)
    end
end

function scanner.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
    
    context:setCanYield(true)
    miner:setStat(stat)
    
	response = http.parseResponse(response)
    
    if (step == "login") then
        if (response.statCode == "302") then
            local cookie = response.headers['set-cookie']
            local url = response.headers['location']
            
            if (type(cookie) == 'table' and cookie[1] ~= nil
                and type(url) == 'table' and url[1] ~= nil) then
                
                cookie = string.gsub(cookie[1], ';.*', '')
                miner:setOpt('cookie', cookie)
                
                local stok = string.match(url[1], '/;stok=([^/]*)/')
                miner:setOpt('stok', stok)
                
                context:setStepName("getStat")
            else
                context:setStepName("end")
                miner:setStat("login failed")
            end
            
        else
            context:setStepName("end")
			miner:setStat("login failed")
        end
    
    elseif (step == "readStat") then
        context:setStepName("getPools")
        parseAvalonStat(response.body, context)
        
        
    elseif (step == "readPools") then
        context:setStepName("end")
        parseAvalonPools(response.body, context)
        
    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
    end
end

return scanner
