
function makeRequest(context)
	local _, err = pcall (doMakeRequest, context)
	
	if (err) then
		context:setStepName("end")
		context:miner():setStat('failed: ' .. err)
		context:setCanYield(true)
	end
	
end

function makeResult(context, response, stat)
	local _, err = pcall (doMakeResult, context, response, stat)
	
	if (err) then
		context:setStepName("end")
		context:miner():setStat('failed: ' .. err)
		context:setCanYield(true)
	end
end

local loadScanner = function(name)
    return pcall (require, "lua.scripts.minerScanner." .. name)
end

local nextScannerName = function(currentName)
    local scannerMap = {
        ["http-auto-detect"] = "antminer-cgminer"
    }
    
    return scannerMap[currentName]
end

local contextRestart = function(context)
    context:setStepName("begin")
    context:setCanYield(false)
end


function doMakeRequest(context)

    local miner = context:miner()
    local scannerName = miner:opt('scannerName')
    
    if (scannerName == "") then
        scannerName = "http-auto-detect"
        miner:setOpt('scannerName', scannerName)
    end
    
    local success, scanner = loadScanner(scannerName)
    
    if (success) then
        scanner.doMakeRequest(context)
    else
        context:setStepName("end")
		context:miner():setStat('failed: ' .. scanner)
		context:setCanYield(true)
    end
end

function doMakeResult(context, response, stat)

    local miner = context:miner()
    local scannerName = miner:opt('scannerName')
    
    assert(scannerName ~= "", "inner error: scannerName cannot be empty!")

    if (stat ~= "success") then
        
        scannerName = nextScannerName(scannerName)
        
        if (scannerName == nil) then
            context:setStepName("end")
            context:miner():setStat(stat)
            context:setCanYield(true)
        else
            miner:setOpt('scannerName', scannerName)
            contextRestart(context)
        end
        
        return
    end
    
    local success, scanner = loadScanner(scannerName)
    
    if (success) then
        scanner.doMakeResult(context, response, stat)
        
        if (context:stepName() == 'end') and ((miner:typeStr() == 'unknown') or (miner:typeStr() == '')) then
            scannerName = nextScannerName(scannerName)
            
            if (scannerName ~= nil) then
                miner:setOpt('scannerName', scannerName)
                contextRestart(context)
            end
            
            return
        end
        
    else
        context:setStepName("end")
		context:miner():setStat('failed: ' .. scanner)
		context:setCanYield(true)
    end
end
