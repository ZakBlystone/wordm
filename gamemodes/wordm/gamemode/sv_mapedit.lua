util.AddNetworkString("mapedit_msg")

net.Receive("mapedit_msg", function(len, pl)

	local cmd = net.ReadUInt(MAPEDIT_BITS)
	if cmd == MAPEDIT_SELECT then

		print("RECV SELECT MSG")

		local ent = net.ReadEntity()
		local name = ent:GetName()

		net.Start("mapedit_msg")
		net.WriteUInt(MAPEDIT_SELECT, MAPEDIT_BITS)
		net.WriteEntity(ent)
		net.WriteString(name or "")
		net.WriteInt(ent:MapCreationID(), 32)
		net.Send(pl)

	end

end)