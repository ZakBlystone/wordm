include "shared.lua"
include "cl_textfx.lua"
include "cl_chat.lua"
include "cl_phrasescore.lua"

G_WORD_COOLDOWNS = G_WORD_COOLDOWNS or {}

surface.CreateFont( "WordAmmoFont", {
	font = "Akkurat-Bold",
	extended = false,
	size = 38,
	weight = 1000,
	blursize = 0,
} )

surface.CreateFont( "CooldownWordFont", {
	font = "Akkurat-Bold",
	extended = false,
	size = 22,
	weight = 0,
	blursize = 0,
} )

surface.CreateFont( "WordScoreFont", {
	font = "Akkurat-Bold",
	extended = false,
	size = 25,
	weight = 0,
	blursize = 0,
} )

net.Receive("wordscore_msg", function(len)

	print("RECV WORDSCORE : " .. len)

	local time = net.ReadFloat()
	local ply = net.ReadEntity()
	local phrase = RecvPhraseScore()

	ply.pendingPhrase = phrase
	ply.pendingPhraseTime = CurTime() + TIME_TO_PHRASE

	net.Start("wordscore_msg")
	net.WriteFloat( CurTime() + TIME_TO_PHRASE )
	net.SendToServer()

	for _,w in ipairs(phrase.words) do
		if w.cooldown then
			GAMEMODE:PostWordCooldown( ply, phrase.phrase:sub(w.first, w.last), w.cooldown )
		end
	end

	GAMEMODE:ShowPhraseScore( ply, phrase )

	--PrintTable(phrase)

end)

function GM:Think()

	for _,v in ipairs(player.GetAll()) do
		if v.pendingPhrase and v.pendingPhraseTime and v.pendingPhraseTime < CurTime() then
			self:HandlePlayerPhraseSynced(v, v.pendingPhrase)
			v.pendingPhrase = nil
			v.pendingPhraseTime = nil
		end
	end

	self:ChatThink()
	self:CooldownThink()
	--self:UpdateFiredWords()

end

function GM:PostDrawOpaqueRenderables()

	surface.SetFont( "WordAmmoFont" )
	self:DrawFiredWords()


end

function GM:GetWordColor(word)

	local r,g,b = 255,255,255

	if bit.band(word.flags, WORD_VALID) == 0 then
		r,g,b = 255,100,100
	else
		if bit.band(word.flags, WORD_COOLDOWN) ~= 0 then
			r,g,b = 60,60,128
		end
		if bit.band(word.flags, WORD_DUPLICATE) ~= 0 then
			b = 0
		end
	end
	return r,g,b

end

function GM:HUDPaint()

	if self:IsChatOpen() then
		self:DrawChat()
	end

	self:DrawCooldowns()

	if G_TEMP_PHRASESCORE then
		G_TEMP_PHRASESCORE:Draw( ScrW()/2, ScrH()/2, true )
	end

end

function GM:PlayerBindPress( ply, bind, pressed, code )

	if self:IsChatOpen() and pressed then
		return true
	end

	if bind == "messagemode" or bind == "messagemode2" then

		if pressed then 
			self:ToggleChat() 
		else
			self:FocusChat()
		end
		return true

	end

end

function GM:PostWordCooldown( ply, str, cooldown )

	for _,v in ipairs(G_WORD_COOLDOWNS) do

		if v.str == str then
			v.time = cooldown
			return
		end

	end

	G_WORD_COOLDOWNS[#G_WORD_COOLDOWNS+1] = {
		time = cooldown,
		str = str,
		ply = ply,
	}

end

function GM:CooldownThink()

	for i=#G_WORD_COOLDOWNS, 1, -1 do

		local c = G_WORD_COOLDOWNS[i]
		if c.time <= CurTime() then
			table.remove(G_WORD_COOLDOWNS, i)
		end

	end

end

function GM:DrawCooldowns()

	surface.SetFont("CooldownWordFont")

	for k, c in ipairs(G_WORD_COOLDOWNS) do

		local tx = math.max(c.time - CurTime(), 0) * 4
		local str = c.str
		local tw, th = surface.GetTextSize(str)
		local x, y = ScrW() - tw - 10, 10 + (k-1) * 28


		surface.SetTextColor(Color(255,180,180,100))
		surface.SetTextPos(x, y)
		surface.DrawText(str)

		surface.SetDrawColor(255,180,180,100)
		surface.DrawRect(x - tx - 10, y, tx, th)
	
	end

end

G_TEMP_PHRASESCORE = G_TEMP_PHRASESCORE or nil

function GM:ShowPhraseScore( ply, phrase )

	if ply == LocalPlayer() then
		surface.PlaySound("wordm/word_place.wav")
	else
		surface.PlaySound("wordm/word_place2.wav")
	end

	G_TEMP_PHRASESCORE = phrasescore.New( ply, phrase )

end