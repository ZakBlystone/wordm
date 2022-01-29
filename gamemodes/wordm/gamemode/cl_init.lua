include "shared.lua"
include "cl_textfx.lua"
include "cl_chat.lua"
include "cl_phrasescore.lua"
include "cl_mapedit.lua"
include "cl_playereditor.lua"

G_WORD_COOLDOWNS = G_WORD_COOLDOWNS or {}
G_PLAYER_PINGS = G_PLAYER_PINGS or {}
G_TEMP_PHRASESCORE = nil
G_ALL_PHRASESCORES = G_ALL_PHRASESCORES or {}
G_WORDSCORE_HISTORY_TIME = 30
G_WORDSCORE_HISTORY_MAX = 5

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

local _permut = {
	function(a,b,c) return a,b,c end,
	function(a,b,c) return b,a,c end,
	function(a,b,c) return c,a,b end,
	function(a,b,c) return c,b,a end,
	function(a,b,c) return b,c,a end,
	function(a,b,c) return a,c,b end,
}

local function rgb(h,s,v)

	h = h % 360 / 60
	local x = v * s * math.abs(h % 2 - 1)
	return _permut[1+math.floor(h)](v,v-x,v-v*s)

end

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

		G_PLAYER_PINGS[#G_PLAYER_PINGS+1] = {
			ply = ply,
			pos = pos + Vector(0,0,32),
			time = CurTime(),
			sanitized = SanitizeToAscii(ply:Nick())
		}

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
	self:ThinkMapEdit()
	--self:UpdateFiredWords()

end

function GM:PostDrawOpaqueRenderables()

	surface.SetFont( "WordAmmoFont" )
	self:DrawFiredWords()
	self:DrawMapEdit()


end

function GM:GetWordColor(score, flags)

	local r,g,b = 255,255,255

	--if true then return math.random(0,255), math.random(0,255), math.random(0,255) end

	local h = 60 + math.floor(score/5)*20
	h = math.min(h, 340)
	r,g,b = rgb( h, 0.8, 255 )

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

local gradient_mat = Material("vgui/gradient_down")

local function FormatTimeGood(t)

	local minutes = math.floor(t/60) % 60
	local seconds = math.floor(t) % 60
	local hundredths = math.floor(t*100) % 100
	return ("%02i:%02i.%02i"):format(minutes, seconds, hundredths)

end

local clickToJoinText = "Press '" .. input.LookupBinding("+reload"):upper() .. "' to join"

