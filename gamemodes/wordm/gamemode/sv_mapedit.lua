module("mapedit", package.seeall)

util.AddNetworkString("mapedit_msg")

net.Receive("mapedit_msg", function(len, pl)

	local cmd = net.ReadUInt(MAPEDIT_BITS)
	if cmd == MAPEDIT_GETIDS then

		local entities = ents.GetAll()
		local mapIDs = {}
		local entIDs = {}
		for _,v in ipairs(entities) do
			mapIDs[#mapIDs+1] = v:MapCreationID()
			entIDs[#entIDs+1] = v:EntIndex()
		end

		mapIDs = EncodeIDList(mapIDs)
		entIDs = EncodeIDList(entIDs)

		net.Start("mapedit_msg")
		net.WriteUInt(MAPEDIT_GETIDS, MAPEDIT_BITS)
		net.WriteUInt(#entities, 24)
		net.WriteUInt(#mapIDs, 24)
		net.WriteUInt(#entIDs, 24)

		for i=1, #mapIDs do net.WriteUInt(mapIDs[i], 32) end
		for i=1, #entIDs do net.WriteUInt(entIDs[i], 32) end

		net.Send(pl)

	elseif cmd == MAPEDIT_APPLY then

		if pl:IsAdmin() then
			GAMEMODE:DoCleanup( true )
		end

	end

end)
