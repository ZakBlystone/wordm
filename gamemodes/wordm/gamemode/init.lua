AddCSLuaFile "cl_init.lua"
AddCSLuaFile "cl_textfx.lua"
AddCSLuaFile "shared.lua"

include "shared.lua"

util.AddNetworkString("wordscore_msg")

G_WORD_COOLDOWN = G_WORD_COOLDOWN or {}
G_WORD_COOLDOWN = {}

if G_WORDLIST == nil then

	G_WORDLIST = {}
	G_WORDLIST_HASH = {}

	local wordstr = file.Read("gamemodes/wordm/content/data/words_alpha.txt", "THIRDPARTY")
	for s in string.gmatch(wordstr, "[^%s,]+") do
		G_WORDLIST[#G_WORDLIST+1] = s
		G_WORDLIST_HASH[s] = true
	end

	print("Loaded " .. #G_WORDLIST .. " words.")

end

function GM:PlayerLoadout( ply ) end -- Handled by player base
function GM:PlayerSetModel( ply ) end -- Handled by player base
function GM:PlayerSpawn( ply )

	player_manager.SetPlayerClass( ply, "player_common" )
	player_manager.RunClass( ply, "Init" )

	return self.BaseClass.PlayerSpawn( self, ply )

end

function GM:ShowHelp( ply ) ply:SendLua("GAMEMODE:ShowHelp()") end
function GM:ShowTeam( ply ) ply:SendLua("GAMEMODE:ShowTeam()") end
function GM:ShowSpare1( ply ) ply:SendLua("GAMEMODE:ShowSpare1()") end
function GM:ShowSpare2( ply ) end

function GM:ComputeWordCooldown( str )

	return 30 + string.len(str) * 5

end

function GM:ScoreWord( word, applyCooldown )

	local info = {}
	local flags = 0
	local score = 0

	if not word.duplicate then

		if G_WORDLIST_HASH[word.str] then
			if (G_WORD_COOLDOWN[word.str] or 0) - CurTime() > 0 then
				flags = flags + WORD_COOLDOWN
				info.cooldown = G_WORD_COOLDOWN[word.str]
			else
				flags = flags + WORD_VALID
				score = score + string.len(word.str)

				if applyCooldown then
					G_WORD_COOLDOWN[word.str] = CurTime() + self:ComputeWordCooldown(word.str)
				end
			end
		end

	else

		flags = flags + WORD_DUPLICATE

	end

	info.flags = flags
	info.score = score
	info.first = word.first
	info.last = word.last
	return info

end

function GM:ScorePhrase( text )

	local scoring = { phrase = text, words = {} }
	local words = {}

	local max = 1000
	local a,b,c = 0,0
	while true do
		a,b,c = text:find( "([%w]+)", b+1 )
		if not a then break end
		words[#words+1] = {
			first = a,
			last = b,
			str = c,
		}
		max = max - 1
		if max == 0 then break end
	end

	local dup = {}
	for _,v in ipairs(words) do
		if dup[v.str] then v.duplicate = true end
		dup[v.str] = true
		scoring.words[#scoring.words+1] = self:ScoreWord( v )
	end

	return scoring

end

function GM:PlayerSay( ply, text )

	print("SAY: " .. text)

	local phrase = self:ScorePhrase( text )

	net.Start("wordscore_msg")
	net.WriteFloat(CurTime())
	net.WriteEntity(ply)
	SendPhraseScore( phrase )
	net.Broadcast()

	ply.pendingPhrase = phrase

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

net.Receive("wordscore_msg", function(len, ply)

	local when = net.ReadFloat()
	if ply.pendingPhrase then

		ply.pendingPhraseTime = when

	end

end)