module("phrasescore", package.seeall)

local meta = {}
meta.__index = meta

function meta:Init()

	self.time = 0
	self.eval = {}
	self.finished = false
	return self

end

function meta:Draw( x, y, centered, mulAlpha, noanim )

	if self.done then return end

	local fast = false
	local sc = self.score
	local time = 0
	local alpha = 1 * (mulAlpha or 1)

	y = y - 100

	self.time = self.time + FrameTime()

	if not noanim then

		if self.time >= 1 then
			if not self.finished then
				local tx, ty = unpack(G_WEAPON_PHRASE_LOC or {0,0})

				surface.PlaySound("wordm/word_snap.wav")
				self.finished = true

				self.tiles = textfx.MakeTiles( sc.phrase, "WordAmmoFont" )
				self.layout = textfx.LayoutCentered( self.tiles, x, y )
				self.tlayout = textfx.LayoutRight( self.tiles, tx, ty )

				for k, e in ipairs(self.layout) do
					local tg = self.tlayout[k]
					e.vx = (tg.x - e.x) * 10 + math.Rand(-50,50)
					e.vy = (tg.y - e.y) * 10 + math.Rand(-50,50)
					e.spd = 0
				end
			end
		end

		
		if self.finished then

			alpha = 1 - self.time

			local dt = FrameTime()
			for k, e in ipairs(self.layout) do
				local tg = self.tlayout[k]
				e.x = e.x + e.vx * dt * e.spd
				e.y = e.y + e.vy * dt * e.spd
				e.spd = e.spd + math.Rand(1,7) * dt
				e.a = math.max(e.a - dt * 5, 0)
			end

			textfx.DrawLayout( self.layout )

			if self.time >= 2 then self.done = true end

		end

	end


	surface.SetFont("WordAmmoFont")

	local spw = surface.GetTextSize(" ")

	surface.SetTextColor(255,255,255,255*alpha)

	local str = sc.phrase
	local tw,th = surface.GetTextSize( str )
	if centered then
		x = x - tw/2
		y = y - th/2
	end

	--surface.SetTextColor(255,255,255,100*alpha)
	--surface.SetTextPos(x, y-50)
	--surface.DrawText( sc.phrase )

	if #sc.words > 8 then
		fast = true
	end

	local ttx = self.time * 2 * (#sc.words + 1)
	for k, w in ipairs(sc.words) do

		local eval = ttx > k
		local cr,cg,cb = GAMEMODE:GetWordColor(w)
		
		if not eval then
			cr,cg,cb = 255,255,255
		else
			if not self.eval[k] then
				if not noanim then
					if fast and k ~= #sc.words then
						surface.PlaySound("wordm/word_eval2.wav")
					else
						surface.PlaySound("wordm/word_eval.wav")
					end
				end
				if k == #sc.words then self.evaldone = true end
				self.eval[k] = true
			end
		end

		surface.SetTextColor(cr,cg,cb,255*alpha)
		surface.SetFont("WordAmmoFont")
		local wstr = sc.phrase:sub(w.first, w.last)
		local ww, wh = surface.GetTextSize(wstr)
		surface.SetTextPos(x, y)
		surface.DrawText( wstr )

		if eval then
			local b = y + 30
			local d = 8
			surface.SetDrawColor(cr,cg,cb,255*alpha)
			surface.DrawLine(x-1, b, x-1, b + d)
			surface.DrawLine(x+1+ww, b, x+1+ww, b + d)
			surface.DrawLine(x-1, b + d, x+ww+1, b + d)

			surface.SetFont("WordScoreFont")
			local sct = tostring(w.score)
			local scw, sch = surface.GetTextSize(sct)
			surface.SetTextPos(x+(ww-scw)/2, b+d)
			surface.DrawText(sct)
		end

		x = x + ww

		local n = sc.words[next(sc.words, k)]
		local nf = n and n.first or string.len(sc.phrase)+1
		if nf > w.last + 1 then

			surface.SetFont("WordAmmoFont")
			local wstr = sc.phrase:sub(w.last+1, nf-1)
			local ww, wh = surface.GetTextSize(wstr)
			surface.SetTextColor(cr,cg,cb,80*alpha)
			surface.SetTextPos(x, y)
			surface.DrawText( wstr )
			x = x + ww

		end

	end

end

function New( ply, score )

	return setmetatable({ ply = ply, score = score }, meta):Init()

end

if G_TEMP_PHRASESCORE then
	setmetatable(G_TEMP_PHRASESCORE, meta)
	G_TEMP_PHRASESCORE.time = -2
	G_TEMP_PHRASESCORE.eval = {}
	G_TEMP_PHRASESCORE.finished = false
	G_TEMP_PHRASESCORE.done = false
end