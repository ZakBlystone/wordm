include "shared.lua"

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

	PrintTable(phrase)

end)

function GM:Think()

	for _,v in ipairs(player.GetAll()) do
		if v.pendingPhrase and v.pendingPhraseTime and v.pendingPhraseTime < CurTime() then
			self:HandlePlayerPhraseSynced(v, v.pendingPhrase)
			v.pendingPhrase = nil
			v.pendingPhraseTime = nil
		end
	end

end

function GM:HUDPaint()


end