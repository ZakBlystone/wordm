if SERVER then
	AddCSLuaFile()
end

SWEP.PrintName				= "Word Gun"
SWEP.Slot					= 0

SWEP.ViewModel				= "models/weapons/c_357.mdl"
SWEP.WorldModel				= "models/weapons/w_357.mdl"

SWEP.UseHands		= true

SWEP.HoldType				= "pistol"

util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )

SWEP.Primary.Delay			= 1
SWEP.Primary.ClipSize		= 1000
SWEP.Primary.DefaultClip	= 0
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Sound			= Sound( "weapons/357/357_fire2.wav" )
SWEP.Primary.Empty			= Sound( "weapons/pistol/pistol_empty.wav" )
SWEP.Primary.Automatic		= true

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Ammo		= "none"
SWEP.Secondary.Sound			= Sound( "weapons/shotgun/shotgun_fire7.wav" )
SWEP.Secondary.Empty			= Sound( "weapons/pistol/pistol_empty.wav" )
SWEP.Secondary.Automatic		= false

SWEP.Spawnable				= false
SWEP.RequestInfo			= {}
SWEP.ConsumeEntirePhrase	= true

function SWEP:Initialize()

	self:SetWeaponHoldType( self.HoldType )
	self.Phrases = {}
	self.WordEject = {}
	self.NextBulletDamage = 0
	self.NextBulletCount = 1
	self.CurrentPhrase = nil

end

function SWEP:Deploy()

	return true

end

function SWEP:PrimaryAttack()

	--if self:GetOwner():IsBot() then return end

	if IsFirstTimePredicted() then

		self.NextBulletDamage = 0
		self.NextBulletCount = 1

		local wordToFire, phrase = self:ConsumeWord()
		if wordToFire == nil or wordToFire.score == nil or wordToFire.score == 0 then 
			self:EmitSound(self.Primary.Empty, 75, 100)
		else
			local str = phrase.phrase:sub(wordToFire.first, wordToFire.last)
			print(str .. " : SCORE: " .. (wordToFire.score or 0))

			self:EmitSound(self.Primary.Sound, 75, 120 - math.min(wordToFire.score * 7, 105))

			self.NextBulletDamage = wordToFire.score
			self.NextBulletStr = str

			if CLIENT then
				self.Shots[#self.Shots+1] = {
					score = wordToFire.score * 3,
					t = 0,
				}
			end
		end

		if self.NextBulletDamage ~= 0 then

			GAMEMODE:FireWord( 
				self:GetOwner(), 
				self:GetOwner():GetShootPos(), 
				self:GetOwner():GetAimVector(),
				0,
				self.NextBulletDamage * 3,
				self.NextBulletStr or "<word>" )

		end

	end

	if self.NextBulletDamage == 0 then
		self:SetNextPrimaryFire( CurTime() + 0.4 )
		return
	end


	self:ShootEffects()

	self:SetNextPrimaryFire( CurTime() + 0.4 )

end

function SWEP:SecondaryAttack()

	if IsFirstTimePredicted() then

		local score, count, strings = self:ConsumePhrase()
		self.NextBulletDamage = math.ceil(score / 4)
		self.NextBulletSpread = math.Remap(score, 0, 100, 0.4, 0.01)
		self.NextBulletCount = count
		self.NextBulletStrings = strings

		if score == 0 then
			self:EmitSound(self.Secondary.Empty, 75, 100)
		else
			self:EmitSound(self.Secondary.Sound, 75, 120 - math.min(score/2, 105))

			if CLIENT then
				self.Shots[#self.Shots+1] = {
					score = self.NextBulletDamage .. " x" .. self.NextBulletCount,
					t = 0,
				}
			end
		end

		if score ~= 0 then

			local spread = self.NextBulletSpread or 0.4
			for i=1, self.NextBulletCount do

				GAMEMODE:FireWord( 
					self:GetOwner(), 
					self:GetOwner():GetShootPos(), 
					self:GetOwner():GetAimVector(),
					spread,
					self.NextBulletDamage * 3,
					self.NextBulletStrings[i] or "<word>",
					i )

			end

		end

	end

	if self.NextBulletDamage == 0 then
		self:SetNextSecondaryFire( CurTime() + 1 )
		return
	end

	

	self:ShootEffects()

	--[[self:GetOwner():FireBullets({
		Num = self.NextBulletCount,
		Attacker = self:GetOwner(),
		Damage = self.NextBulletDamage,
		Force = 10,
		Dir = self:GetOwner():GetAimVector(),
		Src = self:GetOwner():GetShootPos(),
		IgnoreEntity = self:GetOwner(),
		Spread = Vector(spread,spread,0),
	})]]

	self:SetNextSecondaryFire( CurTime() + 1 )

end

function SWEP:CustomAmmoDisplay()

	self.AmmoDisplay = self.AmmoDisplay or {} 
	self.AmmoDisplay.Draw = false
 
	if self.Primary.ClipSize > 0 then
		self.AmmoDisplay.PrimaryClip = 0 --self:Clip1()
		self.AmmoDisplay.PrimaryAmmo = 0 --self:Ammo1()
	end
	if self.Secondary.ClipSize > 0 then
		self.AmmoDisplay.SecondaryAmmo = 0
	end
 
	return self.AmmoDisplay

end

function SWEP:ConsumeWord()

	local phrase = self.CurrentPhrase
	if phrase == nil then return end

	local word = phrase.words[1]
	if word == nil then return end

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

function SWEP:ConsumePhrase()

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

