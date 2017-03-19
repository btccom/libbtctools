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

--[[-----------------------------
	headerMap = {
		key1 = { value1 },
		key2 = { value21, value22 },
		...
	}
	key = string.lower(key)
--------------------------------]]
local parseHttpHeaders = function(headers)
	local headerMap = {}
	
	for i=2,#headers do
		local splitBegin, splitEnd = string.find(headers[i], "%s*:%s*")
		local key = string.lower(string.sub(headers[i], 1, splitBegin - 1))
		local value = string.sub(headers[i], splitEnd + 1)
		
		if (headerMap[key] == nil) then
			headerMap[key] = { value }
		else
			table.insert(headerMap[key], value)
		end
	end
	
	return headerMap
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
	local headerMap = parseHttpHeaders(headers)
	
	assert(headers[1], "Empty HTTP request line")
	local method, path, protocol = parseHttpRequestLine(headers[1])
	
	return {
		method = method,
		path = path,
		protocol = protocol,
		headers = headerMap,
		body = body
	}
end

function http.parseResponse(httpMessage)
	local headers, body = parseHttpMessage(httpMessage)
	local headerMap = parseHttpHeaders(headers)
	
	assert(headers[1], "Empty HTTP response line")
	local statCode, statMsg, protocol = parseHttpResponseLine(headers[1])
	
	return {
		statCode = statCode,
		statMsg = statMsg,
		protocol = protocol,
		headers = headerMap,
		body = body
	}
end

---------------- HTTP Digest Auth ----------------
-------------- some functions copied from:
-- https://github.com/catwell/lua-http-digest/blob/master/http-digest.lua

local hash = function(...)
	return Crypto.md5(table.concat({...}, ":"))
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

local make_basic_auth = function(httpRequest, httpResponse, user, password)
	return Crypto.base64Encode(user .. ':' .. password)
end

local make_digest_auth = function(httpRequest, httpResponse, user, password)
    local ht = parse_header(httpResponse.headers["www-authenticate"][1])
    assert(ht.realm and ht.nonce and ht.opaque, "Digest fields missing: " .. httpResponse.headers["www-authenticate"][1])
	
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
end

--[[-------------------------
    httpRequest = {
		method = 'POST',
		host = 'localhost',
		path = '/post.do',
		headers = {
			'Accept' = 'text/html, text/plain, */*',
			'Content-Type' = 'application/x-www-form-urlencoded',
			'Test' = { 'a', 'b', 'c' }
		},
		body = "a=1&b=2&c=3"
	}
-----------------------------]]
function http.makeRequest(httpRequest)
	if (httpRequest.method == nil) then
		if (string.len(httpRequest.body) > 0) then
			httpRequest.method = 'POST'
		else
			httpRequest.method = 'GET'
		end
	end
	
	if (httpRequest.headers == nil) then
		httpRequest.headers = {}
	end
	
	if (httpRequest.body == nil) then
		httpRequest.body = ""
	end

	local line = httpRequest.method .. ' ' .. httpRequest.path .. ' HTTP/1.1'
	local headers = { line }
	
	httpRequest.headers['user-agent'] = { 'BTC Tools v0.1' };
	httpRequest.headers['connection'] = { 'close' };
	httpRequest.headers['accept-encoding'] = nil;
	httpRequest.headers['keep-alive'] = nil;
	
	if not (httpRequest.host == nil) then
		httpRequest.headers['host'] = httpRequest.host
	end
	
	if (string.len(httpRequest.body) > 0) then
		httpRequest.headers['content-length'] = { string.len(httpRequest.body) };
	end
	
	for key, arr in pairs(httpRequest.headers) do
		key = key:gsub("^%l", string.upper)
		key = key:gsub("-%l", string.upper)
	
		if not (type(arr) == 'table') then
			arr = { arr }
		end
	
		for i=1, #arr do
			line = key .. ': ' .. arr[i]
			table.insert(headers, line)
		end
	end
	
	headers = table.concat(headers, "\r\n")
	
	return headers .. "\r\n\r\n" .. httpRequest.body
end

function http.makeAuthRequest(httpRequest, httpResponse, user, password)
	if (httpResponse.statCode == "401") and httpResponse.headers["www-authenticate"] then
		local authLine = httpResponse.headers["www-authenticate"][1]
		
		if (string.match(authLine, "^[Bb]asic")) then
			authLine = make_basic_auth(httpRequest, httpResponse, user, password)
		elseif (string.match(authLine, "^[Dd]igest")) then
			authLine = make_digest_auth(httpRequest, httpResponse, user, password)
		else
			return nil, string.format("Unsupported auth method: %s", authLine)
		end
		
		httpRequest.headers["authorization"] = { authLine }
		
		return http.makeRequest(httpRequest)
	else
		return nil, string.format("auth not needed: %s %s %s", httpResponse.statCode, httpResponse.statMsg, httpResponse.protocol)
	end
end

---------------- End of function defines ----------------

return http
