AddCSLuaFile()

include "player_extension.lua"
include "mathutils.lua"
include "wordbullets.lua"
include "player_class/player_common.lua"
include "ui/shared.lua"
include "mapedit/shared.lua"

GM.Name     = "WorDM"
GM.Author   = "Zak"

-- WORD FLAGS ( 4 bits )
WORD_BITS = 4
WORD_SCOREBITS = 16
WORD_POSBITS = 10
WORD_COOLDOWNBITS = 10

PHRASE_LENBITS = 10

WORD_VALID = 1
WORD_COOLDOWN = 2
WORD_SECRET = 4
WORD_DUPLICATE = 8

TIME_TO_PHRASE = 0.5

function SanitizeToAscii(str)

	return string.gsub(str, "[^%a%s%p]", "")

end

function SendWordScore( t )

	net.WriteUInt(t.flags, WORD_BITS)
	net.WriteUInt(t.first, WORD_POSBITS)
	net.WriteUInt(t.last, WORD_POSBITS)

	if bit.band(t.flags, WORD_VALID) ~= 0 then
		net.WriteUInt(t.score, WORD_SCOREBITS)
		net.WriteUInt(math.floor(t.cooldown), WORD_COOLDOWNBITS)
	end

	if bit.band(t.flags, WORD_COOLDOWN) ~= 0 then
		net.WriteFloat(t.cooldown)
	end

end

function RecvWordScore()

	local t = {}
	t.flags = net.ReadUInt(WORD_BITS)
	t.first = net.ReadUInt(WORD_POSBITS)
	t.last = net.ReadUInt(WORD_POSBITS)
	t.score = 0

	if bit.band(t.flags, WORD_VALID) ~= 0 then
		t.score = net.ReadUInt(WORD_SCOREBITS)
		t.cooldown = CurTime() + net.ReadUInt(WORD_COOLDOWNBITS)
	end

	if bit.band(t.flags, WORD_COOLDOWN) ~= 0 then
		t.cooldown = net.ReadFloat()
	end

	return t

end

function SendPhraseScore( t )

	net.WriteString(t.phrase)
	net.WriteUInt(#t.words, PHRASE_LENBITS)
	for i=1, #t.words do
		SendWordScore(t.words[i])
	end

end

function RecvPhraseScore()

	local t = { words = {} }
	t.phrase = net.ReadString()
	local len = net.ReadUInt(PHRASE_LENBITS)
	for i=1, len do
		t.words[#t.words+1] = RecvWordScore()
	end
	return t

end

function GM:HandlePlayerPhraseSynced( ply, phrase )

	--print("SYNC PHRASE: " .. tostring(phrase.phrase))

	if #phrase.words == 0 then return end

	if ply.GivePhrase then
		ply:GivePhrase( phrase )
	end

end

function GM:PlayerTick( ply, mv )

	if SERVER then

		self:UpdateFiredWords( ply )

	else

		for _,v in ipairs(player.GetAll()) do

			self:UpdateFiredWords( v )

		end

	end

end

function GM:GetGameEntity()

	return self.GameEntity

end

function GM:GetAllPlayers( state )

	local out = {}
	for _,v in ipairs(player.GetAll()) do
		if bit.band(v:GetCurrentState(), state) ~= 0 then out[#out+1] = v end
	end
	return out

end

function GM:FurthestEntFromPlayers( ents, players )

	local bestEntity = nil
	local bestDist = 0
	if debugClose then bestDist = math.huge end

	for _,v in ipairs(ents) do

		local minPlayerDist = math.huge
		for _,pl in ipairs( players ) do
			minPlayerDist = math.min( minPlayerDist, pl:GetPos():Distance(v:GetPos()) )
		end

		if minPlayerDist > bestDist then
			bestEntity = v
			bestDist = minPlayerDist
		end

	end

	return bestEntity

end

function GM:Move(ply, mv)

	-- Freeze the players
	if self:GetGameEntity():GetGameState() == GAMESTATE_COUNTDOWN then

		local ang = mv:GetMoveAngles()
		local pos = mv:GetOrigin()
		local vel = mv:GetVelocity()
		
		mv:SetVelocity( Vector(0,0,0) )
		mv:SetOrigin( pos )

		return true

	end

end