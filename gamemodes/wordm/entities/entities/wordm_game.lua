AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_point"

local sv_gameWaitTime = CreateConVar("wordm_gameWaitTimer", "15", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "How long to give players to join")
local sv_gameStartTime = CreateConVar("wordm_gameStartTimer", "30", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "How long to let players setup in-game")
local sv_gamePostTime = CreateConVar("wordm_gamePostTimer", "10", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "How long to let post-game run")

GAMESTATE_IDLE = 0
GAMESTATE_WAITING = 1
GAMESTATE_COUNTDOWN = 2
GAMESTATE_PLAYING = 3
GAMESTATE_POSTGAME = 4

function ENT:Initialize()

	if SERVER then

		print("*** GAME INIT SERVER")
		GAMEMODE.GameEntity = self

	else

		print("*** GAME INIT CLIENT")
		GAMEMODE.GameEntity = self

	end

	self:SetGameState( GAMESTATE_IDLE )

end

function ENT:FinishTimer()

	self:SetTimer( CurTime() )

end

concommand.Add("wordm_finishTimer", function(p,c,a)

	if p.IsAdmin ~= nil and not p:IsAdmin() then return end

	GAMEMODE:GetGameEntity():FinishTimer()
	return

end)

function ENT:GotoIdleState( returnedFromGame )

	if CLIENT then return end

	self:SetGameState( GAMESTATE_IDLE )

	if returnedFromGame then

		GAMEMODE:DoCleanup()

		local idlePlayers = GAMEMODE:GetAllPlayers( PLAYER_IDLE )
		for _,v in ipairs(idlePlayers) do
			v:UnSpectate()
			v:Spawn()
		end


		local activePlayers = GAMEMODE:GetAllPlayers( PLAYER_PLAYING )
		for _,v in ipairs(activePlayers) do
			v:GotoIdle()
			v:UnSpectate()
		end

		for _,v in ipairs(activePlayers) do
			v:Spawn()
		end

		self:DeactivateWordScreens()

	end

end

function ENT:GotoWaitingState()

	if CLIENT then return end

	if self:GetGameState() ~= GAMESTATE_IDLE then
		return
	end

	self:SetTimer( CurTime() + sv_gameWaitTime:GetFloat() )
	self:SetGameState( GAMESTATE_WAITING )

end

function ENT:GotoCountdownState()

	if CLIENT then return end

	if self:GetGameState() ~= GAMESTATE_WAITING then
		return
	end

	-- Put all ready players into the game
	for _,v in ipairs( GAMEMODE:GetAllPlayers(PLAYER_READY) ) do
		v:StartPlaying()
		v:Spawn()
	end

	-- Make all idle players spectate
	for _,v in ipairs( GAMEMODE:GetAllPlayers(PLAYER_IDLE) ) do

		GAMEMODE:BecomeSpectator( v )

	end

	self:SetTimer( CurTime() + sv_gameStartTime:GetFloat() )
	self:SetGameState( GAMESTATE_COUNTDOWN )

end

function ENT:GotoPlayingState()

	if CLIENT then return end

	self:SetGameState( GAMESTATE_PLAYING )

end

function ENT:GotoPostGameState()

	if CLIENT then return end

	self:SetGameState( GAMESTATE_POSTGAME )
	self:SetTimer( CurTime() + sv_gamePostTime:GetFloat() )

end

function ENT:DeactivateWordScreens()

	for _,v in ipairs(ents.FindByClass("wordm_screen")) do

		v:MakeInactive()

	end

end

function ENT:WhatKindOfPowers()

	local averagePlayerHealth = 0
	local players = GAMEMODE:GetAllPlayers( PLAYER_PLAYING ) 

	for i=1, #players do
		averagePlayerHealth = averagePlayerHealth + players[i]:Health()
	end

	averagePlayerHealth = averagePlayerHealth / #players

	if averagePlayerHealth < 75 then
		return WORDSCREENTYPE_HEALTH
	else
		return WORDSCREENTYPE_WORDS
	end

end


function ENT:ManageWordScreenActivation()

	self.NextScreenActivation = self.NextScreenActivation or CurTime()
	if self.NextScreenActivation > CurTime() then return end

	local screens = ents.FindByClass("wordm_screen")
	local inActiveScreens = {}
	local numActive = 0

	for _,v in ipairs(screens) do
		if v:IsActive() then 
			numActive = numActive + 1
		else
			inActiveScreens[#inActiveScreens+1] = v
		end
	end

	if #inActiveScreens == 0 then
		self.NextScreenActivation = CurTime() + 10
		return 
	end

	if numActive > (#screens * 0.60) then
		print("Waiting for more screens: " .. numActive .. " / " .. #screens)
		self.NextScreenActivation = CurTime() + 10
		return
	end

	local players = GAMEMODE:GetAllPlayers( PLAYER_PLAYING ) 
	local furthest = GAMEMODE:FurthestEntFromPlayers( inActiveScreens, players )

	if furthest then
		furthest:MakeActive( false, self:WhatKindOfPowers() )
		print("Activated Screen: " .. tostring(furthest) .. " " .. numActive .. " / " .. #screens)
	end

	self.NextScreenActivation = CurTime() + 10

end

function ENT:Think()

	if SERVER then

		local state = self:GetGameState()
		local shouldFreezePlayers = false

		if state == GAMESTATE_IDLE then

			local readyPlayers = GAMEMODE:GetAllPlayers( PLAYER_READY )
			if #readyPlayers > 1 then

				local nonBot = false
				for _,v in ipairs(readyPlayers) do
					if not v:IsBot() then nonBot = true end
				end

				if nonBot then self:GotoWaitingState() end

			end

		elseif state == GAMESTATE_WAITING then

			local readyPlayers = GAMEMODE:GetAllPlayers( PLAYER_READY )
			if #readyPlayers == 0 then

				self:GotoIdleState()

			end

			if self:GetTimeRemaining() == 0 or #readyPlayers == #player.GetAll() then

				self:GotoCountdownState()

			end

		elseif state == GAMESTATE_COUNTDOWN then

			shouldFreezePlayers = true

			if self:GetTimeRemaining() == 0 then

				self:GotoPlayingState()

			end

		elseif state == GAMESTATE_PLAYING then

			self:ManageWordScreenActivation()

			local activePlayers = GAMEMODE:GetAllPlayers( PLAYER_PLAYING )
			local alive = 0
			for _,v in ipairs(activePlayers) do
				if v:Alive() then alive = alive + 1 end
			end

			if alive == 0 or alive == 1 then --change this to 1 when done testing

				self:GotoPostGameState()

			end

		elseif state == GAMESTATE_POSTGAME then

			if self:GetTimeRemaining() == 0 then

				self:GotoIdleState( true )

			end

		end

	else

		if self:GetGameState() == GAMESTATE_IDLE then

			if not self.ClearedStuff then

				self.ClearedStuff = true

				GAMEMODE:ClearWordBullets()
				GAMEMODE:ClearTemporaryUI()
				LocalPlayer():ConCommand("r_cleardecals")

			end

		else

			self.ClearedStuff = false

		end

	end

end

function ENT:GetTimeRemaining()

	return math.max(self:GetTimer() - CurTime(), 0)

end

function ENT:SetupDataTables()

	self:NetworkVar( "Int", 0, "GameState" )
	self:NetworkVar( "Float", 0, "Timer" )

end


function ENT:UpdateTransmitState()

	return TRANSMIT_ALWAYS

end
