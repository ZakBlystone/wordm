include "shared.lua"
include "cl_textfx.lua"

surface.CreateFont( "WordAmmoFont", {
	font = "Akkurat-Bold",
	extended = false,
	size = 38,
	weight = 1000,
	blursize = 0,
} )

net.Receive("wordscore_msg", function(len)

	print("RECV WORDSCORE : " .. len)

	local time = net.ReadFloat()
	local ply = net.ReadEntity()
	local phrase = RecvPhraseScore()

	ply.pendingPhrase = phrase
	ply.pendingPhraseTime = CurTime() + TIME_TO_PHRASE

	net.Start("wordscore_msg")
	net.WriteFloat( CurTime() + TIME_TO_PHRASE )
	net.SendToServer()

	--PrintTable(phrase)

end)

function GM:Think()

	for _,v in ipairs(player.GetAll()) do
		if v.pendingPhrase and v.pendingPhraseTime and v.pendingPhraseTime < CurTime() then
			self:HandlePlayerPhraseSynced(v, v.pendingPhrase)
			v.pendingPhrase = nil
			v.pendingPhraseTime = nil
		end
	end

	self:ChatThink()

end

function GM:HUDPaint()

	if self.ChatOpened then
		self:DrawChat()
	end

end

function GM:IsChatOpen()

	return self.ChatOpened

end

function GM:DrawChat()

	self.ChatFade = math.min(self.ChatFade+FrameTime()*3, 1)

	surface.SetDrawColor(0,0,0,120 * self.ChatFade)
	surface.DrawRect(0,0,ScrW(),ScrH())

	local text = table.concat(self.ChatBuffer)

	surface.SetFont("WordAmmoFont")
	local tw, th = surface.GetTextSize( text )
	local pad = 30

	draw.RoundedBox(8, ScrW()/2 - tw/2 - pad/2, ScrH()/2 - th/2 - pad/2, tw + pad, th + pad, Color(0,0,0,80))

	surface.SetTextPos(ScrW()/2 - tw/2, ScrH()/2 - th/2)
	surface.SetTextColor(Color(255,255,255))
	surface.DrawText( text )

	local bufpos = surface.GetTextSize( text:sub(1, self.ChatCarat) )
	local pulse = math.Remap( math.cos(CurTime() * 15), -1, 1, 0.1, 1 )

	local cx = ScrW()/2 - tw/2 + bufpos
	local cy = ScrH()/2 - th/2
	surface.SetDrawColor(255, 255, 255, 255*pulse)
	surface.DrawRect(cx, cy, 2, th)
	surface.DrawRect(cx-2, cy, 6, 2)
	surface.DrawRect(cx-2, cy+th, 6, 2)

end

function GM:ToggleChat()

	self.ChatOpened = not self.ChatOpened
	self.ChatBuffer = self.ChatBuffer or {}
	self.ChatCarat = self.ChatCarat or 0

	if self.ChatOpened then
		self.ChatLive = false
		self.ChatFade = 0
	else
		self.ChatButtonRepeat = false
	end

end

function GM:CreateMove( cmd )

	if self.ChatOpened then
		cmd:ClearButtons()
		cmd:ClearMovement()
		return true
	end

end

function GM:SubmitChatBuffer()

	local str = table.concat(self.ChatBuffer)
	if #str > 0 then LocalPlayer():ConCommand("say " .. str) end
	self.ChatBuffer = {}
	self.ChatCarat = 0

end

local blackList = {
	["`"] = true,
}
local codeTranslation = {
	["SPACE"] = " ",
	["SEMICOLON"] = ";",
}

local letters = "abcdefghijklmnopqrstuvwxyz"
local shiftTranslation = {
	["1"] = "!",
	["2"] = "@",
	["3"] = "#",
	["4"] = "$",
	["5"] = "%",
	["6"] = "^",
	["7"] = "&",
	["8"] = "*",
	["9"] = "(",
	["0"] = ")",
	["-"] = "_",
	["="] = "+",
	["\\"] = "|",
	["/"] = "?",
	[","] = "<",
	["."] = ">",
	["`"] = "~",
	[";"] = ":",
	["'"] = "\"",
	["["] = "{",
	["]"] = "}",
	["BACKSPACE"] = "DELETEWORD",
}

