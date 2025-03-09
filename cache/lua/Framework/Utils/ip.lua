function splitaddr( addr )
	local _, _, ip, port, pipe = string.find( addr, "([^:]+):([^,]*)%,(.*)" )
	if ip then
		return ip, toint( port ), pipe
	end
	_, _, ip, port = string.find( addr, "([^:]+):(.*)" )
	--_yy( 'splitaddr----------------', ip, port )
	return ip, toint( port )
end

function ip2string(ip)
	local s = string.format('%08x',ip)
	local h1 = toint('0x'..string.sub(s,1,2))
	local h2 = toint('0x'..string.sub(s,3,4))
	local l1 = toint('0x'..string.sub(s,5,6))
	local l2 = toint('0x'..string.sub(s,7,8))
	return string.format('%s.%s.%s.%s',h1,h2,l1,l2)
end

function isip(addr)
	return string.find(addr, "%d+%.%d+%.%d+%.%d+%:%d+");
end

function _G.getIP( ip )
	ip = tonumber( ip )
	return ('%d.%d.%d.%d'):format(_rshift(ip,24), _rshift(ip,16)%256, _rshift(ip,8)%256, ip%256)
end

function str2ip( ip )
	ip = tonumber( ip )
	return ('%d.%d.%d.%d'):format(_rshift(ip,24), _rshift(ip,16)%256, _rshift(ip,8)%256, ip%256)
end

function toip( str )
	local _, _, n1, n2, n3, n4 = string.find( str, "(%d+)%.(%d+)%.(%d+)%.(%d+)" )
	return _lshift(n1, 24) + _lshift(n2, 16) + _lshift(n3, 8) + n4
end

local hostips
function bindHost( )
	if hostips then return end
	hostips = { }
	--[[local f = io.readall( 'host' )
	if not f then return end
	local lines = string.split( f, "\n" )
	for ii = 1, #lines do
		local line = lines[ii]:trim( )
		if not line:lead'#' then
			local ws = line:split( " " )
			if ws[1] then hostips[ws[1] ] = ws[2] end
		end
	end]]
end

function addHost( host, ip )
	if not host or not ip then return end
	if not isip( ip ) then return end
	hostips = hostips or { }
	hostips[host] = ip
end

local dnstimeout = 30 * 60 * 1000-- luacheck: ignore
local serIp = { }-- luacheck: ignore
function host2ip( host )
	if isip( host ) then return host end
	local port
	host, port = splitaddr( host )
	bindHost( )
	local tb = serIp[host]
    if not tb or ( _now( ) - tb[2] >= dnstimeout ) then
		local t = os.now( 0 )
		local ok, ip = xpcall( _host2ips, _G.CallBackError, host )
		Log.sys( "hostip", host, ip, os.now(0) - t )
		if not ok then
			-- report error and send email
			--[[local sendstr = Net.makePostStr('106.75.145.34:8088', '/item_er', {
				game = 'mofawangzuo',
				errortype = 'host2ip',
				host = host,
				servertype = os or os.info or os.info.servertype,
				serverid = os or os.info or os.info.server_id,
				debugtrace = debug.traceback()
			}, {data=1});]]

			--Net.httpConnect('106.75.145.34:8088', sendstr, function(...)
				--Log.sys('reporthost2ipOK', table.tostr({...}) )
			--end, function(...)
				--Log.sys('reporthost2ipFail', table.tostr({...}) )
			--end)

			serIp[host] = { nil, _now( ) -  dnstimeout*0.7 }
		else
			serIp[host] = { getIP( ip ), _now( ) }
		end
	end
	local ip = serIp[host][1]
	if not ip then
		if hostips[host] then return hostips[host]..":"..port end
		return
	else
		hostips[host] = ip
	end
    host = ( '%s:%s' ):format( ip, port )
	return host
end

function ClearHostCache( host )
	if host then --指定清
		serIp[host] = nil
	else--全清
		serIp = { }
	end
end
--yy('ip<<<<<<<<<<<<<<<<<<<<<<', toip( '10.1.33.238'), toip( '10.1.1.238'), str2ip( 167838190 ), toip( str2ip( 167838190 ) ),  167838190 )