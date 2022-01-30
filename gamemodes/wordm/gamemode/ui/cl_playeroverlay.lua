module("wordm_playeroverlay", package.seeall)

G_PLAYER_PINGS = G_PLAYER_PINGS or {}

function GM:DrawHealthBars()

	for _,v in ipairs( self:GetAllPlayers( PLAYER_PLAYING ) ) do

		local tr = util.TraceHull( {
			start = EyePos(),
			endpos = v:GetPos() + Vector(0,0,30),
			filter = LocalPlayer(),
			mins = Vector(-4,-4,-4),
			maxs = Vector(4,4,4),
		} )

		if tr.Hit and tr.Entity == v then

			local scr = (v:GetPos() + Vector(0,0,92)):ToScreen()
			if scr.visible then

				surface.SetFont("DermaLarge")
				local str = SanitizeToAscii(v:Nick())
				local tw, th = surface.GetTextSize(str)
				surface.SetTextColor(255,255,255,80)
				surface.SetTextPos( scr.x - tw/2, scr.y - th/2 - 10 )
				surface.DrawText( str )

				local hp = math.max(v:Health(), 0)/100

				surface.SetDrawColor(100,100,100,80)
				surface.DrawRect(scr.x-100,scr.y-10,200,20)

				surface.SetDrawColor(255,255,255,128)
				surface.DrawRect(scr.x-100,scr.y-5,200 * hp,10)

			end

		end

	end

end

function GM:AddPlayerPing(ply, pos)

	G_PLAYER_PINGS[#G_PLAYER_PINGS+1] = {
		ply = ply,
		pos = pos + Vector(0,0,32),
		time = CurTime(),
		sanitized = SanitizeToAscii(ply:Nick())
	}

end

function GM:DrawPings()

	surface.SetFont("TargetID")
	for i=#G_PLAYER_PINGS, 1, -1 do
		local p = G_PLAYER_PINGS[i]
		local dt = CurTime() - p.time
		local alpha = 1 - math.max(dt - 1, 0)
		if dt > 2 then
			table.remove(G_PLAYER_PINGS, i)
		end

		local scr = p.pos:ToScreen()
		if scr.visible then

			local str = p.sanitized
			local tw, th = surface.GetTextSize(str)

			surface.SetDrawColor(0,0,0,180 * alpha)
			surface.DrawRect(scr.x - tw/2 - 2, scr.y - th/2 - 2, tw + 4, th + 4)

			surface.SetTextPos(scr.x - tw/2, scr.y - th/2)
			surface.SetTextColor(80,255,80,255 * alpha)
			surface.DrawText(str)

		end

	end

end

function GM:ClearPings()

	G_PLAYER_PINGS = {}

end