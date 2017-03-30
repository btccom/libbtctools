local scanner = {}

local utils = require ("lua.scripts.utils")
local http = require ("lua.scripts.http")

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
    else
		miner:setStat("failed: " .. err)
    end
end

function scanner.doMakeRequest(context)
    local step = context:stepName()
    local miner = context:miner()
    local ip = miner:ip()
    
    if (step == "begin") then
        local request = {
			method = 'POST',
			host = ip,
			path = '/cgi-bin/luci/avalon/page/index',
            body = 'username=root&password=',
            headers = {
                ['Content-Type'] = 'application/x-www-form-urlencoded'
            }
		}
		
		context:setRequestHost(ip)
		context:setRequestPort("80")
		context:setRequestContent(http.makeRequest(request))
		context:setStepName("login")
        
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
        
        print (context:requestContent())
    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
		context:setCanYield(true)
    end
end

function scanner.doMakeResult(context, response, stat)
    local step = context:stepName()
    local miner = context:miner()
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
                context:setCanYield(false)
            else
                context:setStepName("end")
                miner:setStat("auth failed")
                context:setCanYield(true)
            end
            
        else
            context:setStepName("end")
			miner:setStat("auth failed")
			context:setCanYield(true)
        end
    
    elseif (step == "readStat") then
        parseAvalonStat(response.body, context)
        
        context:setStepName("end")
		context:setCanYield(true)
    else
        context:setStepName("end")
		miner:setStat("inner error: unknown step name: " .. step)
		context:setCanYield(true)
    end
end

return scanner
