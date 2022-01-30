
-- quick and dumb map editor for making maps more playable in this game

module("mapedit", package.seeall)

G_MAP_EDIT_STATE = G_MAP_EDIT_STATE or { 
	active = false, 
	lockedEnts = {}, 
	removes = {}, 
	local_ents = {}, 
	entity_lookup = {}, 
	map_lookup = {} 
}

local state = G_MAP_EDIT_STATE

local m = FindMetaTable("Entity")
function m:MapCreationID()

	return state.map_lookup[ self:EntIndex() ]

end

function m:GetName()

	local bspent = ents.GetBSPEntity( self:MapCreationID() )
	if bspent then return bspent["targetname"] or "" end
	return "<not found>"

end

function ents.GetMapCreatedEntity(id)

	for _,v in ipairs(ents.GetAll()) do
		if v:MapCreationID() == id then return v end
	end

end

function ents.GetBSPEntity(id)

	return state.mapbspents[ id-1234 ]

end

function SelectEntity(ent)

	if not IsValid(ent) then print("INVALID ENT") return end

	local mins,maxs = ent:WorldSpaceAABB()
	state.selectedEntity = {
		pos = function(s) return s.ent:GetPos() end,
		angles = function(s) return s.ent:GetAngles() end,
		ent = ent,
		name = ent:GetName(),
		id = ent:MapCreationID(),
		mins = mins - ent:GetPos(),
		maxs = maxs - ent:GetPos(),
	}

end

function Deselect()

	state.selectedEntity = nil

end

function RequestMapIDs()

	net.Start("mapedit_msg")
	net.WriteUInt(MAPEDIT_GETIDS, MAPEDIT_BITS)
	net.SendToServer()

end

