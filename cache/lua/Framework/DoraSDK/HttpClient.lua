


local callbackMap = {}

--- 通过sdk发送异步http请求
--- @param method string (GET, POST, DELETE, PUT)
--- @param timeout number 超时时间，单位秒
--- @param host string 远端地址或者域名
--- @param port number 远端端口
--- @param path string 请求路径
--- @param body string 请求的body，只有 POST 或者 PUT可以带body
--- @param isSSL boolean 是否是https请求
--- @param headers table{string: string}
--- @param callback function http请求回调  function callback(errorStr, httpCode, responseHeader, body) end
---                                             如果http请求成功，errorStr为nil，否则为错误信息
function HttpRequest(method, timeout, host, port, path, body, isSSL, headers, callback) 
    local requestId = _script.generator_uuid()
    callbackMap[requestId] = callback
    _script.HttpRequest(method, timeout, host, port, path, body, isSSL, requestId, headers)
end


--- sdk http回调
--- @param errStr string 如果http请求失败，返回失败信息，http成功的话errStr为nil
--- @param httpCode number 如果请求成功，那么返回http response code，否则为0
--- @param headers table{string, string} http response header
--- @param body string
local function SDKHttpCallback(errStr, httpCode, headers, body, requestId) 
    local callback = callbackMap[requestId]
    callbackMap[requestId] = nil
    if callback then
        callback(errStr, httpCode, headers, body)
    end
end

_script["SDKHttpCallback"] = SDKHttpCallback
