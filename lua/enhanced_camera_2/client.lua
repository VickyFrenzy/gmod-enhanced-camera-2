local cvarEnabled = CreateConVar("cl_ec2_enabled", 1, {FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE}, "Show your body in first-person")
local cvarHair = CreateConVar("cl_ec2_showhair", 1, {FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE}, "Show your hair (bones attached to head) in first-person")
local cvarVehicle = CreateConVar("cl_ec2_vehicle", 1, {FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE}, "Show your body while in vehicles")
local cvarVehicleYawLock = CreateConVar("cl_ec2_vehicle_yawlock", 1, {FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE}, "Restrict yaw while in vehicles to prevent looking backwards at your neck. Yaw is not restricted regardless of this setting if either \"cl_ec2_enabled\" or \"cl_ec2_vehicle\" is 0.")
local cvarVehicleYawLockMax = CreateConVar("cl_ec2_vehicle_yawlock_max", 65, {FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE}, "Angle (in degrees) you can look away from the center view of a vehicle when \"cl_ec2_vehicle_yawlock\" is 1.")
CreateConVar("cl_ec2_staticheight", 1, {FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_USERINFO}, "Statically adjust your view height to match your model")
CreateConVar("cl_ec2_dynamicheight", 1, {FCVAR_CLIENTCMD_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_USERINFO}, "Dynamically adjust your view height to match your model")

EnhancedCameraTwo = EnhancedCameraTwo or {
	-- Animation/Rendering
	entity = nil,
	skelEntity = nil,
	lastTick = 0,

	-- Variables to detect change in model state
	model = nil,
	bodyGroups = nil,
	materials = nil,
	skin = nil,
	material = nil,
	color = nil,

	-- Variables to detect change in pose state
	weapon = nil,
	sequence = nil,
	reloading = false,

	-- Pose-dependent variables
	pose = "",
	viewOffset = Vector(0, 0, 0),
	neckOffset = Vector(0, 0, 0),
	vehicleAngle = 0,

	-- Model-dependent variables
	ragdollSequence = nil,
	idleSequence = nil,

	-- API variables
	apiBoneHide = {}
}

include("shared.lua")

-- PUBLIC API
function EnhancedCameraTwo:SetLimbHidden(limb, hidden)
	-- `limb` may be "l_arm", "r_arm", "l_leg", or "r_leg"
	-- `hidden` is a bool describing the desired visibility
	-- Limbs hidden because of pose will not be visible regardless of this setting.
	self.apiBoneHide[limb] = hidden and true or nil
	self:Refresh()
end

-- Global functions
local function ApproximatePlayerModel()
	-- Return a value suitable for detecting model changes
	return LocalPlayer():GetNWString("EnhancedCameraTwo:TrueModel", LocalPlayer():GetModel())
end

local function GetPlayerBodyGroups()
	local bodygroups = {}
	for _, v in pairs(LocalPlayer():GetBodyGroups()) do
		bodygroups[v.id] = LocalPlayer():GetBodygroup(v.id)
	end
	return bodygroups
end

local function GetPlayerMaterials()
	local materials = {}
	for k, _ in pairs(LocalPlayer():GetMaterials()) do
		materials[k - 1] = LocalPlayer():GetSubMaterial(k - 1)
	end
	return materials
end

-- Body entity functions
function EnhancedCameraTwo:SetModel(model)
	if not IsValid(self.entity) then
		self.entity = ClientsideModel(model)
		self.entity:SetNoDraw(true)
		self.entity.GetPlayerColor = function()
			return LocalPlayer():GetPlayerColor()
		end
		self.entity.GetWeaponColor = function()
			return LocalPlayer():GetWeaponColor()
		end
	else
		self.entity:SetModel(model)
	end
	if not IsValid(self.skelEntity) then
		self.skelEntity = ClientsideModel(model)
		self.skelEntity:SetNoDraw(true)
	else
		self.skelEntity:SetModel(model)
	end

	self.skelEntity.neck = self:GetBone(self.skelEntity)

	self.ragdollSequence = self.entity:LookupSequence("ragdoll")
	self.idleSequence = self.entity:LookupSequence("idle_all_01")
