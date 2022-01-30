local gradient_mat = Material("vgui/gradient_down")

local function FormatTimeGood(t)

	local minutes = math.floor(t/60) % 60
	local seconds = math.floor(t) % 60
	local hundredths = math.floor(t*100) % 100
	return ("%02i:%02i.%02i"):format(minutes, seconds, hundredths)

end

local clickToJoinText = "Press '" .. input.LookupBinding("+reload"):upper() .. "' to join"

function GM:DrawGameState()

	local ge = self:GetGameEntity()
	if not IsValid(ge) then return end

	local title = nil
	local subtitle = nil
	local timer = nil
	local gamestate = ge:GetGameState()
	if gamestate == GAMESTATE_IDLE then

		title = "WAITING FOR PLAYERS"
		subtitle = clickToJoinText

		if LocalPlayer():IsReady() then
			subtitle = "You are READY, please wait for someone else"
		end

	elseif gamestate == GAMESTATE_WAITING then

		title = "STARTING"

		if LocalPlayer():IsReady() then
			subtitle = "You are READY, game starting..."
		else
			subtitle = clickToJoinText
		end

		timer = FormatTimeGood( ge:GetTimeRemaining() )

	elseif gamestate == GAMESTATE_COUNTDOWN then

		if LocalPlayer():IsPlaying() then

			title = "GET READY"
			subtitle = "Everyone is frozen, type some sentences in chat quick!"

		else

			title = "GAME IS STARTING"
			subtitle = "Wait until the next game to join"

		end

		timer = FormatTimeGood( ge:GetTimeRemaining() )

	elseif gamestate == GAMESTATE_PLAYING then

		if not LocalPlayer():IsPlaying() then

			title = "YOU ARE SPECTATING"
			subtitle = "Wait until the next game to join"

		elseif LocalPlayer():Alive() == false then

			title = "YOU DIED"
			subtitle = "Wait until the round is over"

		end

	elseif gamestate == GAMESTATE_POSTGAME then

		title = "GAME OVER"

		local activeplayers = self:GetAllPlayers( PLAYER_PLAYING )
		local liveplayer = nil
		if #activeplayers > 0 then
			for _,v in ipairs(activeplayers) do
				if v:Alive() then liveplayer = v break end
			end
		end

		if IsValid(liveplayer) then
			subtitle = SanitizeToAscii( liveplayer:Nick() ) .. " IS THE WINNER!"
		else
			subtitle = "NOBODY WON! :("
		end

		timer = FormatTimeGood( ge:GetTimeRemaining() )

	end

	if title then

		surface.SetMaterial(gradient_mat)
		surface.SetDrawColor(0,0,0,200)
		surface.DrawTexturedRect(0,0,ScrW(),400)

		draw.SimpleText(title, "GameStateTitle", ScrW()/2,100, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	end

	if subtitle then
		
		draw.SimpleText(subtitle, "GameStateSubTitle", ScrW()/2,140, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	end

	if timer then

		draw.SimpleText(timer, "GameStateSubTitle", ScrW()/2,180, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	end

	if gamestate == GAMESTATE_IDLE then

		if not self.bShowingHelp then
			draw.SimpleText("Press " .. input.LookupBinding("gm_showhelp") .. " for help", "GameStateSubTitle", 30, 30, Color(255,255,255,255))
			--draw.SimpleText("Press Enter for regular chat", "GameStateSubTitle", 30, 60, Color(255,255,255,255))
		end

	end

end

function GM:DrawReadyPlayers()

	for k,v in ipairs(player.GetAll()) do

		local ready = v:IsReady()

		local name = textfx.Builder(SanitizeToAscii(v:Nick()), "WordAmmoFont"):Box(10,2):Color(190,255,100,255)
		:SetPos(10, ScrH()/4 + k * 50)
		local readytext = textfx.Builder(ready and "Ready" or "Not Ready", "CooldownWordFont"):Box(10,4)
		:HAlignTo(name, "after")
		:VAlignTo(name, "center")

		if ready then
			readytext:Color(120,255,120,255)
		else
			readytext:Color(255,120,120,255)
		end

		name:Draw()
		readytext:Draw()


	end

end