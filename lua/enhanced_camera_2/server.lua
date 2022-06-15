include("shared.lua")
AddCSLuaFile("client.lua")

local cvarStaticEnabled = CreateConVar("sv_ec2_staticheight", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Statically adjust players' view heights to match their models")
local cvarHeightEnabled = CreateConVar("sv_ec2_dynamicheight", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Dynamically adjust players' view heights to match their models")
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

	if cvarStaticEnabled:GetBool() and ply:GetInfoNum("cl_ec2_staticheight", 1) == 1 then

		-- Find the height by spawning a dummy entity
		local height = GetViewOffsetValue(ply, "idle_all_01") or 64
		local crouch = GetViewOffsetValue(ply, "cidle_all") or 28

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

local function ShouldUpdateViewOffset(ply, seq, height)
	local mode = ply:GetInfoNum("cl_ec2_dynamicheight", 1)
	if mode == 1 and height ~= ply.ec2_height then
		return true
	elseif mode == 2 and (not ply.ec2_height or height > ply.ec2_height) then
		return true
	end
	return seq ~= ply.ec2_seq
end

local function UpdateViewOffset(ply)

	if not cvarHeightEnabled:GetBool() then return end

	if ply:GetInfoNum("cl_ec2_dynamicheight", 1) == 0 then return end

	local seq = ply:GetSequence()

	local bone = ply._ec2_headbone or EnhancedCameraTwo:GetBone(ply)

	local height = 64

	local pos = Vector(0, 0, 0)

	if bone then

		local plyPos = ply:GetPos()

		pos = ply:GetBonePosition(bone) or pos

		if pos == plyPos then
			pos = ply:GetBoneMatrix(bone):GetTranslation() or pos
		end

		pos = pos - plyPos

		height = math.Round(pos.z + 14, 2)

	end

	if ShouldUpdateViewOffset(ply, seq, height) then

		local min = cvarHeightMin:GetInt()
		local max = cvarHeightMax:GetInt()
		ply:SetCurrentViewOffset(Vector(0, 0, math.Clamp(height, min, max)))

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

local function ConVarChanged(_, _, _)
	for _, ply in pairs(player.GetAll()) do
		ply._ec2_headbone = nil
		UpdateView(ply)
	end
end

cvars.AddChangeCallback("sv_ec2_staticheight", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight_min", ConVarChanged)
cvars.AddChangeCallback("sv_ec2_dynamicheight_max", ConVarChanged)

local plyMeta = FindMetaTable("Player")
EnhancedCameraTwo.BackupFuncs = EnhancedCameraTwo.BackupFuncs or {
	SetViewOffset = plyMeta.SetViewOffset,
	SetViewOffsetDucked = plyMeta.SetViewOffsetDucked,
	SetCurrentViewOffset = plyMeta.SetCurrentViewOffset,
}

concommand.Add("ec2_debug_enable_sv", function()
	local funcs = EnhancedCameraTwo.BackupFuncs
	function plyMeta:SetViewOffset(viewOffset)
		debug.Trace()
		return funcs.SetViewOffset(self, viewOffset)
	end
	function plyMeta:SetViewOffsetDucked(viewOffset)
		debug.Trace()
		return funcs.SetViewOffsetDucked(self, viewOffset)
	end
	function plyMeta:SetCurrentViewOffset(viewOffset)
		debug.Trace()
		return funcs.SetCurrentViewOffset(self, viewOffset)
	end
end)

concommand.Add("ec2_debug_disable_sv", function()
	local funcs = EnhancedCameraTwo.BackupFuncs
	plyMeta.SetViewOffset = funcs.SetViewOffset
	plyMeta.SetViewOffsetDucked = funcs.SetViewOffsetDucked
	plyMeta.SetCurrentViewOffset = funcs.SetCurrentViewOffset
end)

concommand.Add("ec2_debug_print_hooks_sv", function()
	print("PlayerSpawn\n")
	PrintTable(hook.GetTable().PlayerSpawn)
	print()
	print()
	print("PlayerTick\n")
	PrintTable(hook.GetTable().PlayerTick)
end)
