local cvarEnabled = CreateClientConVar("cl_ec_enabled", "1")
local cvarVehicle = CreateClientConVar("cl_ec_vehicle", "1")
local cvarVehicleYawLock = CreateClientConVar("cl_ec_vehicle_yawlock", "1")
local cvarVehicleYawLockMax = CreateClientConVar("cl_ec_vehicle_yawlock_max", "65")

-- Render the body
local body = {
  entity = nil,
  skelEntity = nil,
  lastTick = 0,
  model = nil,
  pose = "",
  weapon = nil,
  sequence = nil,
  viewOffset = Vector(0, 0, 0),
  neckOffset = Vector(0, 0, 0),
  vehicleAngle = 0,
}

-- Global functions
local function GetPose()
  -- Weapon:Getpose() is very unreliable at the time of writing.
  local seqname = LocalPlayer():GetSequenceName(LocalPlayer():GetSequence())
  if string.StartWith(seqname, "sit") then
    return "sit"
  elseif seqname == "drive_pd" then
    return "pod"
  elseif string.StartWith(seqname, "drive") then
    return "drive"
  end
  local pose = string.sub(seqname, string.find(seqname, "_") + 1)
  if string.find(pose, "all") then
    return "normal"
  elseif pose == "smg1" then
    return "smg"
  end
  return pose
end

local function ApproximatePlayerModel()
  -- Return a value suitable for detecting model changes
  return LocalPlayer():GetNWString("EnhancedCamera:TrueModel", LocalPlayer():GetModel())
end

local function GetPlayerModel()
  -- Try to find the actual player model based on the often vague guess given
  -- by GetModel()
  name = body.model
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

local function ShouldDrawBody()
  return cvarEnabled:GetBool() and
    (not LocalPlayer():InVehicle() or cvarVehicle:GetBool()) and
    IsValid(body.entity) and
    IsValid(body.skelEntity) and
    LocalPlayer():Alive() and
    GetViewEntity() == LocalPlayer() and
    not LocalPlayer():ShouldDrawLocalPlayer() and
    not LocalPlayer():GetObserverTarget()
end

-- Body entity functions
function body:SetModel(model)
  if not IsValid(self.entity) then
    self.entity = ClientsideModel(model, RENDERGROUP_VIEWMODEL)
  else
    self.entity:SetModel(model)
  end
  if not IsValid(self.skelEntity) then
    self.skelEntity = ClientsideModel(model, RENDERGROUP_OPAQUE)
  else
    self.skelEntity:SetModel(model)
  end
  self.entity:SetNoDraw(true)
  self.skelEntity:SetNoDraw(true)
end

function body:ResetSequence(seq)
  self.entity:ResetSequence(seq)
  self.skelEntity:ResetSequence(seq)
end

function body:SetPlaybackRate(fSpeed)
  self.entity:SetPlaybackRate(fSpeed)
  self.skelEntity:SetPlaybackRate(fSpeed)
end

function body:FrameAdvance(delta)
  self.entity:FrameAdvance(delta)
  self.skelEntity:FrameAdvance(delta)
end

function body:SetPoseParameter(poseName, poseValue)
  self.entity:SetPoseParameter(poseName, poseValue)
  self.skelEntity:SetPoseParameter(poseName, poseValue)
end

-- Set up the body model to match the player model
function body:OnModelChange()
  self:SetModel(GetPlayerModel())

  for k, v in pairs(LocalPlayer():GetBodyGroups()) do
    self.entity:SetBodygroup(v.id, LocalPlayer():GetBodygroup(v.id))
  end

  for k, v in ipairs(LocalPlayer():GetMaterials()) do
    self.entity:SetSubMaterial(k - 1, LocalPlayer():GetSubMaterial(k - 1))
  end

  self.entity:SetSkin(LocalPlayer():GetSkin())
  self.entity:SetMaterial(LocalPlayer():GetMaterial())
  self.entity:SetColor(LocalPlayer():GetColor())
  self.entity.GetPlayerColor = function()
    return LocalPlayer():GetPlayerColor()
  end

  -- Update new pose
  self.lastTick = 0
  self:OnPoseChange()
end

