
include( 'prop_tools.lua' )

--[[---------------------------------------------------------
   Name: CCSpawn
   Desc: Console Command for a player to spawn different items
-----------------------------------------------------------]]
function CCSpawn( player, command, arguments )

	if ( arguments[1] == nil ) then return end
	if ( !gamemode.Call( "PlayerSpawnObject", player, arguments[1], arguments[2] ) ) then return end
	if ( !util.IsValidModel( arguments[1] ) ) then return end
	
	local iSkin = arguments[2] or 0
	local strBody = arguments[3] or nil

	if ( util.IsValidProp( arguments[1] ) ) then 
	
		GMODSpawnProp( player, arguments[1], iSkin, strBody )
		return
	
	end
	
	if ( util.IsValidRagdoll( arguments[1] ) ) then 
	
		GMODSpawnRagdoll( player, arguments[1], iSkin, strBody )
		return
	
	end

	-- Not a ragdoll or prop.. must be an 'effect' - spawn it as one
	GMODSpawnEffect( player, arguments[1], iSkin, strBody )
	
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
local function MakeRagdoll( Player, Pos, Ang, Model, PhysicsObjects, Data )

	if not gamemode.Call( "PlayerSpawnRagdoll", Player, Model ) then return end
	local Ent = ents.Create( "prop_ragdoll" )
		duplicator.DoGeneric( Ent, Data )
	Ent:Spawn()
	
	duplicator.DoGenericPhysics( Ent, Player, Data )
	
	Ent:Activate()

	if ( IsValid( Player ) ) then
		gamemode.Call( "PlayerSpawnedRagdoll", Player, Model, Ent )
	end
	
	DoPropSpawnedEffect( Ent )
	
	return Ent	
end

-- Register the "prop_ragdoll" class with the duplicator, (Args in brackets will be retreived for every bone)
duplicator.RegisterEntityClass( "prop_ragdoll", MakeRagdoll, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )

--[[---------------------------------------------------------
   Name: GMODSpawnRagdoll - player spawns a ragdoll
-----------------------------------------------------------]]
function GMODSpawnRagdoll( player, model, iSkin, strBody )

	if ( !gamemode.Call( "PlayerSpawnRagdoll", player, model ) ) then return end
	local e = DoPlayerEntitySpawn( player, "prop_ragdoll", model, iSkin, strBody )

	if ( IsValid( player ) ) then
		gamemode.Call( "PlayerSpawnedRagdoll", player, model, e )
	end
	
	DoPropSpawnedEffect( e )
	
	undo.Create("Ragdoll")
		undo.SetPlayer(player)
		undo.AddEntity(e)
	undo.Finish( "Ragdoll ("..tostring(model)..")" )
	
	player:AddCleanup( "ragdolls", e )

end


function MakeProp( Player, Pos, Ang, Model, PhysicsObjects, Data )

	-- Uck.
	Data.Pos		= Pos
	Data.Angle		= Ang
	Data.Model		= Model

	-- Make sure this is allowed
	if ( IsValid( Player ) && !gamemode.Call( "PlayerSpawnProp", Player, Model ) ) then return end
	
	local Prop = ents.Create( "prop_physics" )
		duplicator.DoGeneric( Prop, Data )
	Prop:Spawn()
	
	duplicator.DoGenericPhysics( Prop, Player, Data )
	
	-- Tell the gamemode we just spawned something
	if ( IsValid( Player ) ) then
		gamemode.Call( "PlayerSpawnedProp", Player, Model, Prop )
	end
	
	FixInvalidPhysicsObject( Prop )
	
	DoPropSpawnedEffect( Prop )
	
	return Prop
	
end

duplicator.RegisterEntityClass( "prop_physics", MakeProp, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )
duplicator.RegisterEntityClass( "prop_physics_multiplayer", MakeProp, "Pos", "Ang", "Model", "PhysicsObjects", "Data" )

--[[---------------------------------------------------------
   Name: FixInvalidPhysicsObject
			Attempts to detect and correct the physics object
			on models such as the TF2 Turrets
-----------------------------------------------------------]]
function FixInvalidPhysicsObject( Prop )

	local PhysObj = Prop:GetPhysicsObject()
	if ( !IsValid(PhysObj) ) then return end
	
	local min, max = PhysObj:GetAABB()
	if  ( !min || !max ) then return end
	
	local PhysSize = (min - max):Length()
	if ( PhysSize > 5 ) then return end
	
	local min = Prop:OBBMins()	
	local max = Prop:OBBMaxs()
	if  ( !min || !max ) then return end
	
	local ModelSize = (min - max):Length()
	local Difference = math.abs( ModelSize - PhysSize )
	if ( Difference < 10 ) then return end

	-- This physics object is definitiely weird.
	-- Make a new one.
	
	Prop:PhysicsInitBox( min, max )
	Prop:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
	
	local PhysObj = Prop:GetPhysicsObject()
	if ( !PhysObj ) then return end
	
	PhysObj:SetMass( 100 )
	PhysObj:Wake()

