AddCSLuaFile "cl_init.lua"
AddCSLuaFile "player_extension.lua"
AddCSLuaFile "mathutils.lua"
AddCSLuaFile "wordbullets.lua"
AddCSLuaFile "shared.lua"

include "shared.lua"

resource.AddFile("resource/fonts/Akkurat-Bold.ttf")
resource.AddFile("sound/wordm/word_eval.wav")
resource.AddFile("sound/wordm/word_place.wav")
resource.AddFile("sound/wordm/word_place2.wav")
resource.AddFile("sound/wordm/word_snap.wav")
resource.AddFile("sound/wordm/word_pickup.wav")

util.AddNetworkString("wordscore_msg")
util.AddNetworkString("wordfire_msg")
util.AddNetworkString("wordsubmit_msg")
util.AddNetworkString("worddeath_msg")

DEFINE_BASECLASS( "gamemode_base" )


G_WORD_COOLDOWN = G_WORD_COOLDOWN or {}
G_WORD_COOLDOWN = {}

if G_WORDLIST == nil then

	G_WORDLIST = {}
	G_WORDLIST_HASH = {}

	local function LoadWordTable(filename)

		local wordstr = file.Read("gamemodes/wordm/content/data/" .. filename .. ".txt", "THIRDPARTY")
		for s in string.gmatch(wordstr, "[^%s,]+") do
			local last = s[#s]
			if string.find(s,"[%.]+") then continue end
			if last == "-" then continue end
			G_WORDLIST[#G_WORDLIST+1] = s:lower()
			G_WORDLIST_HASH[s:lower()] = true
		end

	end

	LoadWordTable("words")

	print("Loaded " .. #G_WORDLIST .. " words.")

end

function GM:RandomWordWithCount(n)

	local wordsWithN = {}
	for _,v in ipairs(G_WORDLIST) do
		if #v == n then wordsWithN[#wordsWithN+1] = v end
	end
	return wordsWithN[math.random(1,#wordsWithN)]

end

function GM:DoCleanup( reloadMapData )

	if self.QueuedCleanup then return end
	self.QueuedCleanup = true

	G_WORD_COOLDOWN = {}

	local filter = {
		"env_fire", 
		"entityflame", 
		"_firesmoke", 
		"wordm_game", 
		"wordm_screen", 
		"wordm_spawn", 
		"wordm_spawn_lobby",
	}

	if reloadMapData then
		table.RemoveByValue(filter, "wordm_screen")
		table.RemoveByValue(filter, "wordm_spawn")
		table.RemoveByValue(filter, "wordm_spawn_lobby")
	end

	timer.Simple(0, function()
		game.CleanUpMap( false, filter )
		if reloadMapData then 
			GAMEMODE:LoadMapData()
		else
			GAMEMODE:InitializeMapdata()
		end

		GAMEMODE.QueuedCleanup = false
		for _, p in ipairs(ents.FindByClass("prop_physics*")) do
			local phys = p:GetPhysicsObject()
			if IsValid(phys) then
				phys:Sleep()
			end
		end
	end)

end

function GM:InitializeMapdata()

	local data = self.LoadedMapData
	if data == nil then return end

	for _,v in ipairs(data.locked) do

		local entity = ents.GetMapCreatedEntity(tonumber(v))
		if IsValid(entity) then
			entity:Fire("Lock")
		else
			print("UNABLE TO FIND LOCK ENTITY: " .. tostring( v ))
		end

	end

	for _,v in ipairs(data.removed) do

		local entity = ents.GetMapCreatedEntity(tonumber(v))
		if IsValid(entity) then
			entity:Remove()
		else
			print("UNABLE TO FIND REMOVE ENTITY: " .. tostring( v ))
		end

	end

end

function GM:LoadMapData()

	local mapdata = file.Read("wordm/maps/" .. game.GetMap() .. ".txt", "DATA" )
	if mapdata then

		local data = util.JSONToTable(mapdata)
		--PrintTable(data)

		self.LoadedMapData = data
		self:InitializeMapdata()

		for _,v in ipairs(data.spawn) do
			
			local entity = ents.Create(v.class)
			if IsValid(entity) then
				entity:SetPos( v.pos )
				entity:SetAngles( v.angles )
				entity:Spawn()
			end

		end

	end

end

function GM:InitPostEntity()

	self:LoadMapData()

	ents.Create("wordm_game"):Spawn()

end

function GM:PlayerDeathThink( ply )

	local wantSpawn = ply:KeyDown(IN_ATTACK)

	if ply:IsPlaying() then
		local state = self:GetGameEntity():GetGameState()
		if state == GAMESTATE_PLAYING or state == GAMESTATE_POSTGAME then 

			if wantSpawn and CurTime() - (ply.deathTime or 0) > 2 then

				if not ply.becameSpectator then
					ply.becameSpectator = true
					self:BecomeSpectator( ply )
				end

			end

			return 
		end
	end

	if wantSpawn then
		ply:Spawn()
	end

end

function GM:CanPlayerSuicide( ply )

	local gamestate = GAMEMODE:GetGameEntity():GetGameState()

	if ply:IsPlaying() then return true end
	if gamestate == GAMESTATE_IDLE then return true end
	if gamestate == GAMESTATE_PLAYING then return true end
	return false

end

function GM:SelectFurthestSpawn( playing )

	local spawns = ents.FindByClass(playing and "wordm_spawn" or "wordm_spawn_lobby")
	local players = self:GetAllPlayers( playing and PLAYER_PLAYING or bit.bor(PLAYER_IDLE, PLAYER_READY) )

	--print("PCHECK PLAYING: " .. tostring( playing ))
	--print("PCHECK FLAGS: " .. tostring( playing and PLAYER_PLAYING or bit.bor(PLAYER_IDLE, PLAYER_READY) ))

	if #players <= 1 then
		return spawns[math.random(1,#spawns)]
	end

	local debugClose = false

	local bestSpawn = nil
	local bestDist = 0
	if debugClose then bestDist = math.huge end

	for _,v in ipairs(spawns) do

		local minPlayerDist = math.huge
		for _,pl in ipairs( players ) do
			minPlayerDist = math.min( minPlayerDist, pl:GetPos():Distance(v:GetPos()) )
		end

		if debugClose then
			if minPlayerDist < 10 then continue end
			if minPlayerDist < bestDist then
				bestSpawn = v
				bestDist = minPlayerDist
			end
		else
			if minPlayerDist > bestDist then
				bestSpawn = v
				bestDist = minPlayerDist
			end
		end

	end

	print("BEST SPAWN[" .. tostring(bestSpawn) .. "] IS: " .. bestDist .. " from any other player")

	return bestSpawn or spawns[1]

end

function GM:PlayerShouldTakeDamage( ply, attacker )

	if self:GetGameEntity():GetGameState() < GAMESTATE_PLAYING then return false end

	if ply:IsPlaying() then return true end

end

function GM:PlayerSelectSpawn( ply )

	local spawn = self:SelectFurthestSpawn( ply:IsPlaying() )

	if not IsValid(spawn) then

		print("NO SPAWN FOUND, USING DEFAULT")
		return BaseClass.PlayerSelectSpawn( self, ply )

	end

	return spawn

end

function GM:BecomeSpectator( ply, stay )

	local activePlayers = GAMEMODE:GetAllPlayers( PLAYER_PLAYING )
	local spawns = ents.FindByClass("wordm_spawn")

	ply:StripWeapons()
	ply:Spectate(OBS_MODE_ROAMING)

	if not stay then
		if #activePlayers > 0 then
			ply:SetPos( activePlayers[math.random(1, #activePlayers)]:GetPos() + Vector(0,0,64) )
		else
			ply:SetPos( spawns[math.random(1,#spawns)]:GetPos() + Vector(0,0,64) )
		end
	else
		ply:SetPos( ply:GetPos() + Vector(0,0,64) )
	end


end

function GM:PlayerDeath( ply, inflictor, attacker )

	ply.deathTime = CurTime()
	ply.becameSpectator = false

	if ply:IsPlaying() and #ply:GetPhrases() > 0 then

		local drop = ents.Create("wordm_drop_notepad")
		drop:SetPos( ply:GetPos() + Vector(0,0,30) )
		drop:Spawn()
		drop:SetPhrases( ply:GetPhrases() )

		ply:ClearPhrases()

	end

end

function GM:PlayerLoadout( ply ) end -- Handled by player base
function GM:PlayerSetModel( ply ) end -- Handled by player base
function GM:PlayerSpawn( ply )

	local state = self:GetGameEntity():GetGameState()
	if state == GAMESTATE_PLAYING or state == GAMESTATE_COUNTDOWN then

		if not ply:IsPlaying() then
			--self.BaseClass.PlayerSpawn( self, ply )
			self:BecomeSpectator( ply )
			return
		end

	end

	player_manager.SetPlayerClass( ply, "player_common" )
	player_manager.RunClass( ply, "Init" )

	return self.BaseClass.PlayerSpawn( self, ply )

end

function GM:ShowHelp( ply ) ply:SendLua("GAMEMODE:ShowHelp()") end
function GM:ShowTeam( ply ) ply:SendLua("GAMEMODE:ShowTeam()") end
function GM:ShowSpare1( ply ) ply:SendLua("GAMEMODE:ShowSpare1()") end
function GM:ShowSpare2( ply ) end

function GM:ComputeWordCooldown( str )

	if string.len(str) <= 3 then return 0 end

	return 2 + string.len(str) * 3

end

function GM:ScalePlayerDamage( ply, hitgroup, dmginfo )


end

function GM:GiveWords( ply, count, length )

	local str = ""
	for i=1, count do

		local word = self:RandomWordWithCount(length or 5) --G_WORDLIST[math.random(1, #G_WORDLIST)]

		str = str .. word
		if i ~= count then str = str .. " " end

	end

	print("GIVE: '" .. str .. "'")

	self:ServerSendPhrase(ply, str)

end

concommand.Add("giveWords", function(p,c,a)

	if p.IsAdmin ~= nil and not p:IsAdmin() then return end

	local num = tonumber(a[1]) or 1
	local who = a[2]

	if who then
		for _,v in ipairs(player.GetAll()) do
			if string.find(v:Nick():lower(), who) ~= nil then
				p = v
			end
		end
	end

	print("GIVE WORDS TO: " .. tostring(p))

	GAMEMODE:GiveWords(p, num)

end)

concommand.Add("addWords", function(p,c,a)

	if p.IsAdmin ~= nil and not p:IsAdmin() then return end

	for _,v in ipairs(a) do

		local str = string.lower(v)
		if str ~= "" and str ~= " " then

			if not G_WORDLIST_HASH[str] then

				G_WORDLIST[#G_WORDLIST+1] = str
				G_WORDLIST_HASH[str] = true
				print("Added word: " .. str)

			else

				print("Word already added: " .. str)

			end

		end

	end

end)

function GM:IsValidWord( word )

	if G_WORDLIST_HASH[word] then return true end

	for _,v in ipairs(player.GetAll()) do
		local name = SanitizeToAscii(v:Nick()):lower()
		if word == name then return true end

		local b,pw = 0
		for _ = 1, 100 do
			_,b,pw = name:find( "([%w-']+)", b+1 )
			if not pw then break end
			if word == pw then return true end
		end
	end

	return false

end

function GM:ScoreWord( word, applyCooldown, noCooldown )

	local info = {}
	local flags = 0
	local score = 0
	local lowered = string.lower(word.str)

	if self:IsValidWord(lowered) then
		flags = flags + WORD_VALID

		if (G_WORD_COOLDOWN[lowered] or 0) - CurTime() > 0 then
			if not noCooldown then
				flags = flags + WORD_COOLDOWN
				info.cooldown = G_WORD_COOLDOWN[lowered]
			else
				score = score + string.len(lowered)
			end
		else
			score = score + string.len(lowered)

			if applyCooldown then
				local computed = self:ComputeWordCooldown(lowered)
				G_WORD_COOLDOWN[lowered] = CurTime() + computed
				info.cooldown = computed
			end
		end
	end

	info.flags = flags
	info.score = score * 4
	info.first = word.first
	info.last = word.last
	return info

end

function GM:TriggerScreens( phrase, ply )

	local b,pw = 0
	for _ = 1, 100 do
		_,b,pw = phrase:find( "([%w-']+)", b+1 )
		if not pw then break end
		local word = pw:upper()

		for _, screen in ipairs( ents.FindByClass("wordm_screen") ) do

			if screen:GetWord1() == word then
				screen:ApplyToPlayer( ply, 1 )
			elseif screen:GetWord2() == word then
				screen:ApplyToPlayer( ply, 2 )
			end

		end
	end

end

function GM:ScorePhrase( text, applyCooldown, noCooldown )

	local scoring = { phrase = text, words = {}, total = 0 }
	local words = {}

	--print("---PHRASE: " .. tostring(text))

	local a,b,c = 0,0
	for _ = 1, 100 do
		a,b,c = text:find( "([%w-']+)", b+1 )
		if not a then break end
		--print("---WORD: " .. tostring(c))
		words[#words+1] = {
			first = a,
			last = b,
			str = c,
		}
	end

	local dup = {}
	for k,v in ipairs(words) do
		if dup[v.str] then
			local from = scoring.words[dup[v.str]]
			from.flags = bit.bor(from.flags, WORD_DUPLICATE)
			from.dupgroup = dup[v.str]
			scoring.words[#scoring.words+1] = {
				dupgroup = from.dupgroup,
				flags = from.flags,
				score = from.score,
				cooldown = from.cooldown,
				first = v.first,
				last = v.last,
			}
		else
			dup[v.str] = k
			scoring.words[#scoring.words+1] = self:ScoreWord( v, applyCooldown, noCooldown )			
		end
	end

	local grouping = {}
	for _,v in ipairs(scoring.words) do
		if v.dupgroup then
			grouping[v.dupgroup] = (grouping[v.dupgroup] or 0) + 1
		end
	end

	for _,v in ipairs(scoring.words) do
		if v.dupgroup then
			v.score = math.max(math.Round(v.score / grouping[v.dupgroup]), 1)
		end
		scoring.total = scoring.total + v.score
	end

	return scoring

end

function GM:ServerSendPhrase( ply, text, noCooldown )

	local phrase = self:ScorePhrase( text, true, noCooldown )

	if ply:IsBot() then

		self:HandlePlayerPhraseSynced( ply, phrase )

	end

	self:TriggerScreens( text, ply )

	if tts then
		tts.TTSOnPlayer(text, ply, 180)
	end

	net.Start("wordscore_msg")
	net.WriteFloat(CurTime())
	net.WriteEntity(ply)
	net.WriteVector(ply:GetPos())
	SendPhraseScore( phrase )
	net.Broadcast()

	ply.pendingPhrase = phrase

end

function GM:PlayerSay( ply, text )

	self:TriggerScreens( text, ply )

	--local sanitized = SanitizeToAscii(text)
	--print("SAY: " .. text)

	--if #string.gsub(sanitized, "[%s]", "") == 0 then return text end
	--self:ServerSendPhrase( ply, sanitized )
	return text

end

function GM:Think()

	for _,v in ipairs(player.GetAll()) do
		if v.pendingPhrase and v.pendingPhraseTime and v.pendingPhraseTime < CurTime() then
			self:HandlePlayerPhraseSynced(v, v.pendingPhrase)
			v.pendingPhrase = nil
			v.pendingPhraseTime = nil
		end
	end

end

function GM:KeyPress( ply, key )

	if not IsFirstTimePredicted() then return end

	if self:GetGameEntity():GetGameState() <= GAMESTATE_COUNTDOWN then

		if key == IN_RELOAD then
			ply:ToggleReady()
		end

	end

end

net.Receive("wordscore_msg", function(len, ply)

	local when = net.ReadFloat()
	if ply.pendingPhrase then

		ply.pendingPhraseTime = when

	end

end)

net.Receive("wordsubmit_msg", function(len, ply)

	local ge = GAMEMODE:GetGameEntity()
	local gamestate = ge:GetGameState()

	local str = net.ReadString()
	GAMEMODE:ServerSendPhrase( ply, str )


end)