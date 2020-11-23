AddCSLuaFile()

timer.Simple(0, function()

	--Fix for https://steamcommunity.com/sharedfiles/filedetails/?id=1187366110
	hook.Remove("PlayerSpawn", "Mae_Viewheight_Offeset")

end)
