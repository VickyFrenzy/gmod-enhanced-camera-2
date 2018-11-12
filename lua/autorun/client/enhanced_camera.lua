local cvarEnabled = CreateClientConVar("cl_ec_enabled", "1")
local cvarHair = CreateClientConVar("cl_ec_showhair", "1")
local cvarVehicle = CreateClientConVar("cl_ec_vehicle", "1")
local cvarVehicleYawLock = CreateClientConVar("cl_ec_vehicle_yawlock", "1")
local cvarVehicleYawLockMax = CreateClientConVar("cl_ec_vehicle_yawlock_max", "65")

EnhancedCamera = EnhancedCamera or {
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

-- PUBLIC API
function EnhancedCamera:SetLimbHidden(limb, hidden)
  -- `limb` may be "l_arm", "r_arm", "l_leg", or "r_leg"
  -- `hidden` is a bool describing the desired visibility
  -- Limbs hidden because of pose will not be visible regardless of this setting.
  self.apiBoneHide[limb] = hidden and true or nil
  self:Refresh()
end

-- Global functions
local function ApproximatePlayerModel()
  -- Return a value suitable for detecting model changes
  return LocalPlayer():GetNWString("EnhancedCamera:TrueModel", LocalPlayer():GetModel())
end

local function GetPlayerBodyGroups()
  local bodygroups = {}
  for k, v in pairs(LocalPlayer():GetBodyGroups()) do
    bodygroups[v.id] = LocalPlayer():GetBodygroup(v.id)
  end
  return bodygroups
end

local function GetPlayerMaterials()
  local materials = {}
  for k, v in pairs(LocalPlayer():GetMaterials()) do
    materials[k - 1] = LocalPlayer():GetSubMaterial(k - 1)
  end
  return materials
end

-- Body entity functions
function EnhancedCamera:SetModel(model)
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

  self.ragdollSequence = self.entity:LookupSequence("ragdoll")
  self.idleSequence = self.entity:LookupSequence("idle_all_01")
end

function EnhancedCamera:ResetSequence(seq)
  self.entity:ResetSequence(seq)
  self.skelEntity:ResetSequence(seq)
end

function EnhancedCamera:SetPlaybackRate(fSpeed)
  self.entity:SetPlaybackRate(fSpeed)
  self.skelEntity:SetPlaybackRate(fSpeed)
end

function EnhancedCamera:FrameAdvance(delta)
  self.entity:FrameAdvance(delta)
  self.skelEntity:FrameAdvance(delta)
end

function EnhancedCamera:SetPoseParameter(poseName, poseValue)
  self.entity:SetPoseParameter(poseName, poseValue)
  self.skelEntity:SetPoseParameter(poseName, poseValue)
end

-- Body utility functions
function EnhancedCamera:HasChanged(key, newvalue)
  if self[key] ~= newvalue then
    self[key] = newvalue
    return true
  end
  return false
end

function EnhancedCamera:HasTableChanged(key, newtable)
  local tbl = self[key]
  if tbl == newtable then
    return false
  end
  if tbl == nil or newtable == nil then
    self[key] = newtable
    return true
  end
  if table.getn(tbl) ~= table.getn(newtable) then
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

function EnhancedCamera:Refresh()
  self.model = nil
  self.sequence = nil
  self.pose = nil
end

-- Body state functions
function EnhancedCamera:ShouldDraw()
  return cvarEnabled:GetBool() and
    (not LocalPlayer():InVehicle() or cvarVehicle:GetBool()) and
    IsValid(self.entity) and
    IsValid(self.skelEntity) and
    LocalPlayer():Alive() and
    GetViewEntity() == LocalPlayer() and
    not LocalPlayer():ShouldDrawLocalPlayer() and
    LocalPlayer():GetObserverMode() == 0
end

function EnhancedCamera:GetPose()
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
  local pose = string.sub(seqname, string.find(seqname, "_") + 1)
  pose = (wep and wep.DefaultHoldType) or pose
  if string.find(pose, "all") then
    return "normal"
  elseif pose == "smg1" then
    return "smg"
  end
  return pose
end

function EnhancedCamera:GetModel()
  -- Try to find the actual player model based on the often vague guess given
  -- by GetModel()
  name = self.model
  if util.IsValidModel(name) then return name end

  -- Search for a matching model name in the list of valid models
  local basename = string.GetFileFromFilename(name)
  for _, name in pairs(player_manager.AllValidModels()) do
    if string.GetFileFromFilename(name) == basename then
      return name
    end
  end

  return "models/player/kleiner.mdl"
end

function EnhancedCamera:GetSequence()
  local sequence = LocalPlayer():GetSequence()
  if sequence == self.ragdollSequence then
    return self.idleSequence
  end
  return sequence
end

function EnhancedCamera:GetRenderPosAngle()
  local renderPos = EyePos()
  local renderAngle = nil

  if LocalPlayer():InVehicle() then
    renderAngle = LocalPlayer():GetVehicle():GetAngles()
    renderAngle:RotateAroundAxis(renderAngle:Up(), self.vehicleAngle)
  else
    renderAngle = Angle(0, LocalPlayer():EyeAngles().y, 0)
  end

  local offset = self.viewOffset - self.neckOffset
  offset:Rotate(renderAngle)
  -- Adjust offset for crouching
  if LocalPlayer():GetGroundEntity() ~= NULL and LocalPlayer():Crouching() then
    offset.z = offset.z + 21
  end
  renderPos = renderPos + offset
  return renderPos, renderAngle
end

-- Set up the body model to match the player model
function EnhancedCamera:OnModelChange()
  self:SetModel(self:GetModel())

  for k, v in pairs(self.bodyGroups) do
    self.entity:SetBodygroup(k, v)
  end

  if self:HasTableChanged('materials', GetPlayerMaterials()) then
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
  },
  right = {
    weapon_bugbait = true,
  },
}

