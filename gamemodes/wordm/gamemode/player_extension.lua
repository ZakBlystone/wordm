
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

function meta:GetPhrases()

	return self.Phrases or {}

end

function meta:GetCurrentPhrase()

	return self.CurrentPhrase

end

function meta:GivePhrase( scoring )

	scoring = table.Copy(scoring)

	self.Phrases[#self.Phrases+1] = scoring

	if not self.CurrentPhrase then
		self.CurrentPhrase = scoring
	end

	self:OnPhraseAdded(scoring)

end

function meta:ConsumeWord()

	local phrase = self.CurrentPhrase
	if phrase == nil then return end

	local word = phrase.words[1]
	if word == nil then 
		table.remove(self.Phrases, 1)
		self.CurrentPhrase = self.Phrases[1]
		return 
	end

	-- Skip this word if it is on cooldown
	if bit.band(word.flags, WORD_COOLDOWN) ~= 0 then
		local c = phrase.words[1]
		table.remove(phrase.words, 1)
		self:OnWordConsumed(phrase, c)
		return self:ConsumeWord()
	end

	local c = phrase.words[1]
	table.remove(phrase.words, 1)
	self:OnWordConsumed(phrase, c)
	return word, phrase

end

function meta:ConsumePhrase()

	local phrase = self.CurrentPhrase
	if phrase == nil then return 0,0 end

	local totalScore = 0
	local totalCount = 0
	local strings = {}
	while #phrase.words > 0 do
		local word = phrase.words[1]
		table.remove(phrase.words,1)
		self:OnWordConsumed(phrase, word)

		if bit.band(word.flags, WORD_COOLDOWN) == 0 and
		   bit.band(word.flags, WORD_VALID) ~= 0 then
		   	totalScore = totalScore + (word.score or 0)
		   	totalCount = totalCount + 1

		   	strings[#strings+1] = phrase.phrase:sub(word.first, word.last)
		end
	end

	--table.remove(self.Phrases, 1)
	--self.CurrentPhrase = self.Phrases[1]

	return totalScore, totalCount, strings

end

function meta:OnWordConsumed(phrase, word)

	if #phrase.words == 0 then
		table.remove(self.Phrases, 1)
		self.CurrentPhrase = self.Phrases[1]
	end

	local weapon = self:GetActiveWeapon()
	if IsValid(weapon) and weapon.OnWordConsumed then
		weapon:OnWordConsumed(phrase, word)
	end

end

function meta:OnPhraseAdded(phrase)

	local weapon = self:GetActiveWeapon()
	if IsValid(weapon) and weapon.OnPhraseAdded then
		weapon:OnPhraseAdded(phrase)
	end

end