AddCSLuaFile()

if CLIENT then

	include("enhanced_camera_2/client.lua")

elseif SERVER then

	include("enhanced_camera_2/server.lua")

end