-- Hide limbs as appropriate for the current hold type and record the hold
-- type for use elsewhere
function EnhancedCamera:OnPoseChange()
  for i = 0, self.entity:GetBoneCount() do
    self.entity:ManipulateBoneScale(i, Vector(1, 1, 1))
    self.entity:ManipulateBonePosition(i, vector_origin)
  end

  -- Hide appropriate limbs
  local wep = LocalPlayer():GetActiveWeapon()
  local name = IsValid(wep) and wep:GetClass() or ""
  local bone = self.entity:LookupBone("ValveBiped.Bip01_Head1")
  self.entity:ManipulateBoneScale(bone, vector_origin)
  if not cvarHair:GetBool() then
    self.entity:ManipulateBonePosition(bone, Vector(-128, 128, 0))
  end
  if self.apiBoneHide['l_arm'] or self.reloading or not (
      (POSE_SHOW_ARM.left[self.pose] or
       NAME_SHOW_ARM.left[name]) and not
       NAME_HIDE_ARM.left[name]) then
    bone = self.entity:LookupBone("ValveBiped.Bip01_L_Upperarm")
    self.entity:ManipulateBoneScale(bone, vector_origin)
    self.entity:ManipulateBonePosition(bone, Vector(0, 0, -128))
  end
  if self.apiBoneHide['r_arm'] or self.reloading or not (
      (POSE_SHOW_ARM.right[self.pose] or
       NAME_SHOW_ARM.right[name]) and not
       NAME_HIDE_ARM.right[name]) then
    bone = self.entity:LookupBone("ValveBiped.Bip01_R_Upperarm")
    self.entity:ManipulateBoneScale(bone, vector_origin)
    self.entity:ManipulateBonePosition(bone, Vector(0, 0, 128))
  end
  if self.apiBoneHide['l_leg'] then
    bone = self.entity:LookupBone("ValveBiped.Bip01_L_Thigh")
    self.entity:ManipulateBoneScale(bone, vector_origin)
    self.entity:ManipulateBonePosition(bone, Vector(0, 0, -128))
  end
  if self.apiBoneHide['r_leg'] then
    bone = self.entity:LookupBone("ValveBiped.Bip01_R_Thigh")
    self.entity:ManipulateBoneScale(bone, vector_origin)
    self.entity:ManipulateBonePosition(bone, Vector(0, 0, -128))
  end

  -- Set pose-specific view offset
  if self.pose == "normal" or self.pose == "camera" or self.pose == "fist" or
      self.pose == "dual" or self.pose == "passive" or self.pose == "magic" then
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

