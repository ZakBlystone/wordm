module("mapedit", package.seeall)

MAPEDIT_GETIDS = 0
MAPEDIT_APPLY = 1
MAPEDIT_BITS = 2

-- simple compression for transmitting entity ids over the network

function EncodeDeltas(t)

	local o = {}
	for k,v in ipairs(t) do
		o[#o+1] = k > 1 and v - t[k-1] or v
	end
	return o

end

function DecodeDeltas(t)

	local o,r = {}, 0
	for k,v in ipairs(t) do
		r = k == 1 and v or r + v
		o[#o+1] = k == 1 and v or r
	end
	return o

end

function EncodeRLE(t)

	local rle, num, val = {}, 0, nil
	local function emit(v)
		if num == 0 then return end
		rle[#rle+1] = bit.bor(bit.lshift(num, 16), bit.band(val+0x7FFF, 0xFFFF))
	end

	for k,v in ipairs(t) do
		if v ~= val then emit() end
		num = v ~= val and 1 or num+1
		val = v == val and val or v
	end
	emit()

	return rle

end

function DecodeRLE(t)

	local o = {}
	for k,v in ipairs(t) do
		local val = bit.band(v, 0xFFFF)-0x7FFF
		for i=1, bit.rshift(v, 16) do o[#o+1] = val end
	end
	return o

end

function EncodeIDList(t)

	return EncodeRLE(EncodeDeltas(t))

end

function DecodeIDList(t)

	return DecodeDeltas(DecodeRLE(t))

end