AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Model = "models/props_phx/construct/metal_plate2x2.mdl"

WORDSCREENTYPE_INACTIVE = 0
WORDSCREENTYPE_HEALTH = 1
WORDSCREENTYPE_WORDS = 2

function ENT:Initialize()

	if SERVER then

		self:SetModel(self.Model)
		self:SetMoveType(MOVETYPE_NONE)

	end

end

function ENT:SetupDataTables()

	self:NetworkVar( "Int", 0, "Type" )
	self:NetworkVar( "String", 0, "Word" )
	self:NetworkVar( "Float", 0, "Timer" )

end

function ENT:IsActive()

	return self:GetType() ~= WORDSCREENTYPE_INACTIVE

end

function ENT:MakeInactive()

	self:SetType( WORDSCREENTYPE_INACTIVE )

end

function ENT:MakeActive( force, newType )

	if CLIENT then return end

	local t = self:GetType()
	if t ~= WORDSCREENTYPE_INACTIVE and not force then return end

	self:SetWord( GAMEMODE:RandomWordWithCount(7):upper() )

	if newType == nil then
		newType = {WORDSCREENTYPE_HEALTH, WORDSCREENTYPE_WORDS}
		newType = newType[math.random(1,#newType)]
	end

	self:SetType( newType )
	self:SetTimer( CurTime() )

end

function ENT:ApplyToPlayer(ply)

	if CLIENT then return end

	local t = self:GetType()

	if t == WORDSCREENTYPE_INACTIVE then return end
	if t == WORDSCREENTYPE_HEALTH then

		ply:SetHealth( math.min(ply:Health() + 20, 125) )

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

function ENT:GetTypeString()

	local t = self:GetType()
	if t == WORDSCREENTYPE_HEALTH then return "+20 Health" end
	if t == WORDSCREENTYPE_WORDS then return "+4 Words" end
	return "..."

end

function ENT:Draw()

	self:DrawModel()

	local surf = self:GetPos() + self:GetAngles():Up() * 4.2
	local scale = 0.25
	local width = 48 / scale
	local height = 48 / scale
	local screen = textfx.Box(-width,-height,width*2,height*2)

	cam.Start3D2D(surf, self:GetAngles(), scale)

	local b,e = pcall(function()

		local blink = CurTime() - self:GetTimer()
		local bdt = (0.5 - math.min(blink, 0.5)) * 2

		surface.SetDrawColor(bdt*255,bdt*255,bdt*255,255)
		surface.DrawRect(-width,-height,width*2,height*2)
		
		local title = textfx.Builder(self:GetTypeString(), "WordAmmoFont"):Box(10,10):Color(100,255,100,255)
		:HAlignTo(screen, "center")
		:VAlignTo(screen, "top")
		:Draw()

		if self:GetWord() ~= "" and self:GetType() ~= WORDSCREENTYPE_INACTIVE then

			local word = textfx.Builder(self:GetWord(), "GameStateTitle"):Box(10,10):Color(0,0,0,255)
			:HAlignTo(screen, "center")
			:VAlignTo(screen, "center")
			:DrawRounded(110,110,255,255,8)

			word:Draw()

		end

	end)

	cam.End3D2D()

	if not b then print(e) end

end