local pose_SHOW_ARM = {
  left = {
    normal = true,
    sit = true,
    drive = true,
    pod = true,

    melee = true,
    knife = true,
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
    weapon_pistol = true,
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
function body:OnPoseChange()
  for i = 0, self.entity:GetBoneCount() do
    self.entity:ManipulateBoneScale(i, Vector(1, 1, 1))
    self.entity:ManipulateBonePosition(i, vector_origin)
  end

  -- Hide appropriate limbs
  local wep = LocalPlayer():GetActiveWeapon()
  local name = IsValid(wep) and wep:GetClass() or ""
  local bone = self.entity:LookupBone("ValveBiped.Bip01_Head1")
  self.entity:ManipulateBoneScale(bone, vector_origin)
  self.entity:ManipulateBonePosition(bone, Vector(-128, 128, 0))
  if self.reloading or not (
      (pose_SHOW_ARM.left[self.pose] or
       NAME_SHOW_ARM.left[name]) and not
      NAME_HIDE_ARM.left[name]) then
    bone = self.entity:LookupBone("ValveBiped.Bip01_L_Upperarm")
    self.entity:ManipulateBoneScale(bone, vector_origin)
    self.entity:ManipulateBonePosition(bone, Vector(0, 0, -128))
  end
  if self.reloading or not (
      (pose_SHOW_ARM.right[self.pose] or
       NAME_SHOW_ARM.right[name]) and not
      NAME_HIDE_ARM.right[name]) then
    bone = self.entity:LookupBone("ValveBiped.Bip01_R_Upperarm")
    self.entity:ManipulateBoneScale(bone, vector_origin)
    self.entity:ManipulateBonePosition(bone, Vector(0, 0, 128))
  end

  -- Set pose-specific view offset
  if self.pose == "normal" or self.pose == "camera" or self.pose == "fist" or
      self.pose == "dual" or self.pose == "passive" or self.pose == "magic" then
    self.viewOffset = Vector(-8, 0, -5)
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

function body:Think(maxSeqGroundSpeed)
  -- Handle model changes
  local model = ApproximatePlayerModel()
  if not IsValid(self.entity) or model ~= body.model then
    body.model = model
    body:OnModelChange()
  end

  local poseChanged = false

  -- Test if pose/sequence changed
  local sequence = LocalPlayer():GetSequence()
  if self.sequence ~= sequence then
    self.sequence = sequence
    self:ResetSequence(sequence)
    local pose = GetPose()
    if self.pose ~= pose then
      self.pose = pose
      poseChanged = true
    end
  end

  -- Test if weapon changed
  local weapon = LocalPlayer():GetActiveWeapon()
  if self.weapon ~= weapon then
    self.weapon = weapon
    self.reloading = false
    poseChanged = true
  end

  -- Test if reload is finished
  if self.reloading then
    if IsValid(weapon) then
      local time = CurTime()
      if weapon:GetNextPrimaryFire() < time and weapon:GetNextSecondaryFire() < time then
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
  self:SetPoseParameter("body_yaw", (LocalPlayer():GetPoseParameter("body_yaw") * 180) - 90)
  self:SetPoseParameter("spine_yaw", (LocalPlayer():GetPoseParameter("spine_yaw") * 180) - 90)

  -- Pose vehicle steering
  if LocalPlayer():InVehicle() then
    self.entity:SetColor(color_transparent)
    self:SetPoseParameter("vehicle_steer", (LocalPlayer():GetVehicle():GetPoseParameter("vehicle_steer") * 2) - 1)
  end

  -- Update skeleton neck offset
  self.skelEntity:SetAngles(Angle(0, 0, 0))
  body.neckOffset = self.skelEntity:GetBonePosition(self.skelEntity:LookupBone("ValveBiped.Bip01_Neck1"))
end

hook.Add("UpdateAnimation", "EnhancedCamera:UpdateAnimation", function(ply, velocity, maxSeqGroundSpeed)
  if ply == LocalPlayer() then
    body:Think(maxSeqGroundSpeed)
  end
end)

-- On start of reload animation
hook.Add("DoAnimationEvent", "EnhancedCamera:DoAnimationEvent", function(ply, event, data)
  if ply == LocalPlayer() and event == PLAYERANIMEVENT_RELOAD  then
    body.reloading = true
    body:OnPoseChange()
  end
end)

function body:Render()
  if ShouldDrawBody() then
    cam.Start3D(EyePos(), EyeAngles())
      local renderColor = LocalPlayer():GetColor()
      local renderPos = EyePos()
      local renderAngle = nil
      local clipVector = vector_up * -1

      if LocalPlayer():InVehicle() then
        renderAngle = LocalPlayer():GetVehicle():GetAngles()
        renderAngle:RotateAroundAxis(renderAngle:Up(), self.vehicleAngle)
      else
        renderAngle = Angle(0, LocalPlayer():EyeAngles().y, 0)
      end

      local offset = self.viewOffset - self.neckOffset
      offset:Rotate(renderAngle)
      renderPos = renderPos + offset

      local enabled = render.EnableClipping(true)
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
      render.EnableClipping(enabled)
    cam.End3D()
  end
end

hook.Add("RenderScreenspaceEffects", "EnhancedCamera:RenderScreenspaceEffects", function()
  body:Render()
end)

-- Lock yaw in vehicles
hook.Add("CreateMove", "EnhancedCamera:CreateMove", function(ucmd)
  if ShouldDrawBody() and cvarVehicleYawLock:GetBool() and LocalPlayer():InVehicle() then
    ang = ucmd:GetViewAngles()
    max = cvarVehicleYawLockMax:GetInt()
    yaw = math.Clamp(math.NormalizeAngle(ang.y - body.vehicleAngle), -max, max) + body.vehicleAngle
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
  Legs:OnModelChange()
end)

-- Options Menu
hook.Add("PopulateToolMenu", "EnhancedCamera:PopulateToolMenu", function()
  spawnmenu.AddToolMenuOption("Options", "Enhanced Camera", "EnhancedCamera", "Options", "", "", function(panel)
    panel:AddControl("CheckBox", {
      Label = "Show body",
      Command = "cl_ec_enabled",
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
