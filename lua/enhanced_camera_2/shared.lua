AddCSLuaFile()

EnhancedCameraTwo = EnhancedCameraTwo or {}

local bone_list = {
	"ValveBiped.Bip01_Neck1",
}

function EnhancedCameraTwo:GetBone(ent)
	local bone = 0
	for _, v in ipairs(bone_list) do
		bone = ent:LookupBone(v) or 0
		if bone > 0 then
			ent._ec2_headbone = bone
			return bone
		end
	end
	return bone
end

function EnhancedCameraTwo:_debug_list_bones(ent)
	local bones = ent:GetBoneCount()
	local i = 0
	while i < bones do
		print(ent:GetBoneName(i))
		i = i + 1
	end
end

timer.Simple(0, function()

	--Fix for https://steamcommunity.com/sharedfiles/filedetails/?id=1187366110
	hook.Remove("PlayerSpawn", "Mae_Viewheight_Offeset")

end)
