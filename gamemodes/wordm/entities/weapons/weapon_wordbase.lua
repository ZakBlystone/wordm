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
	self.WordEject = {}
	self.NextBulletDamage = 0
	self.NextBulletCount = 1

end

function SWEP:Deploy()

	return true

end

function SWEP:PrimaryAttack()

	--if self:GetOwner():IsBot() then return end

	if IsFirstTimePredicted() then

		self.NextBulletDamage = 0
		self.NextBulletCount = 1
		self.NextBulletDelay = 0
		self.NextBulletSpead = 0
		self.LastFireTime = self.LastFireTime or 0

		local wordToFire, phrase = self:ConsumeWord()
		if wordToFire == nil or wordToFire.score == nil or wordToFire.score == 0 then
			if self.LastFireTime + 0.5 < CurTime() then
				self:EmitSound(self.Primary.Empty, 75, 100)
			end
		else
			local str = phrase.phrase:sub(wordToFire.first, wordToFire.last)
			print(str .. " : SCORE: " .. (wordToFire.score or 0))

			self:EmitSound(self.Primary.Sound, 75, 140 - math.min(wordToFire.score * 2, 105))

			self.NextBulletScore = wordToFire.score
			self.NextBulletFlags = wordToFire.flags
			self.NextBulletDamage = wordToFire.score
			self.NextBulletStr = str
			self.NextBulletDelay = (wordToFire.last - wordToFire.first) * 0.1
			self.NextBulletDelay = math.min(self.NextBulletDelay, 0.6)

			local len = math.Clamp(wordToFire.last - wordToFire.first, 1, 6)
			self.NextBulletSpead = math.Remap(len, 1, 6, 0.13, 0.0)
			self.LastFireTime = CurTime()

			if CLIENT then
				self.Shots[#self.Shots+1] = {
					score = wordToFire.score, --* 4,
					t = 0,
				}
			end
		end

		if self.NextBulletDamage ~= 0 then

			GAMEMODE:FireWord( 
				self:GetOwner(), 
				self:GetOwner():GetShootPos(), 
				self:GetOwner():GetAimVector(),
				self.NextBulletSpead or 0,
				self.NextBulletDamage, --* 4,
				self.NextBulletScore or 0,
				self.NextBulletFlags or 0,
				self.NextBulletStr or "<word>" )

		end

	end

	if self.NextBulletDamage == 0 then
		self:SetNextPrimaryFire( CurTime() + 0.4 )
		return
	end


	self:ShootEffects()

	self:SetNextPrimaryFire( CurTime() + (self.NextBulletDelay or 0.4) )

end

function SWEP:SecondaryAttack()

	if true then return end


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

	local owner = self:GetOwner()
	if IsValid(owner) then return owner:ConsumeWord() end

end

function SWEP:ConsumePhrase()

	local owner = self:GetOwner()
	if IsValid(owner) then return owner:ConsumePhrase() end

end

function SWEP:OnWordConsumed(phrase, word)

	if CLIENT then 
		self:EjectWord(phrase, word)
		self:ComputeHUDLayout() 
	end

end

function SWEP:OnPhraseAdded(phrase)

	if CLIENT then self:ComputeHUDLayout() end

end

function SWEP:OnPhrasesCleared()

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

G_WEAPON_PHRASE_LOC = {0,0}
function SWEP:ComputeHUDLayout()

	self.HUDLayout = { phrases = {} }

	--print("Recompute hud layout : " .. ScrW() .. " x " .. ScrH())

	surface.SetFont("WordAmmoFont")

	local function AppendPhrase(p, y)

		local layoutPhrase = {}

		local x = ScrW() - 100
		G_WEAPON_PHRASE_LOC = {x,y}

		for i=#p.words, 1, -1 do
			local w = p.words[i]
			local cr,cg,cb = GAMEMODE:GetWordColor(w.score, w.flags)
			local col = Color( cr,cg,cb, 255 )
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
	local phrases = self:GetOwner():GetPhrases()
	for i=1, #phrases do
		AppendPhrase(phrases[i], y)
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

		x.t = x.t + FrameTime()/2
		local a = 1 - math.min(x.t, 1)

		draw.SimpleText(x.score, "WordAmmoFont", ScrW()/2 + 80, ScrH()/2 + x.t * 200, Color(255,255,255,255*a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

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

function SWEP:PreDrawViewModel()



end

function SWEP:ViewModelDrawn()


end

local _rotated = Angle()

function SWEP:PostDrawViewModel( vm, weapon, ply )

	--[[for i=1, self:GetOwner():GetViewModel():GetBoneCount() do
		print( i, self:GetOwner():GetViewModel():GetBoneName(i))
	end]]

	local phrase = self:GetOwner():GetCurrentPhrase()
	if phrase == nil then return end

	local word = phrase.words[1]
	if word == nil then return end

	local cr,cg,cb = GAMEMODE:GetWordColor(word.score, word.flags)
	local str = phrase.phrase:sub(word.first, word.last)
	if not str then return end

	local vm = self:GetOwner():GetViewModel()
	local bone = vm:LookupBone("357_cylinder")
	local mmod = true
	if not bone then bone = vm:LookupBone("Cylinder") mmod = false end
	if not bone then return end

	local b = vm:GetBoneMatrix(bone)
	local pos = b:GetTranslation()
	local ang = b:GetAngles()

	surface.SetFont("WordAmmoFont")
	surface.SetTextColor(cr,cg,cb)

	_rotated:Set(ang)
	
	if mmod then
		_rotated:RotateAroundAxis(_rotated:Forward(), 180)
	else
		_rotated:RotateAroundAxis(_rotated:Right(), 90)
	end

	render.SetColorMaterial()
	--render.DrawBox(pos + ang:Right()*-2, ang, Vector(-1,-1,-1), Vector(1,1,1), Color( 255, 255, 255, 255 ))

	render.CullMode(MATERIAL_CULLMODE_CW)

	cam.Start3D2D( pos - _rotated:Right()*4, _rotated, 0.08 )

	surface.SetTextPos(0, 0)
	surface.DrawText( str )

	cam.End3D2D()

	render.CullMode(MATERIAL_CULLMODE_CCW)

	_rotated:Set(ang)
	if mmod then
		_rotated:RotateAroundAxis(_rotated:Forward(), 180)
	else
		_rotated:RotateAroundAxis(_rotated:Right(), 90)
	end
	_rotated:RotateAroundAxis(_rotated:Right(), 90)

	cam.Start3D2D( pos - _rotated:Right()*1 + _rotated:Up()*3 + _rotated:Forward() * 0.5, _rotated, 0.03 )

	surface.SetTextPos(0, 0)
	surface.DrawText( tostring(word.score or 0) )

	cam.End3D2D()

end