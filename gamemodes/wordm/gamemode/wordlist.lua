module("wordm_wordlist", package.seeall)

function GM:CheckWordListFS()

end

local pnames = function()

	local t,b,i,n,k = player.GetAll(), 0, 0, ""
	return function()

		::check::
		_,b,w = n:find( "([%w-']+)", b+1 )
		if w then i=i+1 return i,w else b = 0 end

		k, v = next(t, k)
		if not IsValid(v) then return end
		n = SanitizeToAscii( v:Nick() ):lower()
		goto check

	end

end