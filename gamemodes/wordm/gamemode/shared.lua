AddCSLuaFile()

include "player_class/player_common.lua"

local sv_debugWordBullets = CreateConVar("sv_debugwordbullets", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "show network debugging")

GM.Name     = "WorDM"
GM.Author   = "Zak"

-- WORD FLAGS ( 4 bits )
WORD_BITS = 4
WORD_SCOREBITS = 16
WORD_POSBITS = 10
WORD_COOLDOWNBITS = 10

PHRASE_LENBITS = 10

WORD_VALID = 1
WORD_COOLDOWN = 2
WORD_SECRET = 4
WORD_DUPLICATE = 8

TIME_TO_PHRASE = 0.5

function SendWordScore( t )

	net.WriteUInt(t.flags, WORD_BITS)
	net.WriteUInt(t.first, WORD_POSBITS)
	net.WriteUInt(t.last, WORD_POSBITS)

	if bit.band(t.flags, WORD_VALID) ~= 0 then
		net.WriteUInt(t.score, WORD_SCOREBITS)
		net.WriteUInt(math.floor(t.cooldown), WORD_COOLDOWNBITS)
	end

	if bit.band(t.flags, WORD_COOLDOWN) ~= 0 then
		net.WriteFloat(t.cooldown)
	end

end

function RecvWordScore()

	local t = {}
	t.flags = net.ReadUInt(WORD_BITS)
	t.first = net.ReadUInt(WORD_POSBITS)
	t.last = net.ReadUInt(WORD_POSBITS)

	if bit.band(t.flags, WORD_VALID) ~= 0 then
		t.score = net.ReadUInt(WORD_SCOREBITS)
		t.cooldown = CurTime() + net.ReadUInt(WORD_COOLDOWNBITS)
	end

	if bit.band(t.flags, WORD_COOLDOWN) ~= 0 then
		t.cooldown = net.ReadFloat()
	end

	return t

end