function SWEP:GivePhrase( scoring )

	scoring = table.Copy(scoring)

	self.Phrases[#self.Phrases+1] = scoring

	if not self.CurrentPhrase then
		self.CurrentPhrase = scoring
	end

	self:OnPhraseAdded(scoring)

end

function SWEP:OnWordConsumed(phrase, word)

	if #phrase.words == 0 then
		table.remove(self.Phrases, 1)
		self.CurrentPhrase = self.Phrases[1]
	end

	if CLIENT then 
		self:EjectWord(phrase, word)
		self:ComputeHUDLayout() 
	end

end

function SWEP:OnPhraseAdded(phrase)

	if CLIENT then self:ComputeHUDLayout() end

end

function SWEP:EjectWord(phrase, consumed)

	local phraseInLayout = nil
	local wordInLayout = nil
	for _, phrase in ipairs(self.HUDLayout.phrases) do
		for _, word in ipairs(phrase.layout) do
			if word.word == consumed then
				wordInLayout = word
				phraseInLayout = phrase
				break
			end
		end
	end

	if wordInLayout then

		local tiles = textfx.MakeTiles( wordInLayout.str, "WordAmmoFont" )
		local layout = textfx.LayoutLeft( tiles, wordInLayout.x, phraseInLayout.y )
		local cr,cg,cb = wordInLayout.col:Unpack()

		for _, e in ipairs(layout) do
			e.vx = math.Rand(-800,-100)
			e.vy = math.Rand(-300,-50)
			e.vr = math.Rand(-360,360)*3
			e.rate = math.Rand(1,4)
			e.cr = cr
			e.cg = cg
			e.cb = cb
		end

		self.WordEject[#self.WordEject + 1] = {
			t = 0,
			layout = layout,
		}

	else
		ErrorNoHalt("FAILED TO FIND EJECT WORD")
	end

end

function SWEP:ProcessEject(entry)

	local dt = FrameTime() * 2
	entry.t = math.min(entry.t + dt, 1)

	for _, e in ipairs(entry.layout) do
		e.x = e.x + e.vx * dt
		e.y = e.y + e.vy * dt
		e.vy = e.vy + 800 * dt
		e.a = math.max(e.a - e.rate * dt, 0)
		e.r = e.r + e.vr * dt
		e.sx = e.sx + dt*1.5
		e.sy = e.sy + dt*1.5
	end
	if entry.t >= 1 then
		return false
	end

	textfx.DrawLayout( entry.layout )

	return true

end

function SWEP:ComputeHUDLayout()

	self.HUDLayout = { phrases = {} }

	--print("Recompute hud layout : " .. ScrW() .. " x " .. ScrH())

	surface.SetFont("WordAmmoFont")

	local function AppendPhrase(p, y)

		local layoutPhrase = {}

		local x = ScrW() - 100
		for i=#p.words, 1, -1 do
			local w = p.words[i]
			local col = Color( 255, 255, 255, 255 )

			if bit.band(w.flags, WORD_VALID) == 0 then
				col = Color(255,100,100,255)
			else
				if bit.band(w.flags, WORD_COOLDOWN) ~= 0 then
					col = Color(60,60,128,255)
				end
				if bit.band(w.flags, WORD_DUPLICATE) ~= 0 then
					col.b = 0
				end
			end

			local str = p.phrase:sub(w.first, w.last) .. " "
			local tw, th = surface.GetTextSize(str) 
			x = x - tw

			layoutPhrase[#layoutPhrase+1] =
			{
				word = p.words[i],
				x = x,
				col = col,
				str = str,
			}
		end

		self.HUDLayout.phrases[#self.HUDLayout.phrases+1] = 
		{
			phrase = p,
			layout = layoutPhrase,
			y = y,
		}

	end

	local y = ScrH() - 200
	for i=1, #self.Phrases do
		AppendPhrase(self.Phrases[i], y)
		y = y - 30
	end

	return self.HUDLayout

end

function SWEP:DrawHUD()

	self.Shots = self.Shots or {}
	self.HUDLayout = self.HUDLayout or self:ComputeHUDLayout()

	for i=#self.Shots, 1, -1 do

		local x = self.Shots[i]
		if x.t > 1 then table.remove(self.Shots,i) continue end

		x.t = x.t + FrameTime()
		local a = 1 - math.min(x.t, 1)

		draw.SimpleText(x.score, "WordAmmoFont", ScrW()/2 + 80, ScrH()/2 + x.t * 100, Color(255,255,255,255*a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	end

	for _, phrase in ipairs(self.HUDLayout.phrases) do

		for _, word in ipairs(phrase.layout) do

			 draw.SimpleText(
			 	word.str, 
			 	"WordAmmoFont", 
			 	word.x, 
			 	phrase.y, 
			 	word.col, 
			 	TEXT_ALIGN_LEFT, 
			 	TEXT_ALIGN_TOP)

		end

	end

	for i=#self.WordEject, 1, -1 do
		if not self:ProcessEject( self.WordEject[i] ) then
			table.remove( self.WordEject, i )
		end
	end

end

function SWEP:DoDrawCrosshair( x, y )

	if GAMEMODE:IsChatOpen() then return true end

	surface.SetDrawColor( 255, 255, 255, 180 )
	surface.DrawLine( x - 4, y, x - 0, y )
	surface.DrawLine( x + 0, y, x + 4, y )
	surface.DrawLine( x, y - 4, x, y - 0 )
	surface.DrawLine( x, y + 0, x, y + 4 )

	--surface.DrawOutlinedRect( x - 32, y - 32, 64, 64 )
	return true
end