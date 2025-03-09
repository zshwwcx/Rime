
-----------------------------------------------------------------------------
local bit = {}

local toint = math.floor

function bit.band(a, b)
	return(a & b)
end

function bit.bor(a, b)
	return(a | b)
end

function bit.lshift(a, b)
	return(a << b)
end

function bit.rshift(a, b)
	return(a >> b)
end

function bit.bnot(a)
	return(~a)
end

-- 位操作
function bit.bor54(a,b)
	local a1,a2=toint(a/(2^31)),a%(2^31)
	local b1,b2=toint(b/(2^31)),b%(2^31)
	a1 = bit.bor(a1,b1)
	a2 = bit.bor(a2,b2)
	return a1*2^31+a2
end

function bit.band54(a,b)
	local a1,a2=toint(a/(2^31)),a%(2^31)
	local b1,b2=toint(b/(2^31)),b%(2^31)
	a1 = bit.band(a1,b1)
	a2 = bit.band(a2,b2)
	return a1*2^31+a2
end

function bit.lshift54(a,b)
	return a*2^b
end

function bit.rshift54(a,b)
	return toint(a/2^b)
end

function bit.bxor54(a,b)
	local a1,a2=toint(a/(2^31)),a%(2^31)
	local b1,b2=toint(b/(2^31)),b%(2^31)
	a1 = bit.bxor(a1,b1)
	a2 = bit.bxor(a2,b2)
	return a1*2^31+a2
end

function bit.bnot54(a)
	local a1,a2=toint(a/(2^31)),a%(2^31)
	a1 = bit.bnot(a1)
	a2 = bit.bnot(a2)
	return a1*2^31+a2
end

function bit.setbit54(val,...)
	for i,v in next, {...} do
		val=bit.bor54(val,bit.lshift54(1,v-1))
	end	
	return val
end
function bit.clsbit54(val,...)
	for i,v in next, {...} do
		val=bit.band54(val,bit.bnot54(bit.lshift54(1,v-1)))
	end	
	return val
end
function bit.chkbit54(val,b)
	if bit.band54(val,bit.lshift54(1,b-1)) == 0 then
		return false
	else
		return true
	end
end
function bit.cal1bit54(val)
	local cnt = 0
	while val>0 do
		val = bit.band54(val,val-1)
		cnt = cnt + 1
	end
	return cnt
end

function bit.binaryfind(val, minn, maxn)
	local bitn=maxn-minn+1;
	val=bit.rshift54(val, minn-1)
	local lown=toint(bitn/2)
	if lown<=0 then
		assert( bit.band( val, 1 ) == 0 )
		return minn
	end
	local bitlow=2^lown - 1
	if bit.band(val, bitlow)~=bitlow then return bit.binaryfind(val, 1, lown)+minn-1 end

	return bit.binaryfind(bit.rshift54(val, lown), 1, bitn-lown)+lown+minn-1
end

function bit.findbit(val, minn)
	if val==0 then return minn; end
	if val==2^53 then return; end
	return bit.binaryfind(val, minn or 1, 53)
end

function bit.findbita(a, minn)
	minn=minn or 1
	local n1=toint(minn/53)
	local n2=minn-53*n1
	for i=n1+1,#a do
		---local val=a[i]
		local n=bit.findbit(a[i], math.min(1, n2-(i-n1-1)*53))
		if n then return n+(i-1)*53 end
	end
end
function bit.setbita(vals,...)
	for i,v in next, {...} do
		local j,b = math.ceil(v/53),v%53
		local val = vals[j]
		b = b==0 and 53 or b
		vals[j] = bit.bor54(val,bit.lshift54(1,b-1))
	end
	return vals
end
function bit.clsbita(vals,...)
	for i,v in next, {...} do
		local j,b = math.ceil(v/53),v%53
		local val = vals[j]
		b = b==0 and 53 or b
		vals[j] = bit.band54(val,bit.bnot54(bit.lshift54(1,b-1)))
	end
	return vals
end
function bit.chkbita(vals,b)
	if b > #vals*53 then return false; end
	local j,a = math.ceil(b/53),b%53
	a = a==0 and 53 or a
	if bit.band54(vals[j],bit.lshift54(1,a-1)) == 0 then
		return false
	else
		return true
	end
end
function bit.banda(a,b)
	local ret={}
	for i=1,#a do
		ret[i] = bit.band54(a[i],b[i])
	end
	return ret
end
function bit.bora(a,b)
	local ret={}
	for i=1,#a do
		ret[i] = bit.bor54(a[i],b[i])
	end
	return ret
end
function bit.cal1bita(a)
	local cnt = 0
	for _,v in next, a do
		cnt = cnt+bit.cal1bit54(v)
	end
	return cnt
end
function bit.cmpbita(a,b)
	assert(#a==#b,'bit.cmpbita: 2 parameters have different length')
	local diff={}
	for i=1, #a do
		local d = bit.bxor54(a[i],b[i])
		if d~=0 then
			for j=1,53 do
				if bit.chkbit54(d,j) then table.insert(diff,(i-1)*53+j) end
			end
		end
	end
	return diff
end

function bit.cmpbit(a, b)
	local d = bit.bxor54(a, b)
	local diff={};
	if d~=0 then
		for j=1,53 do
			if bit.chkbit54(d,j) then table.insert(diff, j) end
		end
	end
	return diff
end

function bit.outbit(val)	
	if val < 2 then return end
	local a = val	
	local s = ''
	local b = 0
	while(a>0)
	do		
		b = toint(a%2)
		s = s..b
		a = bit.rshift54(a,1)		
	end	
	_lpf('=============bit==========='..string.reverse(s))
	return s
end

return bit