end

function EnhancedCameraTwo:ResetSequence(seq)
	self.entity:ResetSequence(seq)
	self.skelEntity:ResetSequence(seq)
end

function EnhancedCameraTwo:SetPlaybackRate(fSpeed)
	self.entity:SetPlaybackRate(fSpeed)
	self.skelEntity:SetPlaybackRate(fSpeed)
end

function EnhancedCameraTwo:FrameAdvance(delta)
	self.entity:FrameAdvance(delta)
	self.skelEntity:FrameAdvance(delta)
end

function EnhancedCameraTwo:SetPoseParameter(poseName, poseValue)
	self.entity:SetPoseParameter(poseName, poseValue)
	self.skelEntity:SetPoseParameter(poseName, poseValue)
end

-- Body utility functions
function EnhancedCameraTwo:HasChanged(key, newvalue)
	if self[key] ~= newvalue then
		self[key] = newvalue
		return true
	end
	return false
end

function EnhancedCameraTwo:HasTableChanged(key, newtable)
	local tbl = self[key]
	if tbl == newtable then
		return false
	end
	if tbl == nil or newtable == nil then
		self[key] = newtable
		return true
	end
	if #tbl ~= #newtable then
		self[key] = newtable
		return true
	end
	for k, v in pairs(tbl) do
		if newtable[k] ~= v then
			self[key] = newtable
			return true
		end
	end
	return false
end

function EnhancedCameraTwo:Refresh()
	self.model = nil
	self.sequence = nil
	self.pose = nil
end

-- Body state functions
function EnhancedCameraTwo:ShouldDraw()
	return cvarEnabled:GetBool() and
		(not LocalPlayer():InVehicle() or cvarVehicle:GetBool()) and
		IsValid(self.entity) and
		IsValid(self.skelEntity) and
		LocalPlayer():Alive() and
		GetViewEntity() == LocalPlayer() and
		not LocalPlayer():ShouldDrawLocalPlayer() and
		LocalPlayer():GetObserverMode() == 0 and
		self.skelEntity.neck and
		self.skelEntity.neck ~= 0 and
		not IsValid(BodyAnimMDL) and
		not IsValid(BodyAnim)
end

function EnhancedCameraTwo:GetPose()
	-- Weapon:Getpose() is very unreliable at the time of writing.
	local seqname = LocalPlayer():GetSequenceName(self.sequence)
	local wep = LocalPlayer():GetActiveWeapon()
	if seqname == "ragdoll" then
		return "normal"
	elseif string.StartWith(seqname, "sit") then
		return "sit"
	elseif seqname == "drive_pd" then
		return "pod"
	elseif string.StartWith(seqname, "drive") then
		return "drive"
	end
	local pose = string.sub(seqname, (string.find(seqname, "_") or 0) + 1)
	pose = (wep and wep.DefaultHoldType) or pose
	if string.find(pose, "all") then
		return "normal"
	elseif pose == "smg1" then
		return "smg"
	end
	return pose
end

function EnhancedCameraTwo:GetModel()
	-- Try to find the actual player model based on the often vague guess given
	-- by GetModel()
	local model_name = self.model
	if util.IsValidModel(model_name) then return model_name end

	-- Search for a matching model name in the list of valid models
	local basename = string.GetFileFromFilename(model_name)
	for _, name in pairs(player_manager.AllValidModels()) do
		if string.GetFileFromFilename(name) == basename then
			return name
		end
	end

	return "models/player/kleiner.mdl"
end

function EnhancedCameraTwo:GetSequence()
	local sequence = LocalPlayer():GetSequence()
	if sequence == self.ragdollSequence then
		return self.idleSequence
	end
	return sequence
end

