if SERVER then

	AddCSLuaFile()
	AddCSLuaFile "cl_textfx.lua"
	AddCSLuaFile "cl_chat.lua"
	AddCSLuaFile "cl_phrasescore.lua"
	AddCSLuaFile "cl_playereditor.lua"
	AddCSLuaFile "cl_deathcards.lua"
	AddCSLuaFile "cl_help.lua"
	AddCSLuaFile "cl_gamestate.lua"
	AddCSLuaFile "cl_playeroverlay.lua"
	AddCSLuaFile "cl_cooldowns.lua"

else

	include "cl_textfx.lua"
	include "cl_chat.lua"
	include "cl_phrasescore.lua"
	include "cl_playereditor.lua"
	include "cl_deathcards.lua"
	include "cl_help.lua"
	include "cl_gamestate.lua"
	include "cl_playeroverlay.lua"
	include "cl_cooldowns.lua"

end