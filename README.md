# Switchboard -- Re-imagined Virtual Switches for Vera Home Automation

![Switchboard](https://www.toggledbits.com/assets/switchboard/switchboard-default.png) 
This plugin is my take on a modernized *Virtual Switch* plugin for Vera. The long-lived (near zombie) Virtual Switch plugin
has some subtle issues that make it difficult to use with some third party applications (including Google Home and Amazon Echo devices), and even Vera's own native mobile app for Android.
Hopefully, this version of virtual switches will address those shortcomings.

NOTE: This plugin does not yet support openLuup. The things that make it work better on Vera than VSwitch are the things that are troubling to openLuup. I will make an effort to reconcile these at some point, but for the moment, this plugin is only supported on Vera UI7 and higher.

## Installing on Vera

Vera users can install Switchboard by searching for it under *Apps > Install apps*.

Alternately, users may request the following URL in a browser, substituting your Vera's local IP where indicated:

```
http://vera-local-ip/port_3480/data_request?id=action&action=CreatePlugin&PluginNum=9194&serviceId=urn:micasaverde-com:serviceId:HomeAutomationGateway1
```

## Installing on openLuup

**NOTE:** Version 2018.11.21 of openLuup, or higher, is required to run Switchboard.

Installation of Switchboard is best done from the AltAppStore. Find it. Click it.

If you are running an openLuup dated earlier than 2019.06.02, and you do not wish to upgrade to at least
that version, you will also need to install the supplemental device files. Download file files from
https://github.com/toggledbits/Switchboard-Vera/tree/master/openLuup
and then place them in your openLuup install directory with the Switchboard plugin files.

## Creating Virtual Switches/Devices

To create virtual switches, go into the "Switchboard" device control panel, and hit the "Add One" button to create one new virtual switch, or "Add Five" to create them five at a time. Each click requires processing and Luup reload, so do this slowly if you have a large number of switches to create.

Once the new device has been created and Switchboard reports the number of devices now running, do a hard-refresh of your browser as described in the last install step above.

**NOTE:** Do not create additional instances of the Switchboard master device. The system should have one and only one Switchboard device. Virtual switches are created only from the Switchboard control panel buttons as described above.

## Switchboard Virtual Switch Features

Switchboard's virtual switches use entirely Vera-native device types and service definitions, and this is what makes them work better than the old Virtual Switch devices (which had a custom device type that Vera really didn't recognize everywhere).

Switchboard's virtual switches can be hidden using the "command and control" interface in the "Status" tab of the Switchboard control panel. Here you will see all of your virtual switches in one place, and be able to control them all, and set options.

Currently, there are only two options: visibility, and self-reset. The visibility option allows you to hide virtual switches, so if you have a large number of them, you can easily get them off your UI7 device list without having to tuck them into a virtual room, etc. The self-reset option creates an "pulse" switch--a switch that provides an "on" pulse and then automatically turns itself off. You can control the length of the pulse for each switch independently; a pulse length of zero means the switch doesn't use pulse timing.

NOTE: Turning "on" a pulse switch that is already on does not extend pulse timing.

NOTE: When a switch is hidden, it will also not be visible in Vera's scene trigger menus and other places in the UI, so if you're trying to create a new scene using a hidden virtual switch, you will first need to go into the Switchboard status panel and un-hide the switch. You can re-hide it after; that doesn't affect the scene's ability to *use* the switch.

## Virtual Window Coverings

It may seem odd to have virtual window coverings, but in Vera, the window covering implementation uses the `Dimming1` service to set the opening (e.g. 0% is closed, and 50% is half open, and 100% is fully open). Calling `SetLoadLevelTarget` as one would for a dimmer controls the shade opening. The `SwitchPower` action `SetTarget` can also be used to quickly fully-open or fully-close the covering.

By default, Switchboard will simulate motor movement of the covering by ramping `LoadLevelStatus` at a rate of 5% per second to the target value. If your application requires a different rate, it can be set by setting `RampRatePerSecond` (as percent per second). Setting it to 0 disables ramp and causes the covering to go immediately to the requested target value.

## Legacy Virtual Switch Features

To maintain compatibility with the older Virtual Switch plugin's switches, Switchboard's switches implement the services and behaviors of the older plugin, in addition to the standard Vera binary switch behaviors.

The old Virtual Switch plugin supported two text fields for each switch. These have made their way into Switchboard's switches as well, for compatibility. However, because the Vera-native UI is used for Switchboard's virtual switches, there is no way to display them in the native Vera switch UI. They are visible and editable in the Switchboard "Status" tab, however.

If you have existing virtual switches from the old "Virtual Switch" plugin, you can "adopt" those switches and make them Switchboard devices, which then allows you to uninstall the old "Virtual Switch" plugin. The device numbers will stay the same, so no changes to scenes, Lua, Reactor, PLEG, etc. should be needed.

## Virtual Scene Controllers

Switchboard allows you to create virtual scene controllers. This gives you a multi-button UI on a single device that allows you to trigger scenes or Reactor/PLEG rules, etc. I use this for establishing "modes" that are unrelated to house modes--sometimes you want/need more than the standard Vera house mode delivers. For example, I now use a virtual scene controller to set and track if my home theater is in "Setup", "Roll Previews", "Roll Show", "Pause" or "Off" mode and make changes when transitioning between. Over my whole house, I use a virtual scene controller to let my other Reactors know if it is currently "Morning", "Day", "Evening" or "Night".