function EnhancedCameraTwo:GetRenderPosAngle()
	local renderPos = EyePos()
	local renderAngle = nil
	local ply = LocalPlayer()

	if ply:InVehicle() then
		renderAngle = ply:GetVehicle():GetAngles()
		renderAngle:RotateAroundAxis(renderAngle:Up(), self.vehicleAngle)
	else
		renderAngle = Angle(0, ply:EyeAngles().y, 0)
	end

	local offset = self.viewOffset - self.neckOffset
	offset:Rotate(renderAngle)

	renderPos = renderPos + offset
	return renderPos, renderAngle
end

-- Set up the body model to match the player model
function EnhancedCameraTwo:OnModelChange()
	self:SetModel(self:GetModel())

	for k, v in pairs(self.bodyGroups) do
		self.entity:SetBodygroup(k, v)
	end

	if self:HasTableChanged("materials", GetPlayerMaterials()) then
		for k, v in pairs(self.materials) do
			self.entity:SetSubMaterial(k, v)
		end
	end

	self.entity:SetSkin(self.skin)
	self.entity:SetMaterial(self.material)
	self.entity:SetColor(self.color)

	-- Update new pose
	self.lastTick = 0
	self.sequence = nil
end

local POSE_SHOW_ARM = {
	left = {
		normal = true,
		sit = true,
		drive = true,
		pod = true,
	},
	right = {
		normal = true,
		sit = true,
		drive = true,
		pod = true,
	},
}

local NAME_SHOW_ARM = {
	left = {
		weapon_crowbar = true,
		weapon_pistol = true,
		weapon_stunstick = true,
		gmod_tool = true,
	},
	right = {
	},
}

