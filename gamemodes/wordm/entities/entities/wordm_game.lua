AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_point"

local sv_gameStartTime = CreateConVar("wordm_gameStartTimer", "30", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "How long to give players to join")
local sv_gamePostTime = CreateConVar("wordm_gamePostTimer", "5", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "How long to give players to join")

GAMESTATE_IDLE = 0
GAMESTATE_COUNTDOWN = 1
GAMESTATE_PLAYING = 2
GAMESTATE_POSTGAME = 3

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

function ENT:GotoIdleState()

	self:SetGameState( GAMESTATE_IDLE )

	local activePlayers = GAMEMODE:GetAllPlayers( true )
	for _,v in ipairs(activePlayers) do
		v:SetPlaying(false)
		v:Spawn()
	end

end

function ENT:GotoStartingState()

	if CLIENT then return end

	if self:GetGameState() ~= GAMESTATE_IDLE then
		return
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

function ENT:Think()

	if SERVER then

		local state = self:GetGameState()

		if state == GAMESTATE_IDLE then

			local activePlayers = GAMEMODE:GetAllPlayers( true )
			if #activePlayers > 0 then

				self:GotoStartingState()

			end

		elseif state == GAMESTATE_COUNTDOWN then

			if self:GetTimeRemaining() == 0 then

				self:GotoPlayingState()

			end

		elseif state == GAMESTATE_PLAYING then

			local activePlayers = GAMEMODE:GetAllPlayers( true )
			local alive = 0
			for _,v in ipairs(activePlayers) do
				if v:Alive() then alive = alive + 1 end
			end

			if alive == 0 or alive == 1 then --change this to 1 when done testing

				self:GotoPostGameState()

			end

		elseif state == GAMESTATE_POSTGAME then

			if self:GetTimeRemaining() == 0 then

				self:GotoIdleState()

			end

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