function EnhancedCamera:Think(maxSeqGroundSpeed)
  local modelChanged = false
  local poseChanged = false

  -- Handle model changes
  modelChanged = self:HasChanged('model', ApproximatePlayerModel()) or modelChanged
  modelChanged = self:HasTableChanged('bodyGroups', GetPlayerBodyGroups()) or modelChanged
  --modelChanged = self:HasTableChanged('materials', GetPlayerMaterials()) or modelChanged
  modelChanged = self:HasChanged('skin', LocalPlayer():GetSkin()) or modelChanged
  modelChanged = self:HasChanged('material', LocalPlayer():GetMaterial()) or modelChanged
  modelChanged = self:HasTableChanged('color', LocalPlayer():GetColor()) or modelChanged
  if not IsValid(self.entity) or modelChanged then
    poseChanged = true
    self:OnModelChange()
  end
  
  -- Set flexes to match
  -- Flexes will reset if not set on every frame
  for i = 0, LocalPlayer():GetFlexNum()-1 do
    self.entity:SetFlexWeight(i, LocalPlayer():GetFlexWeight(i) )
  end

  -- Test if sequence changed
  if self:HasChanged('sequence', self:GetSequence()) then
    self:ResetSequence(self.sequence)
    if self:HasChanged('pose', self:GetPose()) then
      poseChanged = true
    end
  end

  -- Test if weapon changed
  if self:HasChanged('weapon', LocalPlayer():GetActiveWeapon()) then
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
  self.neckOffset = self.skelEntity:GetBonePosition(self.skelEntity:LookupBone("ValveBiped.Bip01_Neck1"))
end

hook.Add("UpdateAnimation", "EnhancedCamera:UpdateAnimation", function(ply, velocity, maxSeqGroundSpeed)
  if ply == LocalPlayer() then
    EnhancedCamera:Think(maxSeqGroundSpeed)
  end
end)

-- On start of reload animation
hook.Add("DoAnimationEvent", "EnhancedCamera:DoAnimationEvent", function(ply, event, data)
  if ply == LocalPlayer() and event == PLAYERANIMEVENT_RELOAD  then
    EnhancedCamera.reloading = true
    EnhancedCamera:OnPoseChange()
  end
end)

function EnhancedCamera:Render()
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

hook.Add("PreDrawEffects", "EnhancedCamera:RenderScreenspaceEffects", function()
  EnhancedCamera:Render()
end)

-- Lock yaw in vehicles
hook.Add("CreateMove", "EnhancedCamera:CreateMove", function(ucmd)
  if EnhancedCamera:ShouldDraw() and cvarVehicleYawLock:GetBool() and LocalPlayer():InVehicle() then
    ang = ucmd:GetViewAngles()
    max = cvarVehicleYawLockMax:GetInt()
    yaw = math.Clamp(math.NormalizeAngle(ang.y - EnhancedCamera.vehicleAngle), -max, max) + EnhancedCamera.vehicleAngle
    ucmd:SetViewAngles(Angle(ang.p, yaw, ang.r))
  end
end)

-- Console commands
concommand.Add("cl_ec_toggle", function()
  if cvarEnabled:GetBool() then
    RunConsoleCommand("cl_ec_enabled", "0")
  else
    RunConsoleCommand("cl_ec_enabled", "1")
  end
end)

concommand.Add("cl_ec_togglevehicle", function()
  if cvarVehicle:GetBool() then
    RunConsoleCommand("cl_ec_vehicle", "0")
  else
    RunConsoleCommand("cl_ec_vehicle", "1")
  end
end)

concommand.Add("cl_ec_refresh", function()
  EnhancedCamera:Refresh()
end)

cvars.AddChangeCallback("cl_ec_showhair", function(name, oldVal, newVal)
  EnhancedCamera:Refresh()
end)

-- Options Menu
hook.Add("PopulateToolMenu", "EnhancedCamera:PopulateToolMenu", function()
  spawnmenu.AddToolMenuOption("Options", "Enhanced Camera", "EnhancedCamera", "Options", "", "", function(panel)
    panel:AddControl("CheckBox", {
      Label = "Show body",
      Command = "cl_ec_enabled",
    })

    panel:AddControl("CheckBox", {
      Label = "Show hair",
      Command = "cl_ec_showhair",
    })

    panel:AddControl("CheckBox", {
      Label = "Show body in vehicles",
      Command = "cl_ec_vehicle",
    })

    panel:AddControl("CheckBox", {
      Label = "Restrict view in vehicles",
      Command = "cl_ec_vehicle_yawlock",
    })

    panel:AddControl("Slider", {
      Label = "Vehicle view restrict amount",
      Command = "cl_ec_vehicle_yawlock_max",
      Min = 5,
      Max = 180,
    })
  end)
end)