end

--[[---------------------------------------------------------
   Name: CCSpawnProp - player spawns a prop
-----------------------------------------------------------]]
function GMODSpawnProp( player, model, iSkin, strBody )

	if ( !gamemode.Call( "PlayerSpawnProp", player, model ) ) then return end

	local e = DoPlayerEntitySpawn( player, "prop_physics", model, iSkin, strBody )

	if ( IsValid( player ) ) then
		gamemode.Call( "PlayerSpawnedProp", player, model, e )
	end

	-- This didn't work out - todo: Find a better way.
	--timer.Simple( 0.01, CheckPropSolid, e, COLLISION_GROUP_NONE, COLLISION_GROUP_WORLD )
	
	FixInvalidPhysicsObject( e )
	
	DoPropSpawnedEffect( e )

	undo.Create("Prop")
		undo.SetPlayer(player)
		undo.AddEntity(e)
	undo.Finish( "Prop ("..tostring(model)..")" )
	
	player:AddCleanup( "props", e )

end

--[[---------------------------------------------------------
   Name: GMODSpawnEffect
-----------------------------------------------------------]]
function GMODSpawnEffect( player, model, iSkin, strBody )

	if ( !gamemode.Call( "PlayerSpawnEffect", player, model ) ) then return end
	local e = DoPlayerEntitySpawn( player, "prop_effect", model, iSkin, strBody )
	if ( !IsValid( e ) ) then return end
	
	if ( IsValid( player ) ) then
		gamemode.Call( "PlayerSpawnedEffect", player, model, e )
	end
	
	DoPropSpawnedEffect( e )
	
	undo.Create("Effect")
		undo.SetPlayer(player)
		undo.AddEntity(e)
	undo.Finish( "Effect ("..tostring(model)..")" )
	
	player:AddCleanup( "effects", e )

end

--[[---------------------------------------------------------
   Name: DoPlayerEntitySpawn
   Desc: Utility function for player entity spawning functions
-----------------------------------------------------------]]
function DoPlayerEntitySpawn( player, entity_name, model, iSkin, strBody )

	local vStart = player:GetShootPos()
	local vForward = player:GetAimVector()

	local trace = {}
	trace.start = vStart
	trace.endpos = vStart + (vForward * 2048)
	trace.filter = player
	
	local tr = util.TraceLine( trace )

	-- PrintTable( tr )

	-- Prevent spawning too close
	--if ( !tr.Hit || tr.Fraction < 0.05 ) then 
	--	return 
	--end
	
	local ent = ents.Create( entity_name )
	if ( !IsValid( ent ) ) then return end

	local ang = player:EyeAngles()
	ang.yaw = ang.yaw + 180 -- Rotate it 180 degrees in my favour
	ang.roll = 0
	ang.pitch = 0
	
	if (entity_name == "prop_ragdoll") then
		ang.pitch = -90
		tr.HitPos = tr.HitPos
	end
	
	ent:SetModel( model )
	ent:SetSkin( iSkin )
	ent:SetAngles( ang )
	ent:SetBodyGroups( strBody )
	ent:SetPos( tr.HitPos )
	ent:Spawn()
	ent:Activate()

	-- Attempt to move the object so it sits flush
	-- We could do a TraceEntity instead of doing all 
	-- of this - but it feels off after the old way

	local vFlushPoint = tr.HitPos - ( tr.HitNormal * 512 )	-- Find a point that is definitely out of the object in the direction of the floor
		vFlushPoint = ent:NearestPoint( vFlushPoint )			-- Find the nearest point inside the object to that point
		vFlushPoint = ent:GetPos() - vFlushPoint				-- Get the difference
		vFlushPoint = tr.HitPos + vFlushPoint					-- Add it to our target pos
										
	if (entity_name != "prop_ragdoll") then
	
		-- Set new position
		ent:SetPos( vFlushPoint )
		player:SendLua( "achievements.SpawnedProp()" );
	
	else
	
		-- With ragdolls we need to move each physobject
		local VecOffset = vFlushPoint - ent:GetPos()
		for i=0, ent:GetPhysicsObjectCount()-1 do
			local phys = ent:GetPhysicsObjectNum( i )
			phys:SetPos( phys:GetPos() + VecOffset )
		end
		
		player:SendLua( "achievements.SpawnedRagdoll()" );
		
	end

	return ent
	
end


concommand.Add( "gm_spawn", CCSpawn, nil, "Spawns props/ragdolls" )

local function InternalSpawnNPC( Player, Position, Normal, Class, Equipment )

	local NPCList = list.Get( "NPC" )
	local NPCData = NPCList[ Class ]
	
	-- Don't let them spawn this entity if it isn't in our NPC Spawn list.
	-- We don't want them spawning any entity they like!
	if ( !NPCData ) then 
		if ( IsValid( Player ) ) then
			Player:SendLua( "Derma_Message( \"Sorry! You can't spawn that NPC!\" )" );
		end
	return end

	if ( NPCData.AdminOnly && !Player:IsAdmin() ) then return end

	local bDropToFloor = false
		
	--
	-- This NPC has to be spawned on a ceiling ( Barnacle )
	--
	if ( NPCData.OnCeiling && Vector( 0, 0, -1 ):Dot( Normal ) < 0.95 ) then
		return nil
	end
	
	--
	-- This NPC has to be spawned on a floor ( Turrets )
	--
	if ( NPCData.OnFloor && Vector( 0, 0, 1 ):Dot( Normal ) < 0.95 ) then
		return nil
	else
		bDropToFloor = true
	end
	
	if ( NPCData.NoDrop ) then bDropToFloor = false end
	
	--
	-- Offset the position
	--
	local Offset = NPCData.Offset or 32
	Position = Position + Normal * Offset
	
	
	-- Create NPC
	local NPC = ents.Create( NPCData.Class )
	if ( !IsValid( NPC ) ) then return end

	NPC:SetPos( Position )
	
	-- Rotate to face player (expected behaviour)
	local Angles = Angle( 0, 0, 0 )
	
		if ( IsValid( Player ) ) then
			Angles = Player:GetAngles()
		end
	
		Angles.pitch = 0
		Angles.roll = 0
		Angles.yaw = Angles.yaw + 180

	if ( NPCData.Rotate ) then Angles = Angles + NPCData.Rotate end
		
	NPC:SetAngles( Angles )
	
	--
	-- This NPC has a special model we want to define
	--
	if ( NPCData.Model ) then
		NPC:SetModel( NPCData.Model )
	end
	
	--
	-- This NPC has a special texture we want to define
	--
	if ( NPCData.Material ) then
		NPC:SetMaterial( NPCData.Material )
	end
	
	--
	-- Spawn Flags
	--
	local SpawnFlags = bit.bor( SF_NPC_FADE_CORPSE, SF_NPC_ALWAYSTHINK )
	if ( NPCData.SpawnFlags ) then SpawnFlags = bit.bor( SpawnFlags, NPCData.SpawnFlags ) end
	if ( NPCData.TotalSpawnFlags ) then SpawnFlags = NPCData.TotalSpawnFlags end
	NPC:SetKeyValue( "spawnflags", SpawnFlags )
	
	--
	-- Optional Key Values
	--
	if ( NPCData.KeyValues ) then
		for k, v in pairs( NPCData.KeyValues ) do
			NPC:SetKeyValue( k, v )
		end		
	end
	
	--
	-- This NPC has a special skin we want to define
	--
	if ( NPCData.Skin ) then
		NPC:SetSkin( NPCData.Skin )
	end
	
	--
	-- What weapon should this mother be carrying
	--
	
	if ( Equipment && Equipment != "none" ) then
		NPC:SetKeyValue( "additionalequipment", Equipment )
		NPC.Equipment = Equipment 
	end
	
	DoPropSpawnedEffect( NPC )
	
	NPC:Spawn()
	NPC:Activate()
	
	if ( bDropToFloor && !NPCData.OnCeiling ) then
		NPC:DropToFloor()	
	end
	
	return NPC
	
end

function Spawn_NPC( player, NPCClassName, WeaponName, tr )

	if ( !NPCClassName ) then return end

	-- Give the gamemode an opportunity to deny spawning
	if ( !gamemode.Call( "PlayerSpawnNPC", player, NPCClassName, WeaponName ) ) then return end
	
	if ( !tr ) then

		local vStart = player:GetShootPos()
		local vForward = player:GetAimVector()
	
		local trace = {}
			trace.start = vStart
			trace.endpos = vStart + vForward * 2048
			trace.filter = player

		tr = util.TraceLine( trace )

	end
	
	-- Create the NPC is you can.
	local SpawnedNPC = InternalSpawnNPC( player, tr.HitPos, tr.HitNormal, NPCClassName, WeaponName )
	if ( !IsValid( SpawnedNPC ) ) then return end

	-- Give the gamemode an opportunity to do whatever
	if ( IsValid( player ) ) then
		gamemode.Call( "PlayerSpawnedNPC", player, SpawnedNPC )
	end
	
	-- See if we can find a nice name for this NPC..
	local NPCList = list.Get( "NPC" )
	local NiceName = nil
	if ( NPCList[ NPCClassName ] ) then 
		NiceName = NPCList[ NPCClassName ].Name
	end

	-- Add to undo list
	undo.Create("NPC")
		undo.SetPlayer( player )
		undo.AddEntity( SpawnedNPC )
		if ( NiceName ) then
			undo.SetCustomUndoText( "Undone "..NiceName )
		end
	undo.Finish( "NPC ("..tostring(NPCClassName)..")" )
	
	-- And cleanup
	player:AddCleanup( "npcs", SpawnedNPC )
	
	player:SendLua( "achievements.SpawnedNPC()" );

end

concommand.Add( "gmod_spawnnpc", function( ply, cmd, args ) Spawn_NPC( ply, args[1], args[2] ) end )


local function GenericNPCDuplicator( Player, Model, Class, Equipment, SpawnFlags, Data )

	if ( !gamemode.Call( "PlayerSpawnNPC", Player, Class, Equipment ) ) then return end

	local Entity = InternalSpawnNPC( Player, Data.Pos, Vector(0,0,1), Class, Equipment, SpawnFlags )
	
	if ( IsValid( Entity ) ) then

		duplicator.DoGeneric( Entity, Data )

		if ( IsValid( Player ) ) then
			gamemode.Call( "PlayerSpawnedNPC", Player, Entity )
			Player:AddCleanup( "npcs", Entity )
		end
		
		table.Add( Entity:GetTable(), Data )
		
	end
	
	return Entity
	
end

-- Huuuuuuuuhhhh
duplicator.RegisterEntityClass( "npc_alyx", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_antlion", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_antlionguard", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_barnacle", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_barney", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_breen", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_combine_s", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_combine_p", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_combine_e", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_crow", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_cscanner", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_dog", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_eli", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_fastzombie", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_gman", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_headcrab", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_headcrab_black", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_headcrab_fast", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_kleiner", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_manhack", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_metropolice", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_monk", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_mossman", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_pigeon", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_rollermine", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_seagull", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_zombie", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_zombie_torso", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_citizen_rebel", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_citizen", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_citizen_dt", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_citizen_medic", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_stalker", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "npc_fisherman", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )

-- HL1
duplicator.RegisterEntityClass( "monster_bigmomma", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_bullchicken", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_gargantua", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_human_assassin", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_babycrab", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_human_grunt", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_cockroach", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_houndeye", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_scientist", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_snark", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_zombie", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_barney", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_alien_controller", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )
duplicator.RegisterEntityClass( "monster_headcrab", GenericNPCDuplicator, "Model", "Class", "Equipment", "SpawnFlags", "Data"  )


--[[---------------------------------------------------------
   Name: CanPlayerSpawnSENT
-----------------------------------------------------------]]
local function CanPlayerSpawnSENT( player, EntityName )

	-- Make sure this is a SWEP
	local sent = scripted_ents.GetStored( EntityName )
	if ( sent == nil ) then 
	
		-- Is this in the SpawnableEntities list?
		local SpawnableEntities = list.Get( "SpawnableEntities" )
		if ( !SpawnableEntities ) then return false end
		local EntTable = SpawnableEntities[ EntityName ]
		if ( !EntTable ) then return false end
		if ( EntTable.AdminOnly && !player:IsAdmin() ) then return false end
		return true 
	
	end

	-- We need a spawn function. The SENT can then spawn itself properly
	local SpawnFunction = scripted_ents.GetMember( EntityName, "SpawnFunction" )
	if ( !isfunction( SpawnFunction ) ) then return false end
	
	-- You're not allowed to spawn this unless you're an admin!
	if ( !scripted_ents.GetMember( EntityName, "Spawnable" ) && !player:IsAdmin() ) then return false end 
	if ( scripted_ents.GetMember( EntityName, "AdminOnly" ) && !player:IsAdmin() ) then return false end
	
	return true
	
end

--[[---------------------------------------------------------
   Name: Spawn_SENT
   Desc: Console Command for a player to spawn different items
-----------------------------------------------------------]]
function Spawn_SENT( player, EntityName, tr )

	if ( EntityName == nil ) then return end

	if ( !CanPlayerSpawnSENT( player, EntityName ) ) then return end
	
	-- Ask the gamemode if it's ok to spawn this
	if ( !gamemode.Call( "PlayerSpawnSENT", player, EntityName ) ) then return end
	
	local vStart = player:EyePos()
	local vForward = player:GetAimVector()
	
	if ( !tr ) then

		local trace = {}
		trace.start = vStart
		trace.endpos = vStart + (vForward * 4096)
		trace.filter = player

		tr = util.TraceLine( trace )

	end
	
	local entity = nil
	local PrintName = nil
	local sent = scripted_ents.GetStored( EntityName )
	if ( sent ) then
	
		local sent = sent.t
		
		ClassName = EntityName
		
			local SpawnFunction = scripted_ents.GetMember( EntityName, "SpawnFunction" )
			if ( !SpawnFunction ) then return end
			entity = SpawnFunction( sent, player, tr, EntityName )

			if ( IsValid( entity ) ) then
				entity:SetCreator( player )
			end
			
		ClassName = nil
		
		PrintName = sent.PrintName
	
	else
	
		-- Spawn from list table
		local SpawnableEntities = list.Get( "SpawnableEntities" )
		if (!SpawnableEntities) then return end
		local EntTable = SpawnableEntities[ EntityName ]
		if (!EntTable) then return end
		
		PrintName = EntTable.PrintName
		
		local SpawnPos = tr.HitPos + tr.HitNormal * 16
		if ( EntTable.NormalOffset ) then SpawnPos = SpawnPos + tr.HitNormal * EntTable.NormalOffset end
	
		entity = ents.Create( EntTable.ClassName )
			entity:SetPos( SpawnPos )
		entity:Spawn()
		entity:Activate()
		
		if ( EntTable.DropToFloor ) then
			entity:DropToFloor()
		end
	
	end
	

	if ( IsValid( entity ) ) then
	
		if ( IsValid( player ) ) then
			gamemode.Call( "PlayerSpawnedSENT", player, entity )
		end
		
		undo.Create("SENT")
			undo.SetPlayer(player)
			undo.AddEntity(entity)
			if ( PrintName ) then
				undo.SetCustomUndoText( "Undone "..PrintName )
			end
		undo.Finish( "Scripted Entity ("..tostring( EntityName )..")" )
		
		player:AddCleanup( "sents", entity )		
		entity:SetVar( "Player", player )

	end
	
	
end

concommand.Add( "gm_spawnsent", function( ply, cmd, args ) Spawn_SENT( ply, args[1] ) end )

--[[---------------------------------------------------------
	-- Give a swep.. duh.
-----------------------------------------------------------]]
function CCGiveSWEP( player, command, arguments )

	if ( arguments[1] == nil ) then return end

	-- Make sure this is a SWEP
	local swep = list.Get( "Weapon" )[ arguments[1] ];
	if (swep == nil) then return end
	
	-- You're not allowed to spawn this!
	if ( ( !swep.Spawnable && !player:IsAdmin() ) || ( swep.AdminOnly && !player:IsAdmin() ) ) then
		return
	end
	
	if ( !gamemode.Call( "PlayerGiveSWEP", player, arguments[1], swep ) ) then return end
	
	MsgAll( "Giving "..player:Nick().." a "..swep.ClassName.."\n" )
	player:Give( swep.ClassName )
	
	-- And switch to it
	player:SelectWeapon( swep.ClassName )
	
end

concommand.Add( "gm_giveswep", CCGiveSWEP )

--[[---------------------------------------------------------
	-- Give a swep.. duh.
-----------------------------------------------------------]]
function Spawn_Weapon( Player, wepname, tr )

	if ( wepname == nil ) then return end

	local swep = list.Get( "Weapon" )[ wepname ];

	-- Make sure this is a SWEP
	if ( swep == nil ) then return end
	
	-- You're not allowed to spawn this!
	if ( ( !swep.Spawnable && !Player:IsAdmin() ) || ( swep.AdminOnly && !Player:IsAdmin() ) ) then
		return
	end
	
	if ( !gamemode.Call( "PlayerSpawnSWEP", Player, wepname, swep ) ) then return end
	
	if ( !tr ) then
		tr = Player:GetEyeTraceNoCursor()
	end

	if ( !tr.Hit ) then return end
	
	local entity = ents.Create( swep.ClassName )
	
	if ( IsValid( entity ) ) then
	
		entity:SetPos( tr.HitPos + tr.HitNormal * 32 )
		entity:Spawn()
		
		gamemode.Call( "PlayerSpawnedSWEP", Player, entity )
	
	end

	
end

concommand.Add( "gm_spawnswep", function( ply, cmd, args ) Spawn_Weapon( ply, args[1] ) end )


local function MakeVehicle( Player, Pos, Ang, Model, Class, VName, VTable )

	if (!gamemode.Call( "PlayerSpawnVehicle", Player, Model, VName, VTable )) then return end
	
	local Ent = ents.Create( Class )
	if (!Ent) then return NULL end
	
	Ent:SetModel( Model )
	
	-- Fill in the keyvalues if we have them
	if ( VTable && VTable.KeyValues ) then
		for k, v in pairs( VTable.KeyValues ) do
			Ent:SetKeyValue( k, v )
		end		
	end
		
	Ent:SetAngles( Ang )
	Ent:SetPos( Pos )

	DoPropSpawnedEffect( Ent )
		
	Ent:Spawn()
	Ent:Activate()
	
	Ent.VehicleName 	= VName
	Ent.VehicleTable 	= VTable
	
	-- We need to override the class in the case of the Jeep, because it 
	-- actually uses a different class than is reported by GetClass
	Ent.ClassOverride 	= Class

	if ( IsValid( Player ) ) then
		gamemode.Call( "PlayerSpawnedVehicle", Player, Ent )
	end

	return Ent	
	
end

duplicator.RegisterEntityClass( "prop_vehicle_jeep_old",   		MakeVehicle, "Pos", "Ang", "Model", "Class", "VehicleName", "VehicleTable" )
duplicator.RegisterEntityClass( "prop_vehicle_jeep",    		MakeVehicle, "Pos", "Ang", "Model", "Class", "VehicleName", "VehicleTable" )
duplicator.RegisterEntityClass( "prop_vehicle_airboat", 		MakeVehicle, "Pos", "Ang", "Model", "Class", "VehicleName", "VehicleTable" )
duplicator.RegisterEntityClass( "prop_vehicle_prisoner_pod", 	MakeVehicle, "Pos", "Ang", "Model", "Class", "VehicleName", "VehicleTable" )


--[[---------------------------------------------------------
   Name: CCSpawnVehicle
   Desc: Player attempts to spawn vehicle
-----------------------------------------------------------]]
function Spawn_Vehicle( Player, vname, tr )

	if ( !vname ) then return end

	local VehicleList = list.Get( "Vehicles" )
	local vehicle = VehicleList[ vname ]
	
	-- Not a valid vehicle to be spawning..
	if ( !vehicle ) then return end
	
	if ( !tr ) then
		tr = Player:GetEyeTraceNoCursor()
	end
	
	local Angles = Player:GetAngles()
		Angles.pitch = 0
		Angles.roll = 0
		Angles.yaw = Angles.yaw + 180
	
	local Ent = MakeVehicle( Player, tr.HitPos, Angles, vehicle.Model, vehicle.Class, vname, vehicle ) 
	if ( !IsValid( Ent ) ) then return end
	
	if ( vehicle.Members ) then
		table.Merge( Ent, vehicle.Members )
		duplicator.StoreEntityModifier( Ent, "VehicleMemDupe", vehicle.Members );
	end
	
	undo.Create( "Vehicle" )
		undo.SetPlayer( Player )
		undo.AddEntity( Ent )
		undo.SetCustomUndoText( "Undone "..vehicle.Name )
	undo.Finish( "Vehicle ("..tostring( vehicle.Name )..")" )
	
	Player:AddCleanup( "vehicles", Ent )
	
end

concommand.Add( "gm_spawnvehicle", function( ply, cmd, args ) Spawn_Vehicle( ply, args[1] ) end )


local function VehicleMemDupe( Player, Entity, Data )

	table.Merge( Entity, Data );
	
end
duplicator.RegisterEntityModifier( "VehicleMemDupe", VehicleMemDupe );
