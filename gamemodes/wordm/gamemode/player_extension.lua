
local meta = FindMetaTable( "Player" )
if not meta then return end

PLAYER_IDLE = 1
PLAYER_READY = 2
PLAYER_PLAYING = 4

function meta:GetCurrentState()

	if self.GetState then

		if self:IsBot() then return bit.bor(self:GetState(), PLAYER_READY) end

		return self:GetState()

	end

	return PLAYER_IDLE

end

function meta:IsIdle()

	return bit.band(self:GetCurrentState(), PLAYER_IDLE) ~= 0

end

function meta:IsReady()

	return bit.band(self:GetCurrentState(), PLAYER_READY) ~= 0

end

function meta:IsPlaying()

	return bit.band(self:GetCurrentState(), PLAYER_PLAYING) ~= 0

end

function meta:ToggleReady()

	if CLIENT then return end

	if bit.band(self:GetCurrentState(), PLAYER_PLAYING) == 0 then

		if self.SetState then

			local fl = self:GetState()
			if bit.band(fl, PLAYER_READY) == 0 then 
				fl = bit.bor(fl, PLAYER_READY) 
			else
				fl = bit.band(fl, bit.bnot(PLAYER_READY))
			end
			self:SetState( fl )

		end

	end

end

function meta:StartPlaying()

	if CLIENT then return end

	if self.SetState then

		self:SetState( PLAYER_PLAYING )

	end

end

function meta:GotoIdle()

	if self.SetState then

		self:SetState( PLAYER_IDLE )

	end

end