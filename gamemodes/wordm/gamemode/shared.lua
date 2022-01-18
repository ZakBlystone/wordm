AddCSLuaFile()

include "player_class/player_common.lua"

GM.Name     = "WorDM"
GM.Author   = "Zak"

-- WORD FLAGS ( 4 bits )
WORD_BITS = 4
WORD_SCOREBITS = 16
WORD_POSBITS = 10

PHRASE_LENBITS = 10

WORD_VALID = 1
WORD_COOLDOWN = 2
WORD_SECRET = 4
WORD_DUPLICATE = 8

TIME_TO_PHRASE = 0.5

function SendWordScore( t )

	net.WriteUInt(t.flags, WORD_BITS)
	net.WriteUInt(t.first, WORD_POSBITS)
	net.WriteUInt(t.last, WORD_POSBITS)

	if bit.band(t.flags, WORD_VALID) ~= 0 then
		net.WriteUInt(t.score, WORD_SCOREBITS)
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

	if bit.band(t.flags, WORD_VALID) ~= 0 then
		t.score = net.ReadUInt(WORD_SCOREBITS)
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

	local weap = ply:GetActiveWeapon()
	if weap.GivePhrase then
		weap:GivePhrase( phrase )
	end

end