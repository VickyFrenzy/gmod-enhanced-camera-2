# Garry's Mod: Enhanced Camera 2

[![Steam Update Date](https://img.shields.io/steam/update-date/2203217139?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2203217139)
[![Steam Views](https://img.shields.io/steam/views/2203217139?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2203217139)
[![Steam Subscriptions](https://img.shields.io/steam/subscriptions/2203217139?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2203217139)
[![Steam Downloads](https://img.shields.io/steam/downloads/2203217139?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2203217139)
[![Steam Favorites](https://img.shields.io/steam/favorites/2203217139?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2203217139)
[![Steam File Size](https://img.shields.io/steam/size/2203217139?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2203217139)

## What is it?

The original [Enhanced Camera](https://github.com/elizagamedev/gmod-enhanced-camera) was not maintained anymore and had a lot of issues. So here is **Enhanced Camera 2**, the Lua error free and improved version of the [Enhanced Camera](https://github.com/elizagamedev/gmod-enhanced-camera).

Enhanced Camera, based off the Oblivion/Skyrim/Fallout mods of the same name, is an addon for Garry's Mod that allows players to see their own bodies.

## What this addon can and cannot do

Enhanced Camera *can*:

* Dynamically change the player's height to match their model

Enhanced Camera *can not*:

* Work 100% of the time if models have broken paths, though it works most of the time
* Show your PAC3 customizations
* Show your shadow (you can use `cl_drawownshadow` if you want, but it won't match your first person body or show your weapon's shadow)

## Console Commands and cvars

_All of these options can be configured in the Options tab._

### Client-side

* `cl_ec2_enabled`
  * `1` (Default): Show your body in first-person
  * `0`: Hide your body in first-person
* `cl_ec2_showhair`
  * `1` (Default): Show your hair (bones attached to head) in first-person
  * `0`: Hide your hair in first-person
* `cl_ec2_hide_left_arm`
  * `0` (Default): Your left arm will be present according to the context
  * `1`: Always hide your left arm
* `cl_ec2_hide_right_arm`
  * `0` (Default): Your right arm will be present according to the context
  * `1`: Always hide your right arm
* `cl_ec2_vehicle`
  * `1` (Default): Show your body while in vehicles
  * `0`: Hide your body while in vehicles
* `cl_ec2_vehicle_yawlock`
  * `1` (Default): Restrict yaw while in vehicles to prevent looking backwards at your neck. Yaw is not restricted regardless of this setting if either `cl_ec2_enabled` or `cl_ec2_vehicle` is `0`.
  * `0`: Unrestrict yaw while in vehicles
* `cl_ec2_vehicle_yawlock_max` (Default: `65`): Angle (in degrees) you can look away from the center view of a vehicle when `cl_ec2_vehicle_yawlock` is enabled.
* `cl_ec2_refresh` Forces a model reload. May be useful if the first-person model doesn't update after changing your playermodel for some reason.
* `cl_ec2_toggle` Toggles the visibility of your body in first-person
* `cl_ec2_togglevehicle` Toggles the visibility of your body in first-person while in vehicles
* `cl_ec2_staticheight` Statically adjust your view height to match your model
  * `0`: Disabled
  * `1` (Default): Enabled
* `cl_ec2_dynamicheight` Dynamically adjust your view height to match your model
  * `0`: Disabled
  * `1` (Default): "Real time" mode
  * `2`: "Comfort" mode

### Server-side

* `sv_ec2_staticheight`
  * `1` (Default): Statically adjust players' view heights to match their models
  * `0`: Don't touch players' heights
* `sv_ec2_dynamicheight`
  * `1` (Default): Dynamically adjust players' view heights to match their models
  * `0`: Don't touch players' heights
* `sv_ec2_dynamicheight_min`
  * (Default: `16`): Minimum view height
* `sv_ec2_dynamicheight_max`
  * (Default: `64`): Maximum view height