function GM:DrawGameState()

	local ge = self:GetGameEntity()
	if not IsValid(ge) then return end

	local title = nil
	local subtitle = nil
	local timer = nil
	local gamestate = ge:GetGameState()
	if gamestate == GAMESTATE_IDLE then

		title = "WAITING FOR PLAYERS"
		subtitle = clickToJoinText

		if LocalPlayer():IsReady() then
			subtitle = "You are READY, please wait for someone else"
		end

	elseif gamestate == GAMESTATE_WAITING then

		title = "STARTING"

		if LocalPlayer():IsReady() then
			subtitle = "You are READY, game starting..."
		else
			subtitle = clickToJoinText
		end

		timer = FormatTimeGood( ge:GetTimeRemaining() )

	elseif gamestate == GAMESTATE_COUNTDOWN then

		if LocalPlayer():IsPlaying() then

			title = "GET READY"
			subtitle = "You are invulnerable for a bit, type some sentences in chat quick!"

		else

			title = "GAME IS STARTING"
			subtitle = "Wait until the next game to join"

		end

		timer = FormatTimeGood( ge:GetTimeRemaining() )

	elseif gamestate == GAMESTATE_PLAYING then

		if not LocalPlayer():IsPlaying() then

			title = "YOU ARE SPECTATING"
			subtitle = "Wait until the next game to join"

		elseif LocalPlayer():Alive() == false then

			title = "YOU DIED"
			subtitle = "Wait until the round is over"

		end

	elseif gamestate == GAMESTATE_POSTGAME then

		title = "GAME OVER"

		local activeplayers = self:GetAllPlayers( PLAYER_PLAYING )
		local liveplayer = nil
		if #activeplayers > 0 then
			for _,v in ipairs(activeplayers) do
				if v:Alive() then liveplayer = v break end
			end
		end

		if IsValid(liveplayer) then
			subtitle = SanitizeToAscii( liveplayer:Nick() ) .. " IS THE WINNER!"
		else
			subtitle = "NOBODY WON! :("
		end

		timer = FormatTimeGood( ge:GetTimeRemaining() )

	end

	if title then

		surface.SetMaterial(gradient_mat)
		surface.SetDrawColor(0,0,0,200)
		surface.DrawTexturedRect(0,0,ScrW(),400)

		draw.SimpleText(title, "GameStateTitle", ScrW()/2,100, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	end

	if subtitle then
		
		draw.SimpleText(subtitle, "GameStateSubTitle", ScrW()/2,140, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	end

	if timer then

		draw.SimpleText(timer, "GameStateSubTitle", ScrW()/2,180, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	end

	if gamestate == GAMESTATE_IDLE then

		if not self.bShowingHelp then
			draw.SimpleText("Press " .. input.LookupBinding("gm_showhelp") .. " for help", "GameStateSubTitle", 30, 30, Color(255,255,255,255))
			--draw.SimpleText("Press Enter for regular chat", "GameStateSubTitle", 30, 60, Color(255,255,255,255))
		end

	end

end

function GM:HUDPaint()

	local ge = self:GetGameEntity()
	if not IsValid(ge) then return end

	local gamestate = ge:GetGameState()

	self:DrawGameState()
	self:DrawMapEditUI()

	if self:IsChatOpen() then
		self:DrawChat()
	end

	if gamestate ~= GAMESTATE_IDLE then

		self:DrawCooldowns()
		self:DrawPhrases()
		self:DrawPings()

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

function GM:DrawHealthBars()

	for _,v in ipairs( self:GetAllPlayers( PLAYER_PLAYING ) ) do

		local tr = util.TraceHull( {
			start = EyePos(),
			endpos = v:GetPos() + Vector(0,0,30),
			filter = LocalPlayer(),
			mins = Vector(-4,-4,-4),
			maxs = Vector(4,4,4),
		} )

		if tr.Hit and tr.Entity == v then

			local scr = (v:GetPos() + Vector(0,0,92)):ToScreen()
			if scr.visible then

				surface.SetFont("DermaLarge")
				local str = SanitizeToAscii(v:Nick())
				local tw, th = surface.GetTextSize(str)
				surface.SetTextColor(255,255,255,80)
				surface.SetTextPos( scr.x - tw/2, scr.y - th/2 - 10 )
				surface.DrawText( str )

				local hp = math.max(v:Health(), 0)/100

				surface.SetDrawColor(100,100,100,80)
				surface.DrawRect(scr.x-100,scr.y-10,200,20)

				surface.SetDrawColor(255,255,255,128)
				surface.DrawRect(scr.x-100,scr.y-5,200 * hp,10)

			end

		end

	end

end

function GM:DrawReadyPlayers()

	for k,v in ipairs(player.GetAll()) do

		local ready = v:IsReady()

		local name = textfx.Builder(SanitizeToAscii(v:Nick()), "WordAmmoFont"):Box(10,2):Color(190,255,100,255)
		:SetPos(10, ScrH()/4 + k * 50)
		local readytext = textfx.Builder(ready and "Ready" or "Not Ready", "CooldownWordFont"):Box(10,4)
		:HAlignTo(name, "after")
		:VAlignTo(name, "center")

		if ready then
			readytext:Color(120,255,120,255)
		else
			readytext:Color(255,120,120,255)
		end

		name:Draw()
		readytext:Draw()


	end

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

function GM:DrawPings()

	surface.SetFont("TargetID")
	for i=#G_PLAYER_PINGS, 1, -1 do
		local p = G_PLAYER_PINGS[i]
		local dt = CurTime() - p.time
		local alpha = 1 - math.max(dt - 1, 0)
		if dt > 2 then
			table.remove(G_PLAYER_PINGS, i)
		end

		local scr = p.pos:ToScreen()
		if scr.visible then

			local str = p.sanitized
			local tw, th = surface.GetTextSize(str)

			surface.SetDrawColor(0,0,0,180 * alpha)
			surface.DrawRect(scr.x - tw/2 - 2, scr.y - th/2 - 2, tw + 4, th + 4)

			surface.SetTextPos(scr.x - tw/2, scr.y - th/2)
			surface.SetTextColor(80,255,80,255 * alpha)
			surface.DrawText(str)

		end

	end

end

local CardVerbs = {
	"killed",
	"destroyed",
	"decimated",
	"eliminated",
	"took out",
	"deconstructed",
	"iced",
	"ended",
	"put an end to",
	"dispatched",
	"terminated",
	"finished off",
	"assassinated",
	"murdered",
	"wrecked",
	"annihilated",
	"eradicated",
	"wasted",
	"devestated",
}

local DeathCard = nil --[[{
	time = CurTime(),
	word = ("Anti-intellectualism"):upper(),
	attacker = "Killer",
	victim = "Victim",
	damage = 100,
	where = "butt",
	verb = CardVerbs[math.random(1,#CardVerbs)],
}]]


function GM:DrawDeathCard( card )

	if card == nil then return end

	local dt = CurTime() - card.time
	local alpha = 1
	local burst = 1 - math.min(dt, 1)

	local duration = 10
	if dt > duration then alpha = math.max(1 - (dt - duration), 0) end
	if alpha == 0 then return end

	local screen = textfx.ScreenBox()
	screen.y = screen.y - (1 - math.pow(burst, 4)) * 100

	local ba = 20 + burst * 200
	local br,bg,bb = rgb(40,burst,255)

	local attacker = textfx.Builder(card.attacker, "WordAmmoFont"):Box(10,2):Color(190,255,100,alpha*255)
	local killed = textfx.Builder(card.verb, "CooldownWordFont"):Box(10,4):Color(255,120,120,alpha*255)
	:HAlignTo(attacker, "after")
	:VAlignTo(attacker, "center")

	local victim = textfx.Builder(card.victim, "WordAmmoFont"):Box(10,2):Color(190,255,100,alpha*255)
	:HAlignTo(killed, "after")
	:VAlignTo(killed, "center")

	local box = textfx.BuilderBox(attacker, killed, victim):Store():HAlignTo(screen, "center")
	textfx.BuilderShift(box, attacker, killed, victim)

	local with = textfx.Builder(("shot in the %s for %i damage with"):format(card.where, card.damage), "CooldownWordFont"):Box(10,2):Color(255,255,255,alpha*180)
	:HAlignTo(box, "center")
	:VAlignTo(attacker, "after")

	local word = textfx.Builder(card.word, "WordAmmoFont"):Box(10,2)
	:Color(255,255,255,alpha*255)
	:HAlignTo(box, "center")
	:VAlignTo(with, "after")

	local box = textfx.BuilderBox(attacker, killed, victim, with, word):Pad(40 - 30 * burst*burst, 10)
	:Store()
	:HAlignTo(screen, "center")
	:VAlignTo(screen, "bottom")
	:DrawRounded(br,bg,bb,ba*alpha*alpha,8):Pad(-5):DrawRounded(0,0,0,200*alpha,6):Pad(5)

	textfx.BuilderShift(box, attacker, killed, victim, with, word)

	attacker:Draw()
	killed:Draw()
	victim:Draw()
	with:Draw()
	word:Draw()

end

function GM:DrawDeathCards()

	self:DrawDeathCard(DeathCard)

end

local HelpText = [[
	<font=HelpTitle>WorDM</font>
	<font=HelpSubTitle><colour=200,200,200,255>A gamemode by Kazditi</colour></font>
	<font=HelpSubTitle><colour=120,120,120,255>"A stick and stone can be ok, but words are ALWAYS hurt you."</colour></font>
	<font=HelpDetails>
	Typing many words, good for becoming win at this game.
	Big words 'chronocinematography' or 'hyperemphasizing' are hurt more, and more words makes better!

	Word scoring does calculate like so:
	<colour=255,100,100,255> - Bad spelling is give you zero points.</colour>
	<colour=255,100,100,255> - Medium to large words become cooldown for few seconds, zero points for them until after</colour>
	<colour=255,255,100,255> - Same word many times is lowered score.</colour>
	<colour=100,255,100,255> - Any order is for words ok ;)</colour>
	<colour=100,255,100,255> - Punctuate your words if want to be fancy is ok (?,':;)</colour>

	<colour=255,100,255,255> Words is make you seen for a little time, so if careful pay attention of another player, they find you!</colour>
	<colour=255,100,255,255> Last player standing wins! </colour>
	</font>


	<font=HelpRow><colour=255,255,200,255>bind_gm_showhelp</colour> : Show/hide this help screen</font>
	<font=HelpRow><colour=255,255,200,255>bind_gm_showteam</colour> : Change your player model and colors</font>
	opt_outfitter



	<font=HelpSubTitle>Credits:</font>
	<font=HelpDetails>Playtesters:</font>
	<colour=200,200,200,255>
	<font=HelpRow> - Muffin/ashii</font>
	<font=HelpRow> - Foohy</font>
	<font=HelpRow> - Lyo</font>
	<font=HelpRow> - An Actual Hyena Named Sitkero</font>
	</colour>
]]

HelpText = HelpText:gsub("opt_outfitter", function(x)
	if concommand.GetTable()["outfitter"] then
		return "<font=HelpRow><colour=255,255,200,255>bind_gm_showspare1</colour> : Show outfitter screen (workshop playermodels)</font>"
	else
		return ""
	end
end)

HelpText = HelpText:gsub("bind_([%w%d_]+)", function(x) return input.LookupBinding( x ) end)

local HelpTextMarkup = markup.Parse( HelpText )

--[[local HelpDemos = {
	phrasescore.New( LocalPlayer(), {
		phrase = "This gaem is fun",
		words = {
			{
				flags = WORD_VALID,
				first = 1,
				last = 4,
				score = 4,
			},
			{
				flags = 0,
				first = 6,
				last = 9,
				score = 0,
			},
			{
				flags = WORD_VALID,
				first = 11,
				last = 12,
				score = 2,
			},
		}
	})
}]]

function GM:DrawHelp()

	if not self.bShowingHelp then return end

	surface.SetDrawColor(0, 0, 0, 180)
	surface.DrawRect(0,0,ScrW(),ScrH())

	HelpTextMarkup:Draw(100, 100, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) 

	--HelpDemos[1]:Draw(120,600,true)

end

function GM:PlayerBindPress( ply, bind, pressed, code )

	if self:MapEditBindPress( bind, pressed, code ) then
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

function GM:PostWordCooldown( ply, str, cooldown )

	if str == nil then return end

	for _,v in ipairs(G_WORD_COOLDOWNS) do

		if v.str:lower() == str:lower() then
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


		surface.SetTextColor(255,180,180,100)
		surface.SetTextPos(x, y)
		surface.DrawText(str)

		surface.SetDrawColor(255,180,180,100)
		surface.DrawRect(x - tx - 10, y, tx, th)
	
	end

end

function GM:ShowPhraseScore( ply, phrase )

	if phrase == nil or #phrase.words == 0 then return end

	if ply == LocalPlayer() then
		surface.PlaySound("wordm/word_place.wav")
		G_TEMP_PHRASESCORE = phrasescore.New( ply, phrase )
		G_ALL_PHRASESCORES[#G_ALL_PHRASESCORES+1] = phrasescore.New( ply, phrase )
	else
		surface.PlaySound("wordm/word_place2.wav")
		G_ALL_PHRASESCORES[#G_ALL_PHRASESCORES+1] = phrasescore.New( ply, phrase )
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

	G_WORD_COOLDOWNS = {}
	G_PLAYER_PINGS = {}
	G_ALL_PHRASESCORES = {}
	G_TEMP_PHRASESCORE = nil

	self:ClearChatBuffers()

end

local GroupNames = {
	[HITGROUP_GENERIC] = "body",
	[HITGROUP_HEAD] = "head",
	[HITGROUP_CHEST] = "chest",
	[HITGROUP_STOMACH] = "stomach",
	[HITGROUP_LEFTARM] = "left arm",
	[HITGROUP_RIGHTARM] = "right arm",
	[HITGROUP_LEFTLEG] = "left leg",
	[HITGROUP_RIGHTLEG] = "right leg",
	[HITGROUP_GEAR] = "stuff",
}

net.Receive("worddeath_msg", function()

	local str = net.ReadString()
	local attacker = net.ReadEntity()
	local victim = net.ReadEntity()
	local damage = net.ReadFloat()
	local hitbox = net.ReadUInt(16)

	local group = GroupNames[victim:GetHitBoxHitGroup(hitbox, 0) or 0]

	local card = {
		time = CurTime(),
		word = str:upper(),
		attacker = SanitizeToAscii(attacker:Nick()),
		victim = SanitizeToAscii(victim:Nick()),
		damage = tostring(damage),
		where = group,
		verb = CardVerbs[math.random(1,#CardVerbs)],
	}

	DeathCard = card

end)

-- Some addon has this, dunno why, removing it
hook.Remove( "PlayerBindPress", "webbrowser" )