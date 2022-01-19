include "shared.lua"
include "cl_textfx.lua"
include "cl_chat.lua"

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

	if self:IsChatOpen() then
		self:DrawChat()
	end

end

function GM:PlayerBindPress( ply, bind, pressed, code )

	if self:IsChatOpen() and pressed then
		return true
	end

	if bind == "messagemode" or bind == "messagemode2" then

		if pressed then 
			self:ToggleChat() 
		else
			self:FocusChat()
		end
		return true

	end

end