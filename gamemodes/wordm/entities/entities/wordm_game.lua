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

-- State machine controlling game flow
-- Idle: nothing happening, players are just chilling in lobby area
-- Waiting: enough players are ready, start a timer for the game to start (allowing players to opt out)
-- Countdown: players are spawned into the game area, players are frozen until timer completes
-- Playing: normal gameplay is happening
-- Postgame: postgame report

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

-- Force the timer to advance to the next game state
function ENT:FinishTimer()

	self:SetTimer( CurTime() )

end

-- Concommand to force the timer to advance to the next game state
concommand.Add("wordm_finishTimer", function(p,c,a)

	if p.IsAdmin ~= nil and not p:IsAdmin() then return end

	GAMEMODE:GetGameEntity():FinishTimer()
	return

end)

-- Transition to the Idle state
-- 'returnedFromGame' is true when a round has just finished playing
function ENT:GotoIdleState( returnedFromGame )

	if CLIENT then return end

	self:SetGameState( GAMESTATE_IDLE )

	if returnedFromGame then

		-- Cleanup the map
		GAMEMODE:DoCleanup()

		-- Get all idle players and un-spectate them
		local idlePlayers = GAMEMODE:GetAllPlayers( PLAYER_IDLE )
		for _,v in ipairs(idlePlayers) do
			v:UnSpectate()
			v:Spawn()
		end

		-- Get all active players and make them idle / un-spectate
		local activePlayers = GAMEMODE:GetAllPlayers( PLAYER_PLAYING )
		for _,v in ipairs(activePlayers) do
			v:GotoIdle()
			v:UnSpectate()
		end

		-- Respawn all active players
		for _,v in ipairs(activePlayers) do
			v:Spawn()
		end

		-- Deactivate all the word screens
		self:DeactivateWordScreens()

	end

end

-- Transition to the Waiting state (waiting for players to opt-in / opt-out of playing)
function ENT:GotoWaitingState()

	if CLIENT then return end

	if self:GetGameState() ~= GAMESTATE_IDLE then
		return
	end

	self:SetTimer( CurTime() + sv_gameWaitTime:GetFloat() )
	self:SetGameState( GAMESTATE_WAITING )

end

-- Transition to the Countdown state (players are spawned in play area frozen)
-- (freezing logic is handled in shared.lua GM:Move)
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

-- Transition to Playing state (no need to modify timer or anything here)
function ENT:GotoPlayingState()

	if CLIENT then return end

	self:SetGameState( GAMESTATE_PLAYING )

end

-- Transition to Post game state (timer to advance to next state)
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

-- Determine what powers a word screen will show based on general state of all players
function ENT:WhatKindOfPowers()

	local averagePlayerHealth = 0
	local players = GAMEMODE:GetAllPlayers( PLAYER_PLAYING ) 

	for i=1, #players do
		averagePlayerHealth = averagePlayerHealth + players[i]:Health()
	end

	averagePlayerHealth = averagePlayerHealth / #players

	-- If average player health is lower than 75, show health powerups, otherwise show words
	if averagePlayerHealth < 75 then
		return WORDSCREENTYPE_HEALTH
	else
		return WORDSCREENTYPE_WORDS
	end

end

-- Pick a word screen in the map and activate it
function ENT:ManageWordScreenActivation()

	self.NextScreenActivation = self.NextScreenActivation or CurTime()
	if self.NextScreenActivation > CurTime() then return end

	local screens = ents.FindByClass("wordm_screen")
	local inactiveScreens = {}
	local numActive = 0

	-- Determine active and inactive screens
	for _,v in ipairs(screens) do
		if v:IsActive() then 
			numActive = numActive + 1
		else
			inactiveScreens[#inactiveScreens+1] = v
		end
	end

	-- No inactive screens, do nothing and wait 10 seconds
	if #inactiveScreens == 0 then
		self.NextScreenActivation = CurTime() + 10
		return 
	end

	-- There are plenty of active screens ( > 60% ), do nothing and wait 10 seconds
	if numActive > (#screens * 0.60) then
		print("Waiting for more screens: " .. numActive .. " / " .. #screens)
		self.NextScreenActivation = CurTime() + 10
		return
	end

	-- Locate the furthest screen from any player ( to prevent camping )
	local players = GAMEMODE:GetAllPlayers( PLAYER_PLAYING ) 
	local furthest = GAMEMODE:FurthestEntFromPlayers( inactiveScreens, players )

	-- If one was found, make that screen active
	if furthest then
		furthest:MakeActive( false, self:WhatKindOfPowers() )
		print("Activated Screen: " .. tostring(furthest) .. " " .. numActive .. " / " .. #screens)
	end

	-- Wait another 10 seconds
	self.NextScreenActivation = CurTime() + 10

end

-- State machine thunk
function ENT:Think()

	if SERVER then

		-- Manage state machine on the server
		local state = self:GetGameState()

		if state == GAMESTATE_IDLE then

			-- If number of ready players exceeds 1 (a duel) go to Waiting state
			local readyPlayers = GAMEMODE:GetAllPlayers( PLAYER_READY )
			if #readyPlayers > 1 then

				local nonBot = false
				for _,v in ipairs(readyPlayers) do
					if not v:IsBot() then nonBot = true end
				end

				if nonBot then self:GotoWaitingState() end

			end

		elseif state == GAMESTATE_WAITING then

			-- If number of ready players drops to 0, cancel and go back to Idle state
			local readyPlayers = GAMEMODE:GetAllPlayers( PLAYER_READY )
			if #readyPlayers == 0 then

				self:GotoIdleState()

			end

			-- When timer expires or everyone is ready, go to the Countdown state
			if self:GetTimeRemaining() == 0 or #readyPlayers == #player.GetAll() then

				self:GotoCountdownState()

			end

		elseif state == GAMESTATE_COUNTDOWN then

			-- When timer expires goto to Playing state
			if self:GetTimeRemaining() == 0 then

				self:GotoPlayingState()

			end

		elseif state == GAMESTATE_PLAYING then

			-- During the Playing state, manage the word screens
			self:ManageWordScreenActivation()

			local activePlayers = GAMEMODE:GetAllPlayers( PLAYER_PLAYING )
			local alive = 0
			for _,v in ipairs(activePlayers) do
				if v:Alive() then alive = alive + 1 end
			end

			-- If everyone is dead or one person is left standing, the game is over
			if alive == 0 or alive == 1 then

				self:GotoPostGameState()

			end

		elseif state == GAMESTATE_POSTGAME then

			-- Go to idle state once timer expires
			if self:GetTimeRemaining() == 0 then

				self:GotoIdleState( true )

			end

		end

	else

		-- On the client, clear things when we transition to idle state
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

-- How much time is left on the timer
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
