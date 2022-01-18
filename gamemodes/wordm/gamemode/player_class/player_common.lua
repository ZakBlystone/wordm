AddCSLuaFile()

DEFINE_BASECLASS "player_default"

if ( CLIENT ) then

	CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
	CreateConVar( "cl_weaponcolor", "0.30 1.80 2.10", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
	CreateConVar( "cl_playerskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" )
	CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" )

end

local PLAYER = {}

PLAYER.DisplayName			= "Common"

PLAYER.WalkSpeed			= 400		-- How fast to move when not running
PLAYER.RunSpeed				= 320		-- How fast to move when running
PLAYER.CrouchedWalkSpeed	= 0.3		-- Multiply move speed by this when crouching
PLAYER.DuckSpeed			= 0.3		-- How fast to go from not ducking, to ducking
PLAYER.UnDuckSpeed			= 0.3		-- How fast to go from ducking, to not ducking
PLAYER.JumpPower			= 180		-- How powerful our jump should be
PLAYER.CanUseFlashlight		= true		-- Can we use the flashlight
PLAYER.MaxHealth			= 100		-- Max health we can have
PLAYER.StartHealth			= 100		-- How much health we start with
PLAYER.StartArmor			= 0			-- How much armour we start with
PLAYER.DropWeaponOnDie		= false		-- Do we drop our weapon when we die
PLAYER.TeammateNoCollide	= false		-- Do we collide with teammates or run straight through them
PLAYER.AvoidPlayers			= true		-- Automatically swerves around other players
PLAYER.UseVMHands			= true		-- Uses viewmodel hands

--
-- Name: PLAYER:SetupDataTables
-- Desc: Set up the network table accessors
-- Arg1:
-- Ret1:
--
function PLAYER:SetupDataTables()

	BaseClass.SetupDataTables( self )

end

--
-- Name: PLAYER:Init
-- Desc: Called when the class object is created (shared)
-- Arg1:
-- Ret1:
--
function PLAYER:Init()

	if SERVER then

		local ply = self.Player
		local class = self

		ply:RemoveAllItems()

		self:SetModel()
		self:Loadout()

		ply:SetWalkSpeed( class.WalkSpeed )
		ply:SetRunSpeed( class.RunSpeed )
		ply:SetCrouchedWalkSpeed( class.CrouchedWalkSpeed )
		ply:SetDuckSpeed( class.DuckSpeed )
		ply:SetUnDuckSpeed( class.UnDuckSpeed )
		ply:SetJumpPower( class.JumpPower )
		ply:AllowFlashlight( class.CanUseFlashlight )
		ply:ShouldDropWeapon( class.DropWeaponOnDie )
		ply:SetNoCollideWithTeammates( class.TeammateNoCollide )
		ply:SetAvoidPlayers( class.AvoidPlayers )
		ply:SetMaxHealth( class.MaxHealth )
		ply:SetHealth( class.StartHealth )
		ply:SetArmor( class.StartArmor )

	end

end

--
-- Name: PLAYER:Spawn
-- Desc: Called serverside only when the player spawns
-- Arg1:
-- Ret1:
--
function PLAYER:Spawn()

	BaseClass.Spawn( self )

	local col = self.Player:GetInfo( "cl_playercolor" )
	self.Player:SetPlayerColor( Vector( col ) )

	local col = Vector( self.Player:GetInfo( "cl_weaponcolor" ) )
	if col:Length() == 0 then
		col = Vector( 0.001, 0.001, 0.001 )
	end
	self.Player:SetWeaponColor( col )

end

--
-- Name: PLAYER:Loadout
-- Desc: Called on spawn to give the player their default loadout
-- Arg1:
-- Ret1:
--
function PLAYER:Loadout()

	self.Player:Give( "weapon_wordbase" )
	self.Player:GiveAmmo( 255, "Pistol", true )

end

function PLAYER:SetModel()

	local cl_playermodel = self.Player:GetInfo( "cl_playermodel" )
	local skin = self.Player:GetInfoNum( "cl_playerskin", 0 )
	local modelname = player_manager.TranslatePlayerModel( cl_playermodel )
	util.PrecacheModel( modelname )
	self.Player:SetSkin( skin )
	self.Player:SetModel( modelname )
	self.Player:SetupHands()

	local groups = self.Player:GetInfo( "cl_playerbodygroups" )
	if ( groups == nil ) then groups = "" end
	local groups = string.Explode( " ", groups )
	for k = 0, self.Player:GetNumBodyGroups() - 1 do
		self.Player:SetBodygroup( k, tonumber( groups[ k + 1 ] ) or 0 )
	end

end

function PLAYER:Death( inflictor, attacker )
end

-- Clientside only
function PLAYER:CalcView( view ) end		-- Setup the player's view
function PLAYER:CreateMove( cmd ) end		-- Creates the user command on the client
function PLAYER:ShouldDrawLocal() end		-- Return true if we should draw the local player

-- Shared
function PLAYER:StartMove( mv, cmd ) end
function PLAYER:Move( mv ) end				-- Runs the move (can run multiple times for the same client)
function PLAYER:FinishMove( mv ) end		-- Copy the results of the move back to the Player

--
-- Name: PLAYER:ViewModelChanged
-- Desc: Called when the player changes their weapon to another one causing their viewmodel model to change
-- Arg1: Entity|viewmodel|The viewmodel that is changing
-- Arg2: string|old|The old model
-- Arg3: string|new|The new model
-- Ret1:
--
function PLAYER:ViewModelChanged( vm, old, new )
end

--
-- Name: PLAYER:PreDrawViewmodel
-- Desc: Called before the viewmodel is being drawn (clientside)
-- Arg1: Entity|viewmodel|The viewmodel
-- Arg2: Entity|weapon|The weapon
-- Ret1:
--
function PLAYER:PreDrawViewModel( vm, weapon )
end

--
-- Name: PLAYER:PostDrawViewModel
-- Desc: Called after the viewmodel has been drawn (clientside)
-- Arg1: Entity|viewmodel|The viewmodel
-- Arg2: Entity|weapon|The weapon
-- Ret1:
--
function PLAYER:PostDrawViewModel( vm, weapon )
end

--
-- Name: PLAYER:GetHandsModel
-- Desc: Called on player spawn to determine which hand model to use
-- Arg1:
-- Ret1: table|info|A table containing model, skin and body
--
function PLAYER:GetHandsModel()

	-- return { model = "models/weapons/c_arms_cstrike.mdl", skin = 1, body = "0100000" }

	local playermodel = player_manager.TranslateToPlayerModelName( self.Player:GetModel() )
	return player_manager.TranslatePlayerHands( playermodel )

end

player_manager.RegisterClass( "player_common", PLAYER, "player_default" )