local ctrlTranslation = {
	["BACKSPACE"] = "CLEAR",
}

for i=1, #letters do shiftTranslation[letters[i]] = string.upper(letters[i]) end

function GM:PlayerButtonUp( ply, button )

	if not IsFirstTimePredicted() then return end

	if button == self.ChatLastButton and self.ChatButtonRepeat then
		self.ChatButtonRepeat = false
	end

end

function GM:PlayerButtonDown( ply, button )

	if not IsFirstTimePredicted() then return end

	if not self.ChatOpened or not self.ChatLive then return end

	self:SendCodeToChatBuffer(button)
	self.ChatLastButton = button
	self.ChatButtonRepeat = true
	self.ChatButtonNextRepeat = CurTime() + 0.4

end

function GM:ChatThink()

	if self.ChatButtonRepeat and self.ChatButtonNextRepeat < CurTime() then

		self:SendCodeToChatBuffer( self.ChatLastButton )
		self.ChatButtonNextRepeat = CurTime() + 0.03

	end

	if not LocalPlayer():Alive() then
		if self:IsChatOpen() then
			self:ToggleChat()
		end
	end

end

function GM:SendCodeToChatBuffer( code )

	local name = input.GetKeyName(code)
	if name == nil then return end
	if blackList[name] then return end

	name = codeTranslation[name] or name
	if input.IsButtonDown( KEY_LSHIFT ) or input.IsButtonDown( KEY_RSHIFT ) then
		name = shiftTranslation[name] or name
	end

	if input.IsButtonDown( KEY_LCONTROL ) or input.IsButtonDown( KEY_RCONTROL ) then
		name = ctrlTranslation[name] or name
	end

	if name == "HOME" then
		self.ChatCarat = 0
	elseif name == "END" then
		self.ChatCarat = #self.ChatBuffer
	elseif name == "LEFTARROW" then
		self.ChatCarat = math.max(self.ChatCarat - 1, 0)
	elseif name == "RIGHTARROW" then
		self.ChatCarat = math.min(self.ChatCarat + 1, #self.ChatBuffer)
	elseif name == "ENTER" then
		self:ToggleChat()
		self:SubmitChatBuffer()
	elseif name == "BACKSPACE" then
		if #self.ChatBuffer > 0 and self.ChatCarat ~= 0 then
			table.remove(self.ChatBuffer, self.ChatCarat)
			self.ChatCarat = math.min(self.ChatCarat-1, #self.ChatBuffer)
		end
	elseif name == "DELETEWORD" then
		-- goto end of word
		while self.ChatBuffer[self.ChatCarat] ~= " " and self.ChatCarat < #self.ChatBuffer do
			self.ChatCarat = self.ChatCarat + 1
		end

		-- delete space
		if self.ChatBuffer[self.ChatCarat] == " " then
			table.remove(self.ChatBuffer, self.ChatCarat)
			self.ChatCarat = math.max(self.ChatCarat - 1, 0)
			if self.ChatCarat == 0 then return end
		end

		-- walk back and delete letters
		while self.ChatBuffer[self.ChatCarat] ~= " " do
			table.remove(self.ChatBuffer, self.ChatCarat)
			self.ChatCarat = math.max(self.ChatCarat - 1, 0)
			if self.ChatCarat == 0 then return end
		end

	elseif name == "CLEAR" then
		self.ChatBuffer = {}
		self.ChatCarat = 0
	elseif #name == 1 then
		table.insert(self.ChatBuffer, self.ChatCarat+1, name)
		self.ChatCarat = self.ChatCarat + 1
	end

end

function GM:PlayerBindPress( ply, bind, pressed, code )

	if self.ChatOpened and pressed then
		return true
	end

	if bind == "messagemode" or bind == "messagemode2" then

		if pressed then 
			self:ToggleChat() 
		else
			if not self.ChatLive then
				print("MAKE CHAT LIVE")
				self.ChatLive = true
			end
		end
		return true

	end

end