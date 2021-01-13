include("shared.lua")
AddCSLuaFile("client.lua")

local cvarHeightEnabled = CreateConVar("sv_ec2_dynamicheight", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Dynamically adjust players' view heights to match their models")
local cvarHeightCrouchEnabled = CreateConVar("sv_ec2_dynamicheight_crouch", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Dynamically adjust players' view heights to match their models while crouching. If disabled, crouch height will not be dynamic.")
local cvarHeightMin = CreateConVar("sv_ec2_dynamicheight_min", 16, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Minimum view height")
local cvarHeightMax = CreateConVar("sv_ec2_dynamicheight_max", 64, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Maximum view height")



local function GetViewOffsetValue(ply, sequence, offset)

	local height

	local entity = ents.Create("base_anim")
	entity:SetModel(ply:GetModel())

	local bone = EnhancedCameraTwo:GetBone(entity)

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

		-- Find the height by spawning a dummy entity
		local height = GetViewOffsetValue(ply, "idle_all_01")
		local crouch = GetViewOffsetValue(ply, "cidle_all")

		-- Update player height
		local min = cvarHeightMin:GetInt()
		local max = cvarHeightMax:GetInt()

		ply:SetViewOffset(Vector(0, 0, math.Clamp(height, min, max)))
		ply:SetViewOffsetDucked(Vector(0, 0, math.Clamp(crouch, min, min)))
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

	local bone = ply._ec2_headbone or EnhancedCameraTwo:GetBone(ply)

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
		if cvarHeightCrouchEnabled:GetBool() and ply:GetInfoNum("cl_ec2_dynamicheight_crouch", 1) == 1 then
			ply:SetCurrentViewOffset(Vector(0, 0, math.Clamp(height or 64, min, max)))
		end
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
	ply._ec2_headbone = nil
	UpdateTrueModel(ply)
end)

hook.Add("PlayerTick", "EnhancedCameraTwo:PlayerTick", function(ply)
	UpdateTrueModel(ply)
	UpdateViewOffset(ply)
end)

local function ConVarChanged(name, oldVal, newVal)
	for _, ply in pairs(player.GetAll()) do
		ply._ec2_headbone = nil
		UpdateView(ply)
	end
end

cvars.AddChangeCallback("sv_ec2_dynamicheight", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight_crouch", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight_min", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight_max", ConVarChanged)


