AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Model = "models/player/kleiner.mdl"

function ENT:Initialize()

	if SERVER then

		self:SetModel(self.Model)
		self:SetMoveType(MOVETYPE_NONE)

	end

end

function ENT:Think()

	if CLIENT then
		self:UseClientSideAnimation()
		self:SetSequence("idle_all_01")
	end

end

function ENT:Draw()

	self:DrawModel()

end