AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Model = "models/combine_helicopter/helicopter_bomb01.mdl"

function ENT:Initialize()

	if SERVER then

		self:SetModel(self.Model)
		self:SetMoveType(MOVETYPE_FLYGRAVITY)
		self:SetSolid( SOLID_BBOX )
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetCollisionBounds( Vector(-16,-16,-16), Vector(16,16,16) )
		self:SetTrigger( true )

	end

end

function ENT:SetPhrases( phrases, ply )

	self.Phrases = table.Copy( phrases )
	self.Owner = ply

	table.sort(self.Phrases, function(a,b)
		return a.total > b.total
	end)

end

function ENT:Think()

end

local noteMaterial = Material("icon16/book.png", "ignorez")
local noteMaterial2 = Material("icon16/book_open.png", "ignorez")

function ENT:Draw()

	self:DestroyShadow()
	--self:DrawModel()


	local pos = self:GetPos()

	render.SetMaterial( CurTime() % 0.5 > 0.25 and noteMaterial or noteMaterial2 )
	render.DrawSprite( pos, 32, 32, Color(255,255,255,180) )

end

function ENT:StartTouch( ent )

	if CLIENT then return end

	if ent == self.Owner then print("TOUCH WAS OWNER") return end
	if not ent:IsPlayer() then return end
	if not ent:Alive() then return end
	if self.Phrases == nil then print("PHRASES NOT SET YET!") return end

	if self.Touched then print("TOUCHED MULTIPLE TIMES") return end
	self.Touched = true

	self:EmitSound("wordm/word_pickup.wav", 75, 100, 1)

	self:Remove()

	if self.Phrases ~= nil and #self.Phrases > 0 then

		GAMEMODE:ServerSendPhrase( ent, self.Phrases[1].phrase, true )

	else

		print("ERROR, NO PHRASE TO GIVE")

	end

end

if SERVER then

	concommand.Add("test_drop", function(p)

		local tr = p:GetEyeTrace()
		if tr.Hit then
			local ent = ents.Create("wordm_drop_notepad")
			ent:SetOwner( p )
			ent:SetPos( tr.HitPos + Vector(0,0,300) )
			ent:Spawn()
		end

	end)

end