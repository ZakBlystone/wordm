module("math", package.seeall)

local fmax = math.max
local fmin = math.min
function IntersectRayBox(origin, dir, min, max)

	local x0,y0,z0 = min:Unpack()
	local x1,y1,z1 = max:Unpack()
	local ox,oy,oz = origin:Unpack()
	local dx,dy,dz = dir:Unpack()

	dx = 1/dx
	dy = 1/dy
	dz = 1/dz

	local t0 = (x0 - ox) * dx
	local t1 = (x1 - ox) * dx
	local t2 = (y0 - oy) * dy
	local t3 = (y1 - oy) * dy
	local t4 = (z0 - oz) * dz
	local t5 = (z1 - oz) * dz

	local tmin = 
	fmax(
		fmax(
			fmin(t0,t1),
			fmin(t2,t3)
		),
		fmin(t4,t5)
	)

	local tmax = 
	fmin(
		fmin(
			fmax(t0,t1),
			fmax(t2,t3)
		),
		fmax(t4,t5)
	)

	if tmax < 0 then return false end
	if tmin > tmax then return false end

	return true, tmin

end

local vsub = Vector()
function IntersectRayPlane(origin, dir, plane_origin, plane_normal)

	vsub:Set(plane_origin)
	vsub:Sub(origin)
	local a = vsub:Dot( plane_normal )
	local b = dir:Dot( plane_normal )

	if b ~= 0 then

		local t = a / b
		return t

	else

		return math.huge

	end

end

local _permut = {
	function(a,b,c) return a,b,c end,
	function(a,b,c) return b,a,c end,
	function(a,b,c) return c,a,b end,
	function(a,b,c) return c,b,a end,
	function(a,b,c) return b,c,a end,
	function(a,b,c) return a,c,b end,
}

function HSVToRGB(h,s,v)

	h = h % 360 / 60
	local x = v * s * math.abs(h % 2 - 1)
	return _permut[1+math.floor(h)](v,v-x,v-v*s)

end

local function fit(x)
	return 1 - 0.5*x + 0.1665831*x^2 - 0.04136174*x^3 + 0.007783141*x^4 - 0.0008936082*x^5
end

function Bouncer( t, decay, fdecay, speed, upshot )

	decay = decay or 0.9
	speed = speed or 0.2
	fdecay = fdecay or 0.35

	local coef = 1/fit(fdecay)

	if upshot then t = t + speed / 2 end
	local root = speed / (speed - fdecay * t / coef)

	if root < 0 then return 0, 0 end

	local i = math.floor(math.log(root) * (1/fdecay))
	local duration = speed / math.exp( i * fdecay )
	local offset = coef * (speed - speed * math.exp( -i * fdecay )) / fdecay
	local amplitude = 1 / math.exp(i * decay)

	t = t * ( 1 / duration )
	t = t - ( offset / duration )
	return t * ( 1 - t ) * 4 * amplitude, i

end