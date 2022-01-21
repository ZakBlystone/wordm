AddCSLuaFile "cl_init.lua"
AddCSLuaFile "cl_textfx.lua"
AddCSLuaFile "cl_chat.lua"
AddCSLuaFile "shared.lua"

include "shared.lua"

resource.AddFile("resource/fonts/Akkurat-Bold.ttf")

util.AddNetworkString("wordscore_msg")
util.AddNetworkString("wordfire_msg")

local function SanitizeToAscii(str)

	return string.gsub(str, "[^%a%s]", "")

end

G_WORD_COOLDOWN = G_WORD_COOLDOWN or {}
G_WORD_COOLDOWN = {}

if G_WORDLIST == nil then

	G_WORDLIST = {}
	G_WORDLIST_HASH = {}

	local function LoadWordTable(filename)

		local wordstr = file.Read("gamemodes/wordm/content/data/" .. filename .. ".txt", "THIRDPARTY")
		for s in string.gmatch(wordstr, "[^%s,]+") do
			G_WORDLIST[#G_WORDLIST+1] = s:lower()
			G_WORDLIST_HASH[s:lower()] = true
		end

	end

	LoadWordTable("words")

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

	if string.len(str) <= 4 then return 0 end

	return 2 + string.len(str) * 4

end

function GM:ScalePlayerDamage( ply, hitgroup, dmginfo )


end

function GM:GiveWords( ply, count )

	local str = ""
	for i=1, count do

		local word = G_WORDLIST[math.random(1, #G_WORDLIST)]

		str = str .. word
		if i ~= count then str = str .. " " end

	end

	self:ServerSendPhrase(ply, str)

end

concommand.Add("giveWords", function(p,c,a)

	if not p:IsAdmin() then return end

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

	if not p:IsAdmin() then return end

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

function GM:ScoreWord( word, applyCooldown )

	local info = {}
	local flags = 0
	local score = 0

	if G_WORDLIST_HASH[string.lower(word.str)] then
		flags = flags + WORD_VALID

		if (G_WORD_COOLDOWN[word.str] or 0) - CurTime() > 0 then
			flags = flags + WORD_COOLDOWN
			info.cooldown = G_WORD_COOLDOWN[word.str]
		else
			score = score + string.len(word.str)

			if applyCooldown then
				local computed = self:ComputeWordCooldown(word.str)
				G_WORD_COOLDOWN[word.str] = CurTime() + computed
				info.cooldown = computed
			end
		end
	end

	info.flags = flags
	info.score = score
	info.first = word.first
	info.last = word.last
	return info

end

function GM:ScorePhrase( text, applyCooldown )

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
			scoring.words[#scoring.words+1] = self:ScoreWord( v, applyCooldown )			
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

function GM:ServerSendPhrase( ply, text )

	local phrase = self:ScorePhrase( text, true )

	if ply:IsBot() then

		self:HandlePlayerPhraseSynced( ply, phrase )

	end

	net.Start("wordscore_msg")
	net.WriteFloat(CurTime())
	net.WriteEntity(ply)
	SendPhraseScore( phrase )
	net.Broadcast()

	ply.pendingPhrase = phrase

end

function GM:PlayerSay( ply, text )

	local sanitized = SanitizeToAscii(text)
	print("SAY: " .. text)

	if #string.gsub(sanitized, "[%s]", "") == 0 then return text end
	self:ServerSendPhrase( ply, sanitized )
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