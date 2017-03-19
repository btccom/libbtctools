
---------------- Test codes ----------------

local httpReq = [[
GET /0.php HTTP/1.1
Host: localhost
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:52.0) Gecko/20100101 Firefox/52.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.8,en-US;q=0.5,en;q=0.3
Accept-Encoding: gzip, deflate
Connection: keep-alive
Upgrade-Insecure-Requests: 1

]]

local httpRes = [[
HTTP/1.1 401 Unauthorized
Date: Sun, 19 Mar 2017 06:50:22 GMT
Server: Apache/2.4.23 (Win64) PHP/7.0.10
X-Powered-By: PHP/7.0.10
WWW-Authenticate: Digest realm="Restricted area" qop="auth" nonce="58ce2a2e9c7a9" opaque="cdce8a5c95a1427d74df7acbf41c9ce0"
Content-Length: 39
Keep-Alive: timeout=5, max=100
Connection: Keep-Alive
Content-Type: text/html; charset=UTF-8

]]

local res = http.parseRequest(string.gsub(httpReq, "\n", "\r\n"))
local req = http.parseResponse(string.gsub(httpRes, "\n", "\r\n"))

local auth, err = make_digest_request(res, req, "root", "root")

print (auth, err)