function DrawEditUI()

	if not state.active then return end

	draw.SimpleText("MAP EDITOR ACTIVE", "DermaDefault", ScrW()/2, 10, Color( 255, 10, 10, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

	if state.selectedEntity then

		local e = state.selectedEntity
		draw.SimpleText(tostring(e.type or e.ent) .. " : " .. tostring(e.name) .. " : " .. tostring(e.id or e._index), 
			"DermaDefault", ScrW() - 120, ScrH() / 2, Color( 255, 10, 10, 255 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	end

	local lobbySpawns = 0
	local spawns = 0
	local screens = 0
	for _,v in ipairs(state.local_ents) do
		if v.type == "wordm_spawn" then spawns = spawns + 1 end
		if v.type == "wordm_spawn_lobby" then lobbySpawns = lobbySpawns + 1 end
		if v.type == "wordm_screen" then screens = screens + 1 end
	end

	draw.SimpleText("spawns: " .. spawns, "DermaDefault", 10, 400, Color(255,10,10,255) )
	draw.SimpleText("lobby_spawns: " .. lobbySpawns, "DermaDefault", 10, 420, Color(255,10,10,255) )
	draw.SimpleText("screens: " .. screens, "DermaDefault", 10, 440, Color(255,10,10,255) )

end

local function DrawEntBox(e, col)

	render.DrawBox(e:pos(), e:angles(), e.mins, e.maxs, col or Color( 255, 255, 255, 100 ))

	render.DrawLine(e:pos(), e:pos() + e:angles():Forward() * 30, Color(255,255,255,100))

end

function DrawEditWorld()

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

function Think()

end

local _invraymtx = Matrix()
local _zerovector = Vector(0,0,0)

local function lines(str)
	local setinel = 0
	return function()
		local k, b = str:find("\n", setinel+1)
		if not k then return end
		b, setinel = setinel, k
		return str:sub(b+1, k-1)
	end
end

function LoadBSPEntities()

	local f = file.Open( "maps/" .. game.GetMap() .. ".bsp", "rb", path or "GAME" )
	local lumps = {}
	local ident = f:ReadLong()
	local version = f:ReadLong()
	local off, len = f:ReadLong(), f:ReadLong()
	f:Seek( off )

	local entity_string = f:Read( len )
	local entities = {}
	local currentEnt = {}
	for x in lines(entity_string) do
		if x == "{" then continue end
		if x == "}" then
			currentEnt.index = #entities+1
			entities[#entities+1] = currentEnt
			currentEnt = {}
			continue
		end
		local key, value = x:match("\"([%w%g%s_]+)\" \"([%g%s_]*)\"")
		--print(x)
		if key == "origin" then
			local x,y,z = tostring(value):match( "([%+%-]?%d*%.?%d+) ([%+%-]?%d*%.?%d+) ([%+%-]?%d*%.?%d+)" )
			value = Vector(x or 0,y or 0,z or 0)
		end
		if key == "angles" then
			local x,y,z = tostring(value):match( "([%+%-]?%d*%.?%d+) ([%+%-]?%d*%.?%d+) ([%+%-]?%d*%.?%d+)" )
			value = Angle(x or 0,y or 0,z or 0)
		end
		currentEnt[key] = value
	end
	state.bspents = entities
	state.mapbspents = {}

	for _,v in ipairs(state.bspents) do
		state.mapbspents[v.index] = v
	end

	print("Loaded BSP entities")

end

--LoadBSPEntities()

function SelectLocal(pos, dir)

	--print(type(pos))
	--print(type(dir))

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

function Select()

	local found = SelectLocal(
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

function ToggleLocked()

	if state.selectedEntity == nil then return end
	local e = state.selectedEntity
	if not e.id then return end
	if state.lockedEnts[e.id] then
		state.lockedEnts[e.id] = nil
	else
		state.lockedEnts[e.id] = e
	end

end

function Remove()

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

function MakeLocalEnt(type, dotrace)

	local t = {
		pos = function(s) return s._pos end,
		angles = function(s) return s._angle end,
		_angle = Angle(0,0,0),
		_pos = Vector(0,0,0),
		mins = Vector(-4,-4,-4),
		maxs = Vector(4,4,4),
		type = type,
	}

	if string.find(type, "spawn") then
		t.mins = Vector(-16,-16,0)
		t.maxs = Vector(16,16,72)
		t.color = Color(80,255,80,100)
		if string.find(type, "lobby") then
			t.color = Color(80,180,255,100)
		end
	end

	if type == "remove_marker" then
		t.color = Color(255,100,100,100)
		t.mins = Vector(-16,-16,-16)
		t.maxs = Vector(16,16,16)
	end

	if type == "wordm_screen" then

		t.color = Color(30,255,20,100)
		t.mins = Vector(-48,-48,0)
		t.maxs = Vector(48,48,4)

	end

	if not dotrace then

		local yaw = LocalPlayer():EyeAngles().y
		t._pos = LocalPlayer():GetPos()
		t._angle.yaw = yaw



		state.local_ents[#state.local_ents+1] = t
		return t

	else

		local tr = LocalPlayer():GetEyeTrace()
		if tr.Hit then

			t._pos = tr.HitPos
			t._angle = tr.HitNormal:Angle()
			t._angle:RotateAroundAxis(t._angle:Right(), -90)
			t._angle:RotateAroundAxis(t._angle:Up(), 90)
			state.local_ents[#state.local_ents+1] = t
			return t

		end

	end

end

function BindPress( bind, pressed, code )

	if state.active then
		if bind == "+attack" then
			if pressed then Select() end
			return true
		end
		if bind == "+attack2" then
			if pressed then ToggleLocked() end
			return true
		end
		if bind == "+reload" then
			if pressed then Remove() end
			return true
		end
		if bind == "+menu" then
			if pressed then

				Derma_Query(
					"Create Entity", 
					"Editor", 
					"spawnpoint", function() MakeLocalEnt("wordm_spawn") end, 
					"lobby_spawnpoint", function() MakeLocalEnt("wordm_spawn_lobby") end, 
					"screen", function() MakeLocalEnt("wordm_screen", true) end)

				return true

			end
		end
	end

end

function Clear()

	state.local_ents = {}
	state.lockedEnts = {}
	state.removes = {}

end

function Load()

	if not state.active then return end

	local mapdata = file.Read("wordm/maps/" .. game.GetMap() .. ".txt", "DATA" )
	if mapdata then

		local data = util.JSONToTable(mapdata)

		Clear()

		for _,v in ipairs(data.spawn) do

			local e = MakeLocalEnt(v.class)
			e._pos = v.pos
			e._angle = v.angles

		end

		for _,v in ipairs(data.locked) do

			local e = ents.GetMapCreatedEntity(tonumber(v))
			if IsValid(e) then
				SelectEntity(e)
				ToggleLocked()
			else
				print("Unable to find locked entity: " .. v)
			end

		end

		for _,v in ipairs(data.removed) do

			local bsp = ents.GetBSPEntity(tonumber(v))
			if not bsp then continue end

			local e = MakeLocalEnt("remove_marker")
			e._pos = bsp["origin"] or Vector(0,0,0)
			e._angle = bsp["angles"] or Angle(0,0,0)
			e._index = v
			e.name = bsp["targetname"] or ""

		end

		Deselect()

	end

end

function Save()

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
		if v.type == "remove_marker" then
			out.removed[#out.removed+1] = v._index
		else
			out.spawn[#out.spawn+1] = {
				pos = v:pos(),
				angles = v:angles(),
				class = v.type,
			}
		end
	end

	local str = util.TableToJSON( out )
	print( str )

	file.Write("wordm/maps/" .. game.GetMap() .. ".txt", str)

end

net.Receive("mapedit_msg", function()

	local cmd = net.ReadUInt(MAPEDIT_BITS)
	if cmd == MAPEDIT_GETIDS then

		local numEnts = net.ReadUInt(24)
		local numMapIDs = net.ReadUInt(24)
		local numEntIDs = net.ReadUInt(24)

		local mapIDs = {}
		local entIDs = {}

		for i=1, numMapIDs do mapIDs[#mapIDs+1] = net.ReadUInt(32) end
		for i=1, numEntIDs do entIDs[#entIDs+1] = net.ReadUInt(32) end

		mapIDs = DecodeIDList(mapIDs)
		entIDs = DecodeIDList(entIDs)

		assert(#mapIDs == #entIDs and #mapIDs == numEnts)

		state.entity_lookup = {}
		state.map_lookup = {}

		for i=1, numEnts do
			state.entity_lookup[mapIDs[i]] = entIDs[i]
			state.map_lookup[entIDs[i]] = mapIDs[i]
		end

	end

end)

concommand.Add("wordm_mapedit", function()

	state.active = not state.active

	if state.active then
		RequestMapIDs()
		LoadBSPEntities()
		Load()
	end

end)

concommand.Add("wordm_mapload", function()

	Load()

end)

concommand.Add("wordm_mapclear", function()

	Clear()

end)

concommand.Add("wordm_mapapply", function()

	Save()
	Clear()
	net.Start("mapedit_msg")
	net.WriteUInt(MAPEDIT_APPLY, MAPEDIT_BITS)
	net.SendToServer()

	timer.Simple(.5,function()
		Load()
	end)

end)

concommand.Add("wordm_mapwrite", function()

	Save()

end)