function SendPhraseScore( t )

	net.WriteString(t.phrase)
	net.WriteUInt(#t.words, PHRASE_LENBITS)
	for i=1, #t.words do
		SendWordScore(t.words[i])
	end

end

function RecvPhraseScore()

	local t = { words = {} }
	t.phrase = net.ReadString()
	local len = net.ReadUInt(PHRASE_LENBITS)
	for i=1, len do
		t.words[#t.words+1] = RecvWordScore()
	end
	return t

end

function GM:HandlePlayerPhraseSynced( ply, phrase )

	--print("SYNC PHRASE: " .. tostring(phrase.phrase))

	local weap = ply:GetActiveWeapon()
	if weap.GivePhrase then
		weap:GivePhrase( phrase )
	end

end

local function SpreadRandom(x)

	return util.SharedRandom("spread-calc-"..x, -1, 1, CurTime())

end

local function ApplySpread( dir, spread, idx )

	local a = dir:Angle()
	local right = a:Right()
	local up = a:Up()
	local min, max = -1, 1
	local bias = 1
	local shotbias = (max - min) * bias + min
	local flat = math.abs(shotbias * 0.5)

	idx = idx or 0

	local x,y
	for i=1, 100 do
		x = SpreadRandom(0*4 + idx) * flat + SpreadRandom(1*4 + idx) * (1-flat)
		y = SpreadRandom(2*4 + idx) * flat + SpreadRandom(3*4 + idx) * (1-flat)
		if shotbias < 0 then
			x = x >= 0 and 1 - x or -1 - x
			y = y >= 0 and 1 - y or -1 - y
		end
		if x*x+y*y <= 1 then break end
	end

	dir:Set( dir + x * spread * right + y * spread * up )
	dir:Normalize()
	return dir

end

G_WORDS_FIRED = G_WORDS_FIRED or {}

local wmeta = {}
wmeta.__index = wmeta

function wmeta:Move()

	--local ft = FrameTime()

	self.lt = self.lt or 0

	local t = (CurTime() - self.t)
	local startpos = self.org + self.dir * self.lt
	local endpos = self.org + self.dir * t * self.speed

	self.lt = t

	if not IsValid(self.owner) then 
		print("NO OWNER")
		return false 
	end

	local trace = {
		start = self.pos,
		endpos = endpos,
		filter = self.owner,
		mask = MASK_SHOT,
	}

	if not self.owner:IsBot() then self.owner:LagCompensation(true) end

	local b,e = pcall(function()
		local tr = util.TraceLine(trace)
		if tr.Hit then
			endpos = tr.HitPos

			print("HIT: " .. tostring(CurTime()))

			if not self.hit then
				self.hit = tr
				self:OnHit( tr )
			end

		end
	end)

	if not self.owner:IsBot() then self.owner:LagCompensation(false) end

	if not b then ErrorNoHalt(e) end

	self.pos = endpos
	return true

end

local zerovector = Vector(0,0,0)

function wmeta:OnHit( tr )

	self.hitTime = CurTime()

	if sv_debugWordBullets:GetBool() then

		debugoverlay.Box(tr.HitPos, 
			SERVER and Vector(-1,-1,0) or Vector(-1,-1,10), 
			SERVER and Vector(1,1,10) or Vector(1,1,20), 
			2, 
			SERVER and Color( 80, 255, 80 ) or Color( 255, 80, 80 ))

	end

	if tr.Entity then

		if tr.HitBoxBone then
			local mtx = tr.Entity:GetBoneMatrix( tr.HitBoxBone )
			mtx:Invert()
			self.attachBone = tr.HitBoxBone
			self.attach = tr.Entity
			self.attachLocal = mtx * tr.HitPos

			mtx:SetTranslation(zerovector)
			self.attachLocalDir = mtx * self.dir
		end

		if tr.Entity:IsPlayer() then

			if CLIENT then

				local ed = EffectData()
				ed:SetOrigin( tr.HitPos )
				util.Effect("BloodImpact", ed)

			else

				local inf = DamageInfo()
				inf:SetDamage( self.damage or 0 )
				inf:SetDamageType( DMG_BULLET )
				inf:SetAttacker( self.owner )
				inf:SetDamageForce( self.dir * (1000 * self.damage) )
				inf:SetDamagePosition( tr.HitPos )
				tr.Entity:TakeDamageInfo( inf )

			end

		end

	end

end

function wmeta:Update()

	if not IsFirstTimePredicted() then return true end

	if not self.hit then
		return self:Move()
	elseif IsValid(self.attach) then
		self.wasattached = true
		if self.attach:IsPlayer() and not self.attach:Alive() then
			if self.attach:GetRagdollEntity() then
				self:TransferToRagdoll(self.attach, self.attach:GetRagdollEntity())
			end
		end
	elseif self.wasattached then
		return false
	end

	if SERVER then print("DONE") return false end

	return true

end

function wmeta:TransferToRagdoll(ply, ragdoll)

	self.attach = ragdoll

	if CLIENT then

		--[[if self.hitTime and CurTime() - self.hitTime < 0.2 then

			local physnum = ragdoll:TranslateBoneToPhysBone(self.attachBone)
			local phys = ragdoll:GetPhysicsObjectNum(physnum)
			if phys:IsValid() then
				phys:EnableMotion(false)
			end

			self.skewer = true

		end]]

	end

end

local _delta = Vector()
local _projected = Vector()
local _final = Vector()
local _rotated = Angle()

function wmeta:Draw()

	local eye = EyePos()

	if IsValid(self.attach) then
		if self.attach == LocalPlayer() then return end

		local mtx = self.attach:GetBoneMatrix( self.attachBone )
		self.pos = mtx * self.attachLocal

		mtx:SetTranslation(zerovector)
		self.rdir = (mtx * self.attachLocalDir)
		self.angle = self.rdir:Angle()
	end

	if not self.tw then
		self.tw, self.th = surface.GetTextSize( self.str or "word" )
	end

	local tail = self.rdir or self.dir
	_delta:Set(eye)
	_delta:Sub(self.pos)

	_projected:Set(tail)
	_projected:Mul(tail:Dot(_delta))
	_projected:Add(self.pos)

	_delta:Set(eye)
	_delta:Sub(_projected)
	_delta:Normalize()

	local x = self.angle:Right():Dot(_delta)
	local y = -self.angle:Up():Dot(_delta)
	local a = math.atan2(y,x)*57.3 + 90
	local rev = false
	local embed = 2
	local scale = 0.3

	if self.skewer then
		embed = self.tw * scale - 1
	end

	if a < 0 or a > 180 then 
		rev = true 
		_final:Set(tail)
		_final:Mul(-self.tw * scale + embed)
		_final:Add(self.pos)
	else
		_final:Set(tail)
		_final:Mul(embed)
		_final:Add(self.pos)
	end

	_rotated:Set( self.angle )
	_rotated:RotateAroundAxis(tail, a)

	if not self.hit then
		render.SetColorMaterial()
		render.DrawBox( self.pos, self.angle, Vector(-self.tw * scale,-2,-2), Vector(2,2,2), Color(255,180,255))
	end

	cam.Start3D2D( _final, _rotated, rev and -scale or scale )
	surface.SetTextPos(-self.tw, -self.th*.5)
	surface.SetTextColor(255,255,255,255)
	surface.DrawText( tostring(self.str) )
	cam.End3D2D()

end

for _,v in ipairs(G_WORDS_FIRED) do
	setmetatable(v, wmeta)
end

function GM:FireWord(owner, pos, dir, spread, damage, str, idx)

	spread = spread or 0
	local speed = 124000

	if spread ~= 0 then ApplySpread(dir, spread, idx) end

	G_WORDS_FIRED[#G_WORDS_FIRED+1] = setmetatable({
		t = CurTime(),
		owner = owner,
		org = pos,
		pos = Vector(pos),
		dir = dir,
		damage = damage or 1,
		str = str,
		speed = speed,
		angle = dir:Angle(),
	}, wmeta)

	if SERVER then
		net.Start("wordfire_msg")
		net.WriteEntity( owner )
		net.WriteVector( pos )
		net.WriteVector( pos + dir * 1000 )
		net.WriteFloat( damage )
		net.WriteString( str )
		net.SendOmit( owner )
	end

end

if CLIENT then

	net.Receive("wordfire_msg", function()
		local owner = net.ReadEntity()
		local pos = net.ReadVector()
		local dir = net.ReadVector()
		local damage = net.ReadFloat()
		local str = net.ReadString()

		dir:Sub(pos)
		dir:Normalize()

		GAMEMODE:FireWord( owner, pos, dir, 0, damage, str )
	end)

end

function GM:UpdateFiredWords( ply )

	if CLIENT and #G_WORDS_FIRED > 50 then
		table.remove(G_WORDS_FIRED, 1)
	end

	for i=#G_WORDS_FIRED, 1, -1 do

		if G_WORDS_FIRED[i].owner == ply then

			if not G_WORDS_FIRED[i]:Update() then

				table.remove(G_WORDS_FIRED, i)

			end

		end

	end

end

function GM:DrawFiredWords()

	for _, w in ipairs(G_WORDS_FIRED) do

		w:Draw()

	end

end

function GM:PlayerTick( ply, mv )

	if SERVER then

		self:UpdateFiredWords( ply )

	else

		for _,v in ipairs(player.GetAll()) do

			self:UpdateFiredWords( v )

		end

	end

end