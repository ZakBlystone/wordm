module("wordm_cooldowns", package.seeall)

G_WORD_COOLDOWNS = G_WORD_COOLDOWNS or {}

function GM:PostWordCooldown( ply, str, cooldown )

	if str == nil then return end

	for _,v in ipairs(G_WORD_COOLDOWNS) do

		if v.str:lower() == str:lower() then
			v.time = cooldown
			return
		end

	end

	G_WORD_COOLDOWNS[#G_WORD_COOLDOWNS+1] = {
		time = cooldown,
		str = str,
		ply = ply,
	}

end

function GM:CooldownThink()

	for i=#G_WORD_COOLDOWNS, 1, -1 do

		local c = G_WORD_COOLDOWNS[i]
		if c.time <= CurTime() then
			table.remove(G_WORD_COOLDOWNS, i)
		end

	end

end

function GM:DrawCooldowns()

	surface.SetFont("CooldownWordFont")

	for k, c in ipairs(G_WORD_COOLDOWNS) do

		local tx = math.max(c.time - CurTime(), 0) * 4
		local str = c.str
		local tw, th = surface.GetTextSize(str)
		local x, y = ScrW() - tw - 10, 10 + (k-1) * 28


		surface.SetTextColor(255,180,180,100)
		surface.SetTextPos(x, y)
		surface.DrawText(str)

		surface.SetDrawColor(255,180,180,100)
		surface.DrawRect(x - tx - 10, y, tx, th)
	
	end

end

function GM:ClearCooldowns()

	G_WORD_COOLDOWNS = {}

end