Garry's Mod: Enhanced Camera
============================

* [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=678037029)
* [GitHub](https://github.com/mathewv/gmod-enhanced-camera)

What is it?
-----------

Enhanced Camera, based off the Oblivion/Skyrim/Fallout mods of the same name, is an addon for Garry's Mod that allows players to see their own bodies. The source code was originally based on [Gmod Legs 3](https://steamcommunity.com/sharedfiles/filedetails/?id=112806637), but has been modified so extensively and the two now have little in common besides a similar goal. It can be considered in a beta state.

Why not Gmod Legs/Immersive First-Person?
-----------------------------------------

Gmod Legs, as the title suggests, only shows the player's legs. It also requires a server-side component to work properly. [Immersive First-Person](https://steamcommunity.com/sharedfiles/filedetails/?id=133042891) is entirely client-side, but doesn't use viewmodels, modifies the camera origin (and thus breaks aiming), and either requires a strict camera pitch restriction or suffers a lot of clipping. Enhanced Camera, like the Oblivion/Skyrim/Fallout mods of the same name, combines the viewmodel and worldmodel and does not modify the camera origin.

What this addon can and cannot do
---------------------------------

Enhanced Camera *can*:

* Work entirely on the client-side, even on servers without the addon installed, as long as `sv_allowcslua` is enabled
* Be added to servers and distributed to clients automatically (potentially useful for RP servers, etc)

Enhanced Camera *can not*:

* Change the player's actual view height or view offset
* Work 100% of the time if models have broken paths unless the optional serverside component is installed, though it works most of the time
* Show your PAC3 customizations (yet!)

Known Issues
------------

* Legs usually clip into the ground while crouching

Console Commands and cvars
--------------------------

All of these options can be configured in the Tools menu, Options tab.

* `cl_ec_enabled`
    * `1` (Default): Show your body in first-person
    * `0`: Hide your body in first-person
* `cl_ec_vehicle`
    * `1` (Default): Show your body while in vehicles
    * `0`: Hide your body while in vehicles
* `cl_ec_vehicle_yawlock`
    * `1` (Default): Restrict yaw while in vehicles to prevent looking backwards at your neck. Yaw is not restricted regardless of this setting if either `cl_ec_enabled` or `cl_ec_vehicle` is `0`.
    * `0`: Unrestrict yaw while in vehicles
* `cl_ec_vehicle_yawlock_max`
    * (Default: `65`): Angle (in degrees) you can look away from the center view of a vehicle when `cl_ec_vehicle_yawlock` is enabled.
* `cl_ec_refresh`
    * Forces a model reload. May be useful if the first-person model doesn't update after changing your playermodel for some reason.
* `cl_ec_toggle`
    * Toggles the visibility of your body in first-person
* `cl_ec_togglevehicle`
    * Toggles the visibility of your body in first-person while in vehicles
