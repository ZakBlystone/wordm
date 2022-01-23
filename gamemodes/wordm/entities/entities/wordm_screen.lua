AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Model = "models/props_phx/construct/metal_plate2x2.mdl"

function ENT:Initialize()

	if SERVER then

		self:SetModel(self.Model)
		self:SetMoveType(MOVETYPE_NONE)

	end

end

function ENT:Think()

end

function ENT:Draw()

	self:DrawModel()

end