include "shared.lua"

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

surface.CreateFont( "WordScoreTotalFont", {
	font = "Akkurat-Bold",
	extended = false,
	size = 52,
	weight = 0,
	blursize = 0,
} )

surface.CreateFont( "GameStateTitle", {
	font = "Akkurat-Bold",
	extended = false,
	size = 52,
	weight = 0,
	blursize = 0,
} )

surface.CreateFont( "GameStateSubTitle", {
	font = "Akkurat-Bold",
	extended = false,
	size = 32,
	weight = 0,
	blursize = 0,
} )

surface.CreateFont( "HelpTitle", { font = "Roboto", size = 72, weight = 1000, antialias = true, } )
surface.CreateFont( "HelpSubTitle", { font = "Roboto", size = 30, weight = 500, antialias = true, } )
surface.CreateFont( "HelpDetails", { font = "Tahoma", size = 20, weight = 800, antialias = true, } )
surface.CreateFont( "HelpRow", { font = "Tahoma", size = 18, weight = 1000, antialias = true, } )

net.Receive("wordscore_msg", function(len)

	print("RECV WORDSCORE : " .. len)

	local time = net.ReadFloat()
	local ply = net.ReadEntity()
	local pos = net.ReadVector()
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

	local ge = GAMEMODE:GetGameEntity()
	if IsValid(ge) and ply ~= LocalPlayer() and ge:GetGameState() == GAMESTATE_PLAYING then

		GAMEMODE:AddPlayerPing(ply, pos)

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

		if not v:Alive() or not v:IsPlaying() then

			v:ClearPhrases()

		end
	end

	self:ChatThink()
	self:CooldownThink()
	wordm_mapedit.Think()
	--self:UpdateFiredWords()

end

function GM:PostDrawOpaqueRenderables()

	surface.SetFont( "WordAmmoFont" )
	self:DrawFiredWords()
	wordm_mapedit.DrawEditWorld()


end

function GM:GetWordColor(score, flags)

	local r,g,b = 255,255,255

	--if true then return math.random(0,255), math.random(0,255), math.random(0,255) end

	local h = 60 + math.floor(score/5)*20
	h = math.min(h, 340)
	r,g,b = math.HSVToRGB( h, 0.8, 255 )

	if bit.band(flags, WORD_VALID) == 0 then
		r,g,b = 0,0,0
	else
		if bit.band(flags, WORD_COOLDOWN) ~= 0 then
			r,g,b = 255,255,255
		end
		if bit.band(flags, WORD_DUPLICATE) ~= 0 then
			r = r / 2
			g = g / 2
			b = b / 2
		end
	end
	return r,g,b

end

function GM:HUDPaint()

	local ge = self:GetGameEntity()
	if not IsValid(ge) then return end

	local gamestate = ge:GetGameState()

	self:DrawGameState()

	wordm_mapedit.DrawEditUI()

	if self:IsChatOpen() then
		self:DrawChat()
	end

	if gamestate ~= GAMESTATE_IDLE then

		self:DrawCooldowns()
		self:DrawPhrases()
		self:DrawPings()

	else

		local readyPlayers = self:GetAllPlayers(PLAYER_READY)
		if #readyPlayers > 0 then
			self:DrawReadyPlayers()
		end

	end

	if gamestate == GAMESTATE_WAITING then

		self:DrawReadyPlayers()

	end

	self:DrawHelp()

	--draw.SimpleText( "State Flags: " .. tostring( LocalPlayer():GetCurrentState() ), "DermaDefault", 300, 300 )

	if LocalPlayer():IsPlaying() then

		self:DrawHealthBars()

	end

	self:DrawDeathCards()

end

function GM:PlayerBindPress( ply, bind, pressed, code )

	if wordm_mapedit.BindPress( bind, pressed, code ) then
		return true
	end

	if self:IsChatOpen() and pressed then
		return true
	end

	if self:ShouldOverrideChat() then

		if bind == "messagemode" or bind == "messagemode2" then

			if pressed then 
				self:ToggleChat() 
			else
				self:FocusChat()
			end
			return true

		end

	end

end

function GM:SubmitPhrase( str )

	net.Start("wordsubmit_msg")
	net.WriteString(str)
	net.SendToServer()

end

function GM:ShowHelp() self.bShowingHelp = not self.bShowingHelp end
function GM:ShowTeam()

	self:OpenPlayerEditor()

end

function GM:ShowSpare1()

	if concommand.GetTable()["outfitter"] then
		LocalPlayer():ConCommand("outfitter")
	end

end

function GM:HUDShouldDraw( element )

	if element == "CHudDamageIndicator" then return LocalPlayer():Alive() end
	return true 

end

function GM:ClearTemporaryUI()

	self:ClearPings()
	self:ClearCooldowns()
	self:ClearPhraseScores()
	self:ClearChatBuffers()

end

-- Some addon has this, dunno why, removing it
hook.Remove( "PlayerBindPress", "webbrowser" )