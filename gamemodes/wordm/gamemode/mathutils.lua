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