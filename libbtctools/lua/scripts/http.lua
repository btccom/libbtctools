local http = {}

---------------- HTTP Message Parse ----------------

local parseHttpMessage = function(httpMessage)
	local headers = {}
	local body = nil
	
	local headerEnd, bodyBegin = string.find(httpMessage, "\r\n\r\n")
	
	if (headerEnd == nil) then
		body = httpMessage
	else
		headerEnd = headerEnd + 1
		bodyBegin = bodyBegin + 1
		
		body = string.sub(httpMessage, bodyBegin)
		
		local lineBegin = 1
		local lineEnd = string.find(httpMessage, "\r\n")
		
		while (lineEnd < headerEnd) do
			lineEnd = lineEnd - 1
			
			local line = string.sub(httpMessage, lineBegin, lineEnd)
			table.insert(headers, line)
			
			lineBegin = lineEnd + 3
			lineEnd = string.find(httpMessage, "\r\n", lineBegin)
		end
	end
	
	return headers, body
end

--[[
	headerArray = {
		{key, value},
		{key, value},
		...
	}
	
	headerMap = {
		key1 = value1,
		key2 = value2,
		...
	}
	
	key = string.lower(key)
]]
local parseHttpHeaders = function(headers)
	local headerArray = {}
	local headerMap = {}
	
	for i=2,#headers do
		local splitBegin, splitEnd = string.find(headers[i], "%s*:%s*")
		local key = string.lower(string.sub(headers[i], 1, splitBegin - 1))
		local value = string.sub(headers[i], splitEnd + 1)
		
		table.insert(headerArray, {key, value})
		headerMap[key] = value
	end
	
	return headerArray, headerMap
end

local parseHttpRequestLine = function(requestLine)
	local method, path, protocol = string.match(requestLine, "^(%u+)%s+(.+)%s+(HTTP/[0-9.]+)$")

	return method, path, protocol
end

local parseHttpResponseLine = function(responseLine)
	local protocol, statCode, statMsg = string.match(responseLine, "^(HTTP/[0-9.]+)%s+(%d+)%s+(.+)$")
	
	return statCode, statMsg, protocol
end

function http.parseRequest(httpMessage)
	local headers, body = parseHttpMessage(httpMessage)
	local headerArray, headerMap = parseHttpHeaders(headers)
	
	assert(headers[1], "Empty HTTP request line")
	local method, path, protocol = parseHttpRequestLine(headers[1])
	
	return {
		method = method,
		path = path,
		protocol = protocol,
		headerArray = headerArray,
		headerMap = headerMap,
		body = body
	}
end

function http.parseResponse(httpMessage)
	local headers, body = parseHttpMessage(httpMessage)
	local headerArray, headerMap = parseHttpHeaders(headers)
	
	assert(headers[1], "Empty HTTP response line")
	local statCode, statMsg, protocol = parseHttpResponseLine(headers[1])
	
	return {
		statCode = statCode,
		statMsg = statMsg,
		protocol = protocol,
		headerArray = headerArray,
		headerMap = headerMap,
		body = body
	}
end

---------------- HTTP Digest Auth ----------------
-------------- some functions copied from:
-- https://github.com/catwell/lua-http-digest/blob/master/http-digest.lua

local hash = function(...)
	local x = table.concat({...}, ":")
    local y = Crypto.md5(x)
	print (y, x)
	return y
end

local parse_header = function(h)
    local r = {}
    for k,v in (h .. ','):gmatch("(%w+)=\"([^\"]*)\"") do
		r[k:lower()] = v
    end
    return r
end

local make_digest_header = function(t)
    local s = {}
    local x
    for i=1,#t do
        x = t[i]
        if x.unquote then
            s[i] =  x[1] .. '=' .. x[2]
        else
            s[i] = x[1] .. '="' .. x[2] .. '"'
        end
    end
    return "Digest " .. table.concat(s, ', ')
end

local make_digest_request = function(httpRequest, httpResponse, user, password)

	if (httpResponse.statCode == "401") and httpResponse.headerMap["www-authenticate"] then
	
        local ht = parse_header(httpResponse.headerMap["www-authenticate"])
        assert(ht.realm and ht.nonce and ht.opaque, "Digest fields missing: " .. httpResponse.headerMap["www-authenticate"])
		
        if ht.qop ~= "auth" then
            return nil, string.format("unsupported qop: %s", tostring(ht.qop))
        end
		
        if ht.algorithm and (ht.algorithm:lower() ~= "md5") then
            return nil, string.format("unsupported algorithm: %s", tostring(ht.algorithm))
        end
		
        local cnonce = string.format("%08x", os.time())
		local nc = "00000001"
        local uri = httpRequest.path
        local method = httpRequest.method
        local response = hash(
            hash(user, ht.realm, password),
            ht.nonce,
            nc,
            cnonce,
            "auth",
            hash(method, uri)
        )
        
        local authorization = make_digest_header{
            {"username", user},
            {"realm", ht.realm},
            {"nonce", ht.nonce},
            {"uri", uri},
            {"cnonce", cnonce},
            {"nc", nc, unquote=true},
            {"qop", "auth"},
            {"algorithm", "MD5"},
            {"response", response},
            {"opaque", ht.opaque},
        }
		
		return authorization
	else
		return nil, string.format("auth not needed: %s %s %s", httpResponse.statCode, httpResponse.statMsg, httpResponse.protocol)
	end
end

---------------- End of function defines ----------------

return http
