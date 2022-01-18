if SERVER then
	AddCSLuaFile()
end

SWEP.PrintName				= "Word Gun"
SWEP.Slot					= 0

SWEP.ViewModel				= "models/weapons/c_pistol.mdl"
SWEP.WorldModel				= "models/weapons/w_pistol.mdl"

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
SWEP.Primary.Automatic		= false

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Ammo		= "none"

SWEP.Spawnable				= false
SWEP.RequestInfo			= {}

function SWEP:Initialize()

	self:SetWeaponHoldType( self.HoldType )
	self.Phrases = {}

end

function SWEP:Deploy()

	return true

end

function SWEP:PrimaryAttack()

	if IsFirstTimePredicted() then

		--if self:Clip1() <= 0 then return end
		if self.CurrentPhrase == nil then return end

		local wordToFire = self.CurrentPhrase.words[#self.CurrentPhrase.words]

		table.remove(self.CurrentPhrase.words, #self.CurrentPhrase.words)

		if #self.CurrentPhrase.words == 0 then
			table.remove(self.Phrases, 1)
			self.CurrentPhrase = self.Phrases[1]
		end

		if wordToFire.score == nil then 
			self:EmitSound(self.Primary.Empty, 75, 100)
			return 
		end


		print("SCORE: " .. wordToFire.score)
		self:EmitSound(self.Primary.Sound, 75, 120 - wordToFire.score * 10)

		self:ShootEffects()
		self:FireBullets({
			Attacker = self:GetOwner(),
			Damage = wordToFire.score,
			Force = wordToFire.score * 10,
			Dir = self:GetOwner():GetAimVector(),
			Src = self:GetOwner():GetShootPos(),
			IgnoreEntity = self:GetOwner(),
		})

		self:SetNextPrimaryFire( CurTime() + 0.1 )

	end

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

function SWEP:GivePhrase( scoring )

	self.Phrases[#self.Phrases+1] = scoring

	if not self.CurrentPhrase then
		self.CurrentPhrase = scoring
	end

end

function SWEP:DrawHUD()

	local function DrawPhrase(p, y)

		surface.SetFont("DermaLarge")
		local totalw = surface.GetTextSize(p.phrase)

		local x = ScrW() - 100 - totalw
		for i=1, #p.words do
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

			local tw, th = draw.SimpleText(p.phrase:sub(w.first, w.last) .. " ", "DermaLarge", x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			x = x + tw
		end

	end

	local y = ScrH() - 200
	for i=1, #self.Phrases do
		DrawPhrase(self.Phrases[i], y)
		y = y - 30
	end

end