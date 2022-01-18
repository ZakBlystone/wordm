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

	local wordstr = file.Read("gamemodes/wordm/content/data/words.txt", "THIRDPARTY")
	for s in string.gmatch(wordstr, "[^%s,]+") do
		G_WORDLIST[#G_WORDLIST+1] = s:lower()
		G_WORDLIST_HASH[s:lower()] = true
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

function GM:ScalePlayerDamage( ply, hitgroup, dmginfo )


end

function GM:ScoreWord( word, applyCooldown )

	local info = {}
	local flags = 0
	local score = 0

	if G_WORDLIST_HASH[string.lower(word.str)] then
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
		a,b,c = text:find( "([%w-']+)", b+1 )
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
			scoring.words[#scoring.words+1] = self:ScoreWord( v )			
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