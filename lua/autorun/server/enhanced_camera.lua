AddCSLuaFile("client/enhanced_camera.lua")

local function UpdateTrueModel(ply)
  if ply:GetNWString("EnhancedCamera:TrueModel") ~= ply:GetModel() then
    ply:SetNWString("EnhancedCamera:TrueModel", ply:GetModel())
  end
end

hook.Add("PlayerSpawn", "EnhancedCamera:PlayerSpawn", function(ply)
  UpdateTrueModel(ply)
end)

hook.Add("PlayerTick", "EnhancedCamera:PlayerTick", function(ply)
  UpdateTrueModel(ply)
end)
