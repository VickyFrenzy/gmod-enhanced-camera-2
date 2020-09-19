AddCSLuaFile("client.lua")

local cvarHeightEnabled = CreateConVar("sv_ec2_dynamicheight", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Dynamically adjust players' view heights to match their models")
local cvarHeightMin = CreateConVar("sv_ec2_dynamicheight_min", 16, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Minimum view height")
local cvarHeightMax = CreateConVar("sv_ec2_dynamicheight_max", 64, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Maximum view height")

local function GetViewOffsetValue(ply, bone_name, sequence, offset)

	local height

	local entity = ents.Create("base_anim")
	entity:SetModel(ply:GetModel())

	local bone = entity:LookupBone(bone_name)

	entity:ResetSequence(sequence)

	entity:SetPoseParameter("move_x", ply:GetPoseParameter("move_x"))
	entity:SetPoseParameter("move_y", ply:GetPoseParameter("move_y"))

	if bone then
		height = entity:GetBonePosition(bone).z + (offset or 6)
	end

	entity:Remove()

	return height

end

local function UpdateView(ply)

	if cvarHeightEnabled:GetBool() and ply:GetInfoNum("cl_ec2_dynamicheight", 1) == 1 then

		local bone = "ValveBiped.Bip01_Neck1"

		-- Find the height by spawning a dummy entity
		local height = GetViewOffsetValue(ply, bone, "idle_all_01")
		local crouch = GetViewOffsetValue(ply, bone, "cidle_all")

		-- Update player height
		local min = cvarHeightMin:GetInt()
		local max = cvarHeightMax:GetInt()

		ply:SetViewOffset(Vector(0, 0, math.Clamp(height or 64, min, max)))
		ply:SetViewOffsetDucked(Vector(0, 0, math.Clamp(crouch or 28, min, max)))

		ply.ec_ViewChanged = true

	elseif ply.ec_ViewChanged then

		ply:SetViewOffset(Vector(0, 0, 64))
		ply:SetViewOffsetDucked(Vector(0, 0, 28))

		ply.ec_ViewChanged = nil

	end

end

local function UpdateViewOffset(ply)

	if not cvarHeightEnabled:GetBool() then return end

	if ply:GetInfoNum("cl_ec2_dynamicheight", 1) == 0 then return end

	local seq = ply:GetSequence()
	local bone_name = "ValveBiped.Bip01_Neck1"

	local bone = ply:LookupBone(bone_name)

	local height = 64

	local pos = Vector(0, 0, 0)

	if bone then

		pos = ply:GetBonePosition(bone)

		if pos == ply:GetPos() then
			pos = ply:GetBoneMatrix(bone):GetTranslation()
		end

		pos = pos - ply:GetPos()

		height = math.Round(pos.z + 14, 2)

	end

	if seq ~= ply.ec2_seq or height ~= ply.ec2_height then

		local min = cvarHeightMin:GetInt()
		local max = cvarHeightMax:GetInt()

		ply:SetCurrentViewOffset(Vector(0, 0, math.Clamp(height or 64, min, max)))

		ply.ec2_seq = seq

		ply.ec2_height = height

	end

end

local function UpdateTrueModel(ply)
	if ply:GetNWString("EnhancedCameraTwo:TrueModel") ~= ply:GetModel() then
		ply:SetNWString("EnhancedCameraTwo:TrueModel", ply:GetModel())
		UpdateView(ply)
	end
end

hook.Add("PlayerSpawn", "EnhancedCameraTwo:PlayerSpawn", function(ply)
	UpdateTrueModel(ply)
end)

hook.Add("PlayerTick", "EnhancedCameraTwo:PlayerTick", function(ply)
	UpdateTrueModel(ply)
	UpdateViewOffset(ply)
end)

local function ConVarChanged(name, oldVal, newVal)
	for _, ply in pairs(player.GetAll()) do
		UpdateView(ply)
	end
end

cvars.AddChangeCallback("sv_ec2_dynamicheight", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight_min", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight_max", ConVarChanged)
