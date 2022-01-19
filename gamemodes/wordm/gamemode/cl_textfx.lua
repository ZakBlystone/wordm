module("textfx", package.seeall)

local VMatrix = FindMetaTable("VMatrix")
local surface_setFont = surface.SetFont
local surface_setDrawColor = surface.SetDrawColor
local surface_setTextPos = surface.SetTextPos
local surface_setTextColor = surface.SetTextColor
local surface_getTextSize = surface.GetTextSize
local surface_drawText = surface.DrawText
local surface_drawRect = surface.DrawRect
local surface_drawOutlinedRect = surface.DrawOutlinedRect
local mtx_set = VMatrix.SetUnpacked
local cam_push = cam.PushModelMatrix
local cam_pop = cam.PopModelMatrix
local rad = math.pi / 180
local cos = math.cos
local sin = math.sin

local __scratchMatrix = Matrix()
local __pushedMatrix = false
local function PushMtx23(a0,a1,a2,b0,b1,b2)

	mtx_set( __scratchMatrix, 
		a0, a1, 0, a2,
		b0, b1, 0, b2,
		0, 0, 1, 0,
		0, 0, 0, 1 )

	cam_push( __scratchMatrix )
	__pushedMatrix = true

end

local function PopMtx()

	if __pushedMatrix then cam_pop() end
	__pushedMatrix = false

end

function MakeTiles( str, font )

	surface_setFont( font )

	local tiles = {}
	local tw, th = surface_getTextSize(str)

	local advance = 0
	for i=1, #str do

		local ch = str[i]
		local w,h = surface_getTextSize(ch)
		if str[i] ~= " " then
			local t = {
				x = advance + w/2,
				w = w/2, -- half-width
				h = h/2, -- half-height
				ch = ch,
			}
			if #tiles == 0 then
				t.tw = tw
				t.th = th
				t.font = font
			end
			tiles[#tiles+1] = t
		end

		advance = advance + w

	end

	return tiles

end

function TileForm(tile, x, y, r, sx, sy)

	x = x or 0
	y = y or 0
	r = r or 0
	sx = sx or 1
	sy = sy or 1

	local c = cos(r * rad)
	local s = sin(r * rad)

	local a0 = sx * c
	local a1 = sy * s
	local a2 = x - c * tile.w * sx - s * tile.h * sy
	local b0 = sx * -s
	local b1 = sy * c
	local b2 = y + s * tile.w * sx - c * tile.h * sy

	return a0, a1, a2, b0, b1, b2

end

function LayoutLeft( tiles, x, y )

	local out = {}

	local tw = tiles[1].tw
	local th = tiles[1].th
	for _, v in ipairs(tiles) do

		out[#out+1] = {
			t = v,
			x = x + v.x,
			y = y,
			r = 0,
			sx = 1,
			sy = 1,
			a = 1,
		}

	end

	return out

end

function LayoutRight( tiles, x, y )

	local out = {}

	local tw = tiles[1].tw
	local th = tiles[1].th
	for _, v in ipairs(tiles) do

		out[#out+1] = {
			t = v,
			x = x + v.x - tw,
			y = y,
			r = 0,
			sx = 1,
			sy = 1,
			a = 1,
		}

	end

	return out

end

function LayoutCentered( tiles, x, y )

	local out = {}

	local tw = tiles[1].tw
	local th = tiles[1].th
	for _, v in ipairs(tiles) do

		out[#out+1] = {
			t = v,
			x = x + v.x - tw * .5,
			y = y,
			r = 0,
			sx = 1,
			sy = 1,
			a = 1,
		}

	end

	return out

end

function DrawLayout(layout)

	surface_setFont( layout[1].t.font )

	render.PushFilterMag( TEXFILTER.ANISOTROPIC )
	render.PushFilterMin( TEXFILTER.ANISOTROPIC )

	for k,v in ipairs(layout) do

		PushMtx23( TileForm(v.t,v.x,v.y,v.r,v.sx,v.sy) )

		surface_setTextColor(v.cr or 255,v.cg or 255,v.cb or 255,255*v.a)
		surface_setTextPos( 0, 0 ) 
		surface_drawText( v.t.ch )

		--surface_drawOutlinedRect( 0, 0, v.w*2, v.h*2 )

		PopMtx()

	end

	render.PopFilterMag()
	render.PopFilterMin()

end

--[[
local layout = Centered(tiles, ScrW()/2, ScrH()/2)

local function Anim_Snap(layout)

	local t = -2
	local d = 0.5
	local start = table.Copy(layout)

	for _,v in ipairs(start) do
		v.x = v.x + math.Rand(-180,180)*4
		v.y = v.y + math.Rand(-180,180)*4 + 400
		v.r = math.Rand(-360,360) * 2
		v.sy = .4
		v.sx = .4
		v.a = 0
	end

	local scratch = table.Copy(start)

	return function()

		t = math.min(t + FrameTime() * d, 1)

		for i=1, #scratch do

			local lt = math.max(math.min(t+(i/#scratch), 1),0)

			local s = start[i]
			local f = layout[i]
			local c = scratch[i]

			local l = math.sin((1-lt) * math.pi/2)
			c.x = s.x * (1-l) + f.x * l
			c.y = s.y * (1-l) + f.y * l
			c.r = s.r * (1-l) + f.r * l
			c.a = s.a * (1-l) + f.a * l
			c.sx = s.sx * (1-l) + f.sx * l
			c.sy = s.sy * (1-l) + f.sy * l

		end

		if t == 1 then return true end
		return false

	end, scratch

end

local snap_f, snap_l = Anim_Snap(layout)

hook.Add("HUDPaint", "textfx", function()

	surface_setFont( "BigFont" )
	surface_setTextColor(255,255,255)
	surface_setDrawColor(255,255,255)

	snap_f()

	render.PushFilterMag( TEXFILTER.ANISOTROPIC )
	render.PushFilterMin( TEXFILTER.ANISOTROPIC )

	for y=0, 0 do

		for k,v in ipairs(snap_l) do

			PushMtx23( TileForm(v.t,v.x,v.y,v.r,v.sx,v.sy) )

			surface_setTextColor(255,255,255,255*v.a)
			surface_setTextPos( 0, 0 ) 
			surface_drawText( v.t.ch )

			--surface_drawOutlinedRect( 0, 0, v.w*2, v.h*2 )

			PopMtx()

		end

	end

	render.PopFilterMag()
	render.PopFilterMin()

	--surface.DrawOutlinedRect( 0, 100-tiles[1].th/2, tiles[1].tw, tiles[1].th )

end)
]]

print("TEXTFX")