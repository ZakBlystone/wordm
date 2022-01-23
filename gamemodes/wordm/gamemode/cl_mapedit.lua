
-- quick and dumb map editor for making maps more playable in this game

G_MAP_EDIT_STATE = G_MAP_EDIT_STATE or { active = false, lockedEnts = {}, removes = {}, local_ents = {} }

local state = G_MAP_EDIT_STATE

function SelectEntity(e)

	if not IsValid(e) then print("INVALID ENT") return end

	net.Start("mapedit_msg")
	net.WriteUInt(MAPEDIT_SELECT, MAPEDIT_BITS)
	net.WriteEntity(e)
	net.SendToServer()

end

function GM:DrawMapEditUI()

	if not state.active then return end

	draw.SimpleText("MAP EDITOR ACTIVE", "DermaDefault", ScrW()/2, 10, Color( 255, 10, 10, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	if state.selectedEntity then

		local e = state.selectedEntity
		draw.SimpleText(tostring(e.type or e.ent) .. " : " .. tostring(e.name) .. " : " .. tostring(e.id), 
			"DermaDefault", ScrW() - 120, ScrH() / 2, Color( 255, 10, 10, 255 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	end

end

local function DrawEntBox(e, col)

	render.DrawBox(e:pos(), e:angles(), e.mins, e.maxs, col or Color( 255, 255, 255, 100 ))

end

function GM:DrawMapEdit()

	if not state.active then return end

	render.SetColorMaterial()

	if state.selectedEntity then

		local e = state.selectedEntity
		DrawEntBox(e)

	end

	for _,v in pairs(state.lockedEnts or {}) do
		DrawEntBox(v, Color(100,80,0,100))
	end

	for _,v in pairs(state.removes or {}) do
		DrawEntBox(v, Color(255,0,0,100))
	end

	for _,v in ipairs(state.local_ents) do
		DrawEntBox(v, v.color or Color(128,128,128,100))
	end

end

function GM:ThinkMapEdit()

end

local _invraymtx = Matrix()
local _zerovector = Vector(0,0,0)

function GM:MapEdit_SelectLocal(pos, dir)

	print(type(pos))
	print(type(dir))

	local c, e = math.huge, nil
	for _,v in ipairs(state.local_ents) do

		_invraymtx:Identity()
		_invraymtx:SetTranslation(v:pos())
		_invraymtx:SetAngles(v:angles())
		_invraymtx:Invert()

		local ipos = _invraymtx * pos

		_invraymtx:SetTranslation(_zerovector)
		local idir = _invraymtx * dir

		local hit, t = IntersectRayBox(ipos, idir, v.mins, v.maxs)
		if hit and t < c then
			c, e = t, v
		end

	end
	return e

end

function GM:MapEdit_Select()

	local found = self:MapEdit_SelectLocal(
		LocalPlayer():GetShootPos(), 
		LocalPlayer():GetAimVector())

	if found then
		state.selectedEntity = found
		return
	end

	local tr = LocalPlayer():GetEyeTrace()
	if IsValid(tr.Entity) then
		print("Try Select: " .. tostring(tr.Entity))
		SelectEntity( tr.Entity )
	else
		print("Deselect")
		state.selectedEntity = nil
	end

end

function GM:MapEdit_ToggleLocked()

	if state.selectedEntity == nil then return end
	local e = state.selectedEntity
	if not e.id then return end
	if state.lockedEnts[e.id] then
		state.lockedEnts[e.id] = nil
	else
		state.lockedEnts[e.id] = e
	end

end

function GM:MapEdit_Remove()

	local e = state.selectedEntity
	if e ~= nil then

		if not e.id then

			table.RemoveByValue(state.local_ents, e)
			state.selectedEntity = nil
			return

		else

			if state.removes[e.id] then
				state.removes[e.id] = nil
			else
				state.removes[e.id] = e
			end

		end

	end

end

function GM:MapEdit_MakeLocalEnt(type, dotrace)

	local t = {
		pos = function(s) return s._pos end,
		angles = function(s) return s._angle end,
		_angle = Angle(0,0,0),
		_pos = Vector(0,0,0),
		mins = Vector(-4,-4,-4),
		maxs = Vector(4,4,4),
		type = type,
	}

	if not dotrace then

		local yaw = LocalPlayer():EyeAngles().y
		t._pos = LocalPlayer():GetPos()
		t._angle.yaw = yaw

		if string.find(type, "spawn") then
			t.mins = Vector(-16,-16,0)
			t.maxs = Vector(16,16,72)
			t.color = Color(80,255,80,100)
			if string.find(type, "lobby") then
				t.color = Color(80,180,255,100)
			end
		end

		state.local_ents[#state.local_ents+1] = t

	else

		local tr = LocalPlayer():GetEyeTrace()
		if tr.Hit then

			t._pos = tr.HitPos
			t._angle = tr.HitNormal:Angle()
			state.local_ents[#state.local_ents+1] = t

		end

	end

end

function GM:MapEditBindPress( bind, pressed, code )

	if state.active then
		if bind == "+attack" then
			if pressed then self:MapEdit_Select() end
			return true
		end
		if bind == "+attack2" then
			if pressed then self:MapEdit_ToggleLocked() end
			return true
		end
		if bind == "+reload" then
			if pressed then self:MapEdit_Remove() end
			return true
		end
		if bind == "+menu" then
			if pressed then

				Derma_Query(
					"Create Entity", 
					"Editor", 
					"spawnpoint", function() self:MapEdit_MakeLocalEnt("wordm_spawn") end, 
					"lobby_spawnpoint", function() self:MapEdit_MakeLocalEnt("wordm_spawn_lobby") end, 
					"screen", function() self:MapEdit_MakeLocalEnt("wordm_screen", true) end)

				return true

			end
		end
	end

end

net.Receive("mapedit_msg", function()

	local cmd = net.ReadUInt(MAPEDIT_BITS)
	if cmd == MAPEDIT_SELECT then

		print("RECV SELECT RESULT")

		local ent = net.ReadEntity()
		local mins,maxs = ent:WorldSpaceAABB()
		state.selectedEntity = {
			pos = function(s) return s.ent:GetPos() end,
			angles = function(s) return s.ent:GetAngles() end,
			ent = ent,
			name = net.ReadString(),
			id = net.ReadInt(32),
			mins = mins - ent:GetPos(),
			maxs = maxs - ent:GetPos(),
		}

	end

end)

concommand.Add("wordm_mapedit", function()

	state.active = not state.active

end)

concommand.Add("wordm_write", function()

	file.CreateDir("wordm/maps")

	local locked = {}
	for k,v in pairs(state.lockedEnts) do
		locked[#locked+1] = tostring(v.id)
	end

	local removed = {}
	for k,v in pairs(state.removes) do
		removed[#removed+1] = tostring(v.id)
	end

	local out = {}
	out.locked = locked
	out.removed = removed
	out.spawn = {}

	for _,v in pairs(state.local_ents) do
		out.spawn[#out.spawn+1] = {
			pos = v:pos(),
			angles = v:angles(),
			class = v.type,
		}
	end

	local str = util.TableToJSON( out )
	print( str )

	file.Write("wordm/maps/" .. game.GetMap() .. ".txt", str)

end)