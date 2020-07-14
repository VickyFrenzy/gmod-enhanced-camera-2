AddCSLuaFile("../client/enhanced_camera.lua")

local cvarHeightEnabled = CreateConVar("sv_ec_dynamicheight", "1", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED})
local cvarHeightMin = CreateConVar("sv_ec_dynamicheight_min", "16", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE})
local cvarHeightMax = CreateConVar("sv_ec_dynamicheight_max", "64", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE})

local function UpdateView(ply)
	if cvarHeightEnabled:GetBool() then
		-- Find the height by spawning a dummy entity
		local height = 64
		local crouch = 28

		local entity = ents.Create("base_anim")
		entity:SetModel(ply:GetModel())

		local bone = entity:LookupBone("ValveBiped.Bip01_Neck1")

		entity:ResetSequence("idle_all_01")
		if bone then
			height = entity:GetBonePosition(bone).z + 5
		end

		entity:Remove()

		local entity_crouch = ents.Create("base_anim")
		entity_crouch:SetModel(ply:GetModel())

		local bone_crouch = entity_crouch:LookupBone("ValveBiped.Bip01_Neck1")

		entity_crouch:ResetSequence("cidle_all")
		if bone_crouch then
			crouch = entity_crouch:GetBonePosition(bone_crouch).z + 5
		end

		entity_crouch:Remove()

		-- Update player height
		local min = cvarHeightMin:GetInt()
		local max = cvarHeightMax:GetInt()
		ply:SetViewOffset(Vector(0, 0, math.Clamp(height, min, max)))
		ply:SetViewOffsetDucked(Vector(0, 0, math.Clamp(crouch, min, max)))
		ply.ec_ViewChanged = true
	else
		if ply.ec_ViewChanged then
			ply:SetViewOffset(Vector(0, 0, 64))
			ply:SetViewOffsetDucked(Vector(0, 0, 28))
			ply.ec_ViewChanged = nil
		end
	end
end

local function UpdateTrueModel(ply)
	if ply:GetNWString("EnhancedCamera:TrueModel") ~= ply:GetModel() then
		ply:SetNWString("EnhancedCamera:TrueModel", ply:GetModel())
		UpdateView(ply)
	end
end

hook.Add("PlayerSpawn", "EnhancedCamera:PlayerSpawn", function(ply)
	UpdateTrueModel(ply)
end)

hook.Add("PlayerTick", "EnhancedCamera:PlayerTick", function(ply)
	UpdateTrueModel(ply)
end)

local function ConVarChanged(name, oldVal, newVal)
	for _, ply in pairs(player.GetAll()) do
		UpdateView(ply)
	end
end

cvars.AddChangeCallback("sv_ec_dynamicheight", ConVarChanged)
cvars.AddChangeCallback("sv_ec_dynamicheight_min", ConVarChanged)
cvars.AddChangeCallback("sv_ec_dynamicheight_max", ConVarChanged)