local NAME_HIDE_ARM = {
	left = {
		--[[		Compatibilty for Modern Warfare 2019 SWEPs - Pistols
			https://steamcommunity.com/sharedfiles/filedetails/?id=2459723892 ]]
		mg_357 = true,
		mg_deagle = true,
		mg_p320 = true,
		mg_m1911 = true,
		mg_makarov = true,
		mg_m9 = true,
		mg_glock = true,
	},
	right = {
		weapon_bugbait = true,
		--[[		Compatibilty for Modern Warfare 2019 SWEPs - Pistols
			https://steamcommunity.com/sharedfiles/filedetails/?id=2459723892 ]]
		mg_357 = true,
		mg_deagle = true,
		mg_p320 = true,
		mg_m1911 = true,
		mg_makarov = true,
		mg_m9 = true,
		mg_glock = true,
	},
}

-- Hide limbs as appropriate for the current hold type and record the hold
-- type for use elsewhere
function EnhancedCameraTwo:OnPoseChange()
	for i = 0, self.entity:GetBoneCount() do
		self.entity:ManipulateBoneScale(i, Vector(1, 1, 1))
		self.entity:ManipulateBonePosition(i, vector_origin)
	end

	-- Hide appropriate limbs
	local wep = LocalPlayer():GetActiveWeapon()
	local name = IsValid(wep) and wep:GetClass() or ""
	local bone = self.entity:LookupBone("ValveBiped.Bip01_Head1")
	if bone then
		self.entity:ManipulateBoneScale(bone, vector_origin)
		if not cvarHair:GetBool() then
			self.entity:ManipulateBonePosition(bone, Vector(-128, 128, 0))
		end
	end
	if self.apiBoneHide["l_arm"] or self.reloading or not (
			(POSE_SHOW_ARM.left[self.pose] or
			NAME_SHOW_ARM.left[name]) and not
			NAME_HIDE_ARM.left[name]) then
		bone = self.entity:LookupBone("ValveBiped.Bip01_L_Upperarm")
		if bone then
			self.entity:ManipulateBoneScale(bone, vector_origin)
			self.entity:ManipulateBonePosition(bone, Vector(0, 0, -128))
		end
	end
	if self.apiBoneHide["r_arm"] or self.reloading or not (
			(POSE_SHOW_ARM.right[self.pose] or
			NAME_SHOW_ARM.right[name]) and not
			NAME_HIDE_ARM.right[name]) then
		bone = self.entity:LookupBone("ValveBiped.Bip01_R_Upperarm")
		if bone then
			self.entity:ManipulateBoneScale(bone, vector_origin)
			self.entity:ManipulateBonePosition(bone, Vector(0, 0, 128))
		end
	end
	if self.apiBoneHide["l_leg"] then
		bone = self.entity:LookupBone("ValveBiped.Bip01_L_Thigh")
		if bone then
			self.entity:ManipulateBoneScale(bone, vector_origin)
			self.entity:ManipulateBonePosition(bone, Vector(0, 0, -128))
		end
	end
	if self.apiBoneHide["r_leg"] then
		bone = self.entity:LookupBone("ValveBiped.Bip01_R_Thigh")
		if bone then
			self.entity:ManipulateBoneScale(bone, vector_origin)
			self.entity:ManipulateBonePosition(bone, Vector(0, 0, -128))
		end
	end

	-- Set pose-specific view offset
	if self.pose == "normal" or self.pose == "camera" or self.pose == "fist"
			or self.pose == "duel" or self.pose == "dual"
			or self.pose == "passive" or self.pose == "magic" then
		self.viewOffset = Vector(-10, 0, -5)
	elseif self.pose == "melee" or self.pose == "melee2" or
			self.pose == "grenade" or self.pose == "slam" then
		self.viewOffset = Vector(-10, 0, -5)
	elseif self.pose == "knife" then
		self.viewOffset = Vector(-6, 0, -5)
	elseif self.pose == "pistol" or self.pose == "revolver" then
		self.viewOffset = Vector(-10, 0, -5)
	elseif self.pose == "smg" or self.pose == "ar2" or self.pose == "rpg" or
			self.pose == "shotgun" or self.pose == "crossbow" or self.pose == "physgun" then
		self.viewOffset = Vector(-10, 4, -5)
	elseif self.pose == "sit" then
		self.viewOffset = Vector(-6, 0, 0)
	elseif self.pose == "drive" then
		self.viewOffset = Vector(-2, 0, -4)
	elseif self.pose == "pod" then
		self.viewOffset = Vector(-8, 0, -4)
	else
		self.viewOffset = Vector(0, 0, 0)
	end

	-- Set vehicle view angle
	self.vehicleAngle = (self.pose == "pod") and 0 or 90
end

function EnhancedCameraTwo:Think(maxSeqGroundSpeed)
	local modelChanged = false
	local poseChanged = false

	-- Handle model changes
	modelChanged = self:HasChanged("model", ApproximatePlayerModel()) or modelChanged
	modelChanged = self:HasTableChanged("bodyGroups", GetPlayerBodyGroups()) or modelChanged
	--modelChanged = self:HasTableChanged("materials", GetPlayerMaterials()) or modelChanged
	modelChanged = self:HasChanged("skin", LocalPlayer():GetSkin()) or modelChanged
	modelChanged = self:HasChanged("material", LocalPlayer():GetMaterial()) or modelChanged
	modelChanged = self:HasTableChanged("color", LocalPlayer():GetColor()) or modelChanged
	if not IsValid(self.entity) or modelChanged then
		poseChanged = true
		self:OnModelChange()
	end

	-- Set flexes to match
	-- Flexes will reset if not set on every frame
	for i = 0, LocalPlayer():GetFlexNum() - 1 do
		self.entity:SetFlexWeight(i, LocalPlayer():GetFlexWeight(i) )
	end

	-- Test if sequence changed
	if self:HasChanged("sequence", self:GetSequence()) then
		self:ResetSequence(self.sequence)
		if self:HasChanged("pose", self:GetPose()) then
			poseChanged = true
		end
	end

	-- Test if weapon changed
	if self:HasChanged("weapon", LocalPlayer():GetActiveWeapon()) then
		self.reloading = false
		poseChanged = true
	end

	-- Test if reload is finished
	if self.reloading then
		if IsValid(self.weapon) then
			local time = CurTime()
			if self.weapon:GetNextPrimaryFire() < time and self.weapon:GetNextSecondaryFire() < time then
				self.reloading = false
				poseChanged = true
			end
		else
			self.reloading = false
		end
	end

	-- Handle weapon changes
	if poseChanged then self:OnPoseChange() end

	-- Update the animation playback rate
	local velocity = LocalPlayer():GetVelocity():Length2D()

	local playbackRate = 1

	if velocity > 0.5 then
		if maxSeqGroundSpeed < 0.001 then
			playbackRate = 0.01
		else
			playbackRate = velocity / maxSeqGroundSpeed
			playbackRate = math.Clamp(playbackRate, 0.01, 10)
		end
	end

	self:SetPlaybackRate(playbackRate)

	self:FrameAdvance(CurTime() - self.lastTick)
	self.lastTick = CurTime()

	-- Pose remainder of model
	self:SetPoseParameter("breathing", LocalPlayer():GetPoseParameter("breathing"))
	self:SetPoseParameter("move_x", (LocalPlayer():GetPoseParameter("move_x") * 2) - 1)
	self:SetPoseParameter("move_y", (LocalPlayer():GetPoseParameter("move_y") * 2) - 1)
	self:SetPoseParameter("move_yaw", (LocalPlayer():GetPoseParameter("move_yaw") * 360) - 180)

	-- Pose vehicle steering
	if LocalPlayer():InVehicle() then
		self.entity:SetColor(color_transparent)
		self:SetPoseParameter("vehicle_steer", (LocalPlayer():GetVehicle():GetPoseParameter("vehicle_steer") * 2) - 1)
	end

	-- Update skeleton neck offset
	self.neckOffset = self.skelEntity:GetBonePosition(self.skelEntity.neck)
end

hook.Add("UpdateAnimation", "EnhancedCameraTwo:UpdateAnimation", function(ply, _, maxSeqGroundSpeed)
	if ply == LocalPlayer() then
		EnhancedCameraTwo:Think(maxSeqGroundSpeed)
	end
end)

-- On start of reload animation
hook.Add("DoAnimationEvent", "EnhancedCameraTwo:DoAnimationEvent", function(ply, event)
	if ply == LocalPlayer() and event == PLAYERANIMEVENT_RELOAD	then
		EnhancedCameraTwo.reloading = true
		EnhancedCameraTwo:OnPoseChange()
	end
end)

function EnhancedCameraTwo:Render()
	if self:ShouldDraw() then
		local renderColor = LocalPlayer():GetColor()
		local renderPos, renderAngle = self:GetRenderPosAngle()

		cam.Start3D(EyePos(), EyeAngles())
			render.SetColorModulation(renderColor.r / 255, renderColor.g / 255, renderColor.b / 255)
				render.SetBlend(renderColor.a / 255)
					self.entity:SetRenderOrigin(renderPos)
					self.entity:SetRenderAngles(renderAngle)
					self.entity:SetupBones()
					self.entity:DrawModel()
					self.entity:SetRenderOrigin()
					self.entity:SetRenderAngles()
				render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)
		cam.End3D()
	end
end

hook.Add("PreDrawEffects", "EnhancedCameraTwo:RenderScreenspaceEffects", function()
	EnhancedCameraTwo:Render()
end)

-- Lock yaw in vehicles
hook.Add("CreateMove", "EnhancedCameraTwo:CreateMove", function(ucmd)
	if EnhancedCameraTwo:ShouldDraw() and cvarVehicleYawLock:GetBool() and LocalPlayer():InVehicle() then
		ang = ucmd:GetViewAngles()
		max = cvarVehicleYawLockMax:GetInt()
		yaw = math.Clamp(math.NormalizeAngle(ang.y - EnhancedCameraTwo.vehicleAngle), -max, max) + EnhancedCameraTwo.vehicleAngle
		ucmd:SetViewAngles(Angle(ang.p, yaw, ang.r))
	end
end)

-- Console commands
concommand.Add("cl_ec2_toggle", function()
	if cvarEnabled:GetBool() then
		RunConsoleCommand("cl_ec2_enabled", "0")
	else
		RunConsoleCommand("cl_ec2_enabled", "1")
	end
end)

concommand.Add("cl_ec2_togglevehicle", function()
	if cvarVehicle:GetBool() then
		RunConsoleCommand("cl_ec2_vehicle", "0")
	else
		RunConsoleCommand("cl_ec2_vehicle", "1")
	end
end)

concommand.Add("cl_ec2_refresh", function()
	EnhancedCameraTwo:Refresh()
end)

cvars.AddChangeCallback("cl_ec2_showhair", function()
	EnhancedCameraTwo:Refresh()
end)

-- Options Menu
hook.Add("PopulateToolMenu", "EnhancedCameraTwo:PopulateToolMenu", function()
	spawnmenu.AddToolMenuOption("Options", "Player", "EnhancedCamera2", "Enhanced Camera 2", "", "", function(panel)

		panel:ClearControls()

		panel:Help("Welcome to the Enhanced Camera 2 settings.")

		panel:CheckBox("Show body", "cl_ec2_enabled")
		panel:ControlHelp("Show your body in first-person")

		panel:CheckBox("Show hair", "cl_ec2_showhair")
		panel:ControlHelp("Show your hair (bones attached to head) in first-person")

		panel:CheckBox("Show body in vehicles", "cl_ec2_vehicle")
		panel:ControlHelp("Show your body while in vehicles")

		panel:CheckBox("Restrict view in vehicles", "cl_ec2_vehicle_yawlock")
		panel:ControlHelp("Restrict yaw while in vehicles to prevent looking backwards at your neck. Yaw is not restricted regardless of this setting if either \"Show body\" or \"Show body in vehicles\" is disabled.")

		panel:NumSlider("Vehicle view restrict", "cl_ec2_vehicle_yawlock_max", 5, 180)
		panel:ControlHelp("Angle (in degrees) you can look away from the center view of a vehicle when \"Restrict view in vehicles\" is enabled.")

		panel:CheckBox("Static view height", "cl_ec2_staticheight")
		panel:ControlHelp("Statically adjust your view height to match your model.")

		local dyna = panel:ComboBox("Dynamic view height", "cl_ec2_dynamicheight")
		dyna:AddChoice("Disabled", 0)
		dyna:AddChoice("\"Real time\" mode", 1)
		dyna:AddChoice("\"Comfort\" mode", 2)
		panel:ControlHelp("Dynamically adjust your view height to match your model.")

		panel:Button("Reload model", "cl_ec2_refresh")
		panel:ControlHelp("Forces a model reload. May be useful if the first-person model doesn't update after changing your playermodel for some reason.")

	end)

	spawnmenu.AddToolMenuOption("Options", "Player", "EnhancedCamera2Server", "Enhanced Camera 2 Server", "", "", function(panel)

		panel:ClearControls()

		panel:Help("Welcome to the Enhanced Camera 2 server settings.")

		panel:CheckBox("Static view height", "sv_ec2_staticheight")
		panel:ControlHelp("Statically adjust players' view heights to match their models.")

		panel:CheckBox("Dynamic view height", "sv_ec2_dynamicheight")
		panel:ControlHelp("Dynamically adjust players' view heights to match their models")

		panel:NumSlider("Maximum view height", "sv_ec2_dynamicheight_max", 0, 100)
		panel:ControlHelp("Maximum View Height")

		panel:NumSlider("Minimum view height", "sv_ec2_dynamicheight_min", 0, 100)
		panel:ControlHelp("Minimum view height")

	end)
end)

concommand.Add("ec2_debug_print_hooks_cl", function()
	print("DoAnimationEvent\n")
	PrintTable(hook.GetTable().DoAnimationEvent)
	print()
	print()
	print("PreDrawEffects\n")
	PrintTable(hook.GetTable().PreDrawEffects)
	print()
	print()
	print("CreateMove\n")
	PrintTable(hook.GetTable().CreateMove)
end)