The virtual scene controllers (VSCs) can have any number of buttons, although 24 seems to be a practical limit for the UI, so that's the UI limit (you can still create more, only the first 24 are shown on the dashboard card). You determine the number of buttons a VSC can have by providing a comma-separated list of button labels in the VSC's control panel UI. Changing the labels, unfortunately, requires a Luup reload, and you must do a hard-refresh of your browser, for proper display. 

When a VSC is in *single state* mode, only one button can be "down" at a time--only one "mode" can be active at a time. When a button is pressed, the VSC sets its `sl_SceneActivated` state variable to the index number of button pressed (starting from 1). If a previous state was in effect, `sl_SceneDeactivated` is also set to the previous index for that old mode. In this way, a VSC in single state mode operates very similar to many physical scene controllers in the Vera world. The UI analogue for this behavior is "radio buttons". Also see the description of the `Value` and `Active` state variables below.

When a VSC is in *multi-state* mode, the UI allows more than one mode to be set. Pressing a mode button in the UI toggles the mode's on/off state. It is thus possible for multiple modes, or no mode at all, to be active at any given time. The UI analogue for this is checkboxes. In multi-state mode, the VSC sets `sl_SceneDeactivated` for the mode when it is turned off, and `sl_SceneActivated` as each is turned on. These values both containly only the state of the most-recently changed mode.

The `Value` state variable is also used to store the effective mode. For single-state VSCs, this will only ever contain one value: the last mode selected. For multi-state VSCs, it will contain a comma-separated list of all modes that are active.

The VSC also sets the state variable `ActiveN`, where `N` is the index number of the mode, to 1 on each active mode, or 0 otherwise.

> Now the bad news. Despite using the Vera-defined device definition, Vera's own declared UI for scene controllers is empty both in its web UI and mobile apps &mdash; the standard UIs show only the device name and an icon. In order to make Switchboard's VSCs useful at least in the web UI, Switchboard replaces the Vera standard UI declaration on VSC devices with a custom, dynamically-created one. But, as usual for all custom UIs in Vera currently, the current mobile apps (including third party) do not use the available UI definition data and so do not (and likely never will) be able to paint the custom buttons. Sorry, there will be no UI for VSCs in the mobile app world.

### Controlling VSCs

VSCs can be controlled by Lua, Reactor Activities, PLEG, etc. by invoking the `SetLight` action (in service `urn:micasaverde-com:serviceId:SceneControllerLED1`). The action takes two parameters: `Indicator` and `newValue`. Their use is as follows:

`Indicator`|`newValue`|Description/Function
---------|--------|-----------
An integer from 1 to the number of buttons/labels/modes *or* a string matching one of the defined modes/labels|0 or 1|For multi-state VSCs, turns the mode in `Indicator` on or off according to `newValue` (1=active, 0=inactive, blank=toggle). For single-state VSCs, the mode in `Indicator` is made the (only) current mode, and `newValue` must be 1 (any other value is invalid/unsupported).
The string `"Set$Labels"`|label list|Configures the list of modes/labels for the target VSC. This will cause a Luup reload. You will also need to hard refresh your browser after this action (but I can't make that happen from the plugin).
The string `"Set$Mode"`|0 or 1|Set single-state mode (`newValue` = 0) or multi-state mode (`newValue` = 1).
The string `"Set$Mask"`|maskbits|Sets the enabled modes to those having one bits in the (integer) mask bits in `newValue` (1=LSB). For example, the value 5 would turn on modes 1 and 3, and turn off all other modes. This is for multi-state VSCs only. Its use is undefined/unsupported for single-state VSCs.
The string `"Inc$Mode"`|ignored|Set the next ordinal mode (the mode numbered after the current one). If the next mode is off the end of the list, it wraps around and sets the first mode. This action is defined/supported only for single-state VSCs.
The string `"Dec$Mode"`|ignored|Set the previous ordinal mode (the mode numbered before the current one). If the next mode is off the end of the list, it wraps around and sets the first mode. This action is defined/supported only for single-state VSCs.

> In case you're wondering, VSCs use the standard definition of a scene controller device, but the "standard" (non-LED) scene controller Vera device type defines no actions at all, and the one and only action supported by the extension "scene controller with LEDs" device type is `SetLight`. That is why we must use `SetLight` as the action--it's the only thing we can use. We can't add actions to the standard definitions, so the only option is to "overload" the meaning of values passed to `SetLight`.

## Distinguishing Switchboard Virtual Devices from "Real" Devices

Sometimes it may be necessary to distinguish Switchboard's virtual devices from real devices (e.g. in a startup Lua routine). Device type cannot be used, as Switchboard tries to use Vera-standard devices types to the greatest extent possible. But there are some built-in "tells":

1. The best, most-reliable method is to check the parent of the device; if the parent is a Switchboard master device, then it's a Switchboard virtual device. A quick version of this test is `if (luup.devices[luup.devices[devicenum_being_tested].device_num_parent] or {}).device_type == "urn:schemas-toggledbits-com:device:Switchboard:1" then --[[ it's a Switchboard device --]] end`
2. An alternate method of detection is to look for the existence of the `Behavior` state variable in service `urn:toggledbits-com:serviceId:Switchboard1` on the device; if present and not blank, it's a Switchboard virtual device;
2. The old, now deprecated method is to check the *manufacturer* attribute on the device, which will be "rigpapa"; the *model* attribute will be set to the switch type name, which is always a string beginning with "Switchboard".

## License and Warranty

Switchboard, Copyright 2018,2019,2020 Patrick H. Rigney (rigpapa). All Rights Reserved.

Switchboard is offered under the MIT License:
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.