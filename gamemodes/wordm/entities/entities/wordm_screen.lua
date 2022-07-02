AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Model = "models/props_phx/construct/metal_plate2x2.mdl"

WORDSCREENTYPE_INACTIVE = 0
WORDSCREENTYPE_HEALTH = 1
WORDSCREENTYPE_WORDS = 2
WORDSCREENTYPE_MULTI = 3

MAX_HEALTH_TO_GIVE = 125

function ENT:Initialize()

	if SERVER then

		self:SetModel(self.Model)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

	end

end

function ENT:SetupDataTables()

	self:NetworkVar( "Int", 0, "Type" )
	self:NetworkVar( "String", 0, "Word1" )
	self:NetworkVar( "String", 1, "Word2" )
	self:NetworkVar( "Float", 0, "Timer" )

end

function ENT:IsActive()

	return self:GetType() ~= WORDSCREENTYPE_INACTIVE

end

function ENT:MakeInactive()

	self:SetType( WORDSCREENTYPE_INACTIVE )

end

function ENT:PickRandomWordForScreen()

	local chances = 100

	::pickword::
	chances = chances - 1
	local word = GAMEMODE:RandomWordWithCount(7):upper()
	for _,v in ipairs(ents.FindByClass("wordm_screen")) do

		if chances == 0 then ErrorNoHalt("FAILED TO CHOOSE RANDOM WORD FOR SCREEN PROPERLY") break end
		if v:GetWord1() == word then goto pickword end
		if v:GetWord2() == word then goto pickword end

	end

	return word

end

function ENT:MakeActive( force, newType )

	if CLIENT then return end

	local t = self:GetType()
	if t ~= WORDSCREENTYPE_INACTIVE and not force then return end

	self:SetWord1( self:PickRandomWordForScreen() )
	self:SetWord2( self:PickRandomWordForScreen() )

	--[[if newType == nil then
		newType = {WORDSCREENTYPE_HEALTH, WORDSCREENTYPE_WORDS}
		newType = newType[math.random(1,#newType)]
	end]]
	newType = WORDSCREENTYPE_MULTI

	self:SetType( newType )
	self:SetTimer( CurTime() )

end

function ENT:ApplyToPlayer(ply, selected)

	if CLIENT then return end

	local t = self:GetType()

	if t == WORDSCREENTYPE_INACTIVE then return end
	if t == WORDSCREENTYPE_MULTI then

		if selected == 1 then t = WORDSCREENTYPE_WORDS end
		if selected == 2 then t = WORDSCREENTYPE_HEALTH end

	end

	if t == WORDSCREENTYPE_HEALTH then

		ply:SetHealth( math.min(ply:Health() + 20, MAX_HEALTH_TO_GIVE) )
		ply:EmitSound("items/smallmedkit1.wav")

	end

	if t == WORDSCREENTYPE_WORDS then

		local numWords = 4

		timer.Simple(1, function()

			if IsValid(ply) and ply:IsPlaying() then

				GAMEMODE:GiveWords( ply, numWords, 5 )

			end

		end)

	end

	self:EmitSound("wordm/word_pickup.wav", 75, 100, 1)

	self:SetTimer( CurTime() )
	self:MakeInactive()

end

function ENT:Think()

	--[[if self:GetType() == WORDSCREENTYPE_INACTIVE then

		if CurTime() - self:GetTimer() > 30 then

			self:MakeActive()

		end

	end]]

end

function ENT:GetTypeString(type)

	local t = type or self:GetType()
	if self:GetType() == WORDSCREENTYPE_INACTIVE then return "---" end
	if t == WORDSCREENTYPE_HEALTH then return "+20 Health" end
	if t == WORDSCREENTYPE_WORDS then return "+4 Words" end
	return "---"

end

function ENT:Draw()

	self:DrawModel()

	local surf = self:GetPos() + self:GetAngles():Up() * 4.2
	local scale = 0.25
	local width = 48 / scale
	local height = 48 / scale
	local screen = textfx.Box(-width,-height,width*2,height*2)
	local active = self:GetType() ~= WORDSCREENTYPE_INACTIVE

	cam.Start3D2D(surf, self:GetAngles(), scale)

	local b,e = pcall(function()

		local blink = CurTime() - self:GetTimer()
		local bdt = (0.5 - math.min(blink, 0.5)) * 2

		surface.SetDrawColor(bdt*255,bdt*255,bdt*255,255)
		surface.DrawRect(-width,-height,width*2,height*2)
		
		if active then
			textfx.Builder("Type your choice", "CooldownWordFont"):Box(10,10):Color(255,255,255,255)
			:HAlignTo(screen, "center")
			:VAlignTo(screen, "center")
			:Draw()
		end

		local top = textfx.Builder(self:GetTypeString(WORDSCREENTYPE_WORDS), "WordAmmoFont"):Box(10,10):Color(100,255,100,255)
		:HAlignTo(screen, "center")
		:VAlignTo(screen, "top")
		:Draw()

		local bottom = textfx.Builder(self:GetTypeString(WORDSCREENTYPE_HEALTH), "WordAmmoFont"):Box(10,10):Color(100,255,100,255)
		:HAlignTo(screen, "center")
		:VAlignTo(screen, "bottom")
		
		if LocalPlayer():Health() >= MAX_HEALTH_TO_GIVE and active then
			bottom:Color(120,100,100,255)
		end

		bottom:Draw()

		if self:GetWord1() ~= "" and active then
			textfx.Builder(self:GetWord1(), "GameStateTitle"):Box(10,10):Color(0,0,0,255)
			:HAlignTo(screen, "center")
			:VAlignTo(top, "after")
			:DrawRounded(110,110,255,255,8)
			:Draw()
		end

		if self:GetWord2() ~= "" and active then
			textfx.Builder(self:GetWord2(), "GameStateTitle"):Box(10,10):Color(0,0,0,255)
			:HAlignTo(screen, "center")
			:VAlignTo(bottom, "before")
			:DrawRounded(110,110,255,255,8)
			:Draw()
		end

	end)

	cam.End3D2D()

	if not b then print(e) end

end