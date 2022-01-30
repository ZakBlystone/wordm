module("wordm_phrasescore", package.seeall)

G_TEMP_PHRASESCORE = nil
G_ALL_PHRASESCORES = G_ALL_PHRASESCORES or {}
G_WORDSCORE_HISTORY_TIME = 30
G_WORDSCORE_HISTORY_MAX = 5

local meta = {}
meta.__index = meta

function meta:Init()

	self.time = 0
	self.eval = {}
	self.finished = false

	return self

end

function meta:Draw( x, y, small, mulAlpha )

	if self.done then return 0,0 end

	local fast = false
	local sc = self.score
	local time = 0
	local alpha = 1 * (mulAlpha or 1)
	local total = 0
	local totalx = 10

	--small = true

	local mainFont = small and "WordScoreFont" or "WordAmmoFont"
	local totalFont = small and "DermaLarge" or "WordScoreTotalFont"
	local scoreFont = small and "Default" or "WordScoreFont"
	local nameFont = "WordAmmoFont"
	local centered = not small

	self.time = self.time + FrameTime()

	if not small then

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

			alpha = math.max(1.2 - self.time, 0)

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

	surface.SetFont(totalFont)

	local ttx = self.time * 2 * (#sc.words + 1)
	for k, w in ipairs(sc.words) do
		if ttx > k then total = total + w.score end
	end

	local totalw = surface.GetTextSize("[" .. total .. "]")
	total = 0

	surface.SetFont(mainFont)
	surface.SetTextColor(255,255,255,255*alpha)

	local str = sc.phrase
	local tw,th = surface.GetTextSize( str )
	if centered then
		x = x - tw/2
		y = y - th/2
	end

	local padding = 5
	local finalw, finalh = tw + totalw + totalx, th + (small and 10 or 20)
	local extraw = 0

	local namestr
	if small then
		namestr = (IsValid(self.ply) and self.ply:Nick() or "") .. ": "

		if not self.sanitizedName then
			self.sanitizedName = SanitizeToAscii(namestr)
		end
		namestr = self.sanitizedName

		surface.SetFont(nameFont)
		
		extraw = surface.GetTextSize(namestr)

		finalw = finalw + extraw
	end

	x = x + padding
	y = y + padding

	finalw = finalw + padding*2
	finalh = finalh + padding*2

	if not small then
		surface.SetDrawColor(0,0,0,150 * alpha)
	else
		surface.SetDrawColor(0,0,0,80 * alpha)
	end
	surface.DrawRect(x-padding,y-padding,finalw,finalh)

	if small then
		surface.SetTextPos(x, y)
		surface.DrawText(namestr)
		x = x + extraw
	end

	if #sc.words > 8 then fast = true end
	for k, w in ipairs(sc.words) do

		local eval = ttx > k
		local cr,cg,cb = GAMEMODE:GetWordColor(w.score, w.flags)
		
		if not eval then
			cr,cg,cb = 255,255,255
		else
			if not self.eval[k] then
				if not small then
					if fast and k ~= #sc.words then
						LocalPlayer():EmitSound("wordm/word_eval2.wav", 75, 100 - (w.score or 25) * 2)
						--surface.PlaySound("wordm/word_eval2.wav")
					else
						LocalPlayer():EmitSound("wordm/word_eval.wav", 75, 100 - (w.score or 25) * 2)
						--surface.PlaySound("wordm/word_eval.wav")
					end
				end
				if k == #sc.words then self.evaldone = true end
				self.eval[k] = true
			end

			total = total + w.score
		end

		surface.SetTextColor(cr,cg,cb,255*alpha)
		surface.SetFont(mainFont)
		local wstr = sc.phrase:sub(w.first, w.last)
		local ww, wh = surface.GetTextSize(wstr)
		surface.SetTextPos(x, y)
		surface.DrawText( wstr )

		if eval then
			local b = small and y + 20 or y + 30
			local d = small and 4 or 8
			surface.SetDrawColor(cr,cg,cb,255*alpha)
			surface.DrawLine(x-1, b, x-1, b + d)
			surface.DrawLine(x+1+ww, b, x+1+ww, b + d)
			surface.DrawLine(x-1, b + d, x+ww+1, b + d)

			surface.SetFont(scoreFont)
			local sct = tostring(w.score)
			local scw, sch = surface.GetTextSize(sct)
			surface.SetTextPos(x+(ww-scw)/2, b+d)
			surface.DrawText(sct)
		end

		x = x + ww

		local n = sc.words[next(sc.words, k)]
		local nf = n and n.first or string.len(sc.phrase)+1
		if nf > w.last + 1 then

			surface.SetFont(mainFont)
			local wstr = sc.phrase:sub(w.last+1, nf-1)
			local ww, wh = surface.GetTextSize(wstr)
			surface.SetTextColor(cr,cg,cb,80*alpha)
			surface.SetTextPos(x, y)
			surface.DrawText( wstr )
			x = x + ww

		end

	end

	surface.SetFont(totalFont)
	surface.SetTextPos(x + totalx, y)
	surface.SetTextColor(255,255,255,255 * alpha)
	surface.DrawText("[" .. total .. "]")

	return finalw, finalh

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

function GM:DrawPhrases()

	if G_TEMP_PHRASESCORE then
		G_TEMP_PHRASESCORE:Draw( ScrW()/2, ScrH()/2 - 100, false )
	end

	while #G_ALL_PHRASESCORES > 0 and (G_ALL_PHRASESCORES[1].time > G_WORDSCORE_HISTORY_TIME or #G_ALL_PHRASESCORES > G_WORDSCORE_HISTORY_MAX) do
		table.remove(G_ALL_PHRASESCORES, 1)
	end

	local y = 0
	for i=1, #G_ALL_PHRASESCORES do
		local p = G_ALL_PHRASESCORES[i]
		local tx = math.max(p.time - (G_WORDSCORE_HISTORY_TIME-1), 0)
		local fade = math.max(math.min(p.time-1, 1), 0)
		local fadex = 1 - fade * .5

		local w,h = p:Draw(10, 10 + y, true, (1 - tx) * 0.8 * fadex)
		y = y + (h or 0) + 5
	end

end

function GM:ShowPhraseScore( ply, phrase )

	if phrase == nil or #phrase.words == 0 then return end

	if ply == LocalPlayer() then
		surface.PlaySound("wordm/word_place.wav")
		G_TEMP_PHRASESCORE = wordm_phrasescore.New( ply, phrase )
		G_ALL_PHRASESCORES[#G_ALL_PHRASESCORES+1] = wordm_phrasescore.New( ply, phrase )
	else
		surface.PlaySound("wordm/word_place2.wav")
		G_ALL_PHRASESCORES[#G_ALL_PHRASESCORES+1] = wordm_phrasescore.New( ply, phrase )
	end

end

function GM:ClearPhraseScores()

	G_ALL_PHRASESCORES = {}
	G_TEMP_PHRASESCORE = nil

end