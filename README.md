# Switchboard -- Re-imagined Virtual Switches for Vera Home Automation

![Switchboard](https://www.toggledbits.com/assets/switchboard/switchboard-default.png) 
This plugin is my take on a modernized *Virtual Switch* plugin for Vera. The long-lived (near zombie) Virtual Switch plugin
has some subtle issues that make it difficult to use with some third party applications (including Google Home and Amazon Echo devices), and even Vera's own native mobile app for Android.
Hopefully, this version of virtual switches will address those shortcomings.

NOTE: This plugin does not yet support openLuup. The things that make it work better on Vera than VSwitch are the things that are troubling to openLuup. I will make an effort to reconcile these at some point, but for the moment, this plugin is only supported on Vera UI7 and higher.

## Installing on Vera

This plugin has not yet been published to the Vera Plugin Marketplace, so you will have to install it "the hard way."

1. Download a ZIP file of the plugin by clicking the green "Clone or download" button on the Github repository master branch page, here: https://github.com/toggledbits/Switchboard-Vera (choose "Download ZIP" from the pop-up).
2. Unzip the downloaded ZIP file to a folder.
3. Upload the folder contents to your Vera using the uploader at *Apps > Develop apps > Luup files*. You should turn *off* the "Restart Luup after Upload" checkbox until the last file, and then turn it back on. If you forget, no worries, just turn it on and re-upload the last file.
4. Wait for Luup to reload (about 60-120 seconds depending on your Vera and system load).
5. Go to *Apps > Develop apps > Create device* and supply the following fields (leave the rest blank). Copy-paste is recommended, as accuracy in spelling and capitalization is vital to the success of this step:
   * Description: `Switchboard`
   * Upnp Device Filename: `D_Switchboard1.xml`
   * Upnp Implementation Filename: `I_Switchboard1.xml`
6. Press the "Create device" button.
6. Go to the "Test Luup code (Lua)" item in *Apps > Develop apps*, and enter and run: `luup.reload()`
6. While that's working, hard-refresh your browser (reload page with cache flush: CTRL-F5 on Chrome/Win, SHIFT-F5 on Firefox/Win, CMD+SHIFT+R on many Mac browsers I'm told).

After Luup reloads and your Vera UI has reloaded, you should see the "Switchboard" device in your devices list.

## Installing on openLuup

**NOTE:** Version 2018.11.21 of openLuup, or higher, is required to run Switchboard.

Installation of Switchboard is best done from the AltAppStore. Find it. Click it.

If you are running an openLuup dated earlier than 2019.06.02, and you do not wish to upgrade to at least
that version, you will also need to install the supplemental device files. Download file files from
https://github.com/toggledbits/Switchboard-Vera/tree/master/openLuup
and then place them in your openLuup install directory with the Switchboard plugin files.

## Creating Virtual Switches

To create virtual switches, go into the "Switchboard" device control panel, and hit the "Add One" button to create one new virtual switch, or "Add Five" to create them five at a time. Each click requires processing and Luup reload, so do this slowly if you have a large number of switches to create.

Once the new device has been created and Switchboard reports the number of devices now running, do a hard-refresh of your browser as described in the last install step above.

**NOTE:** Do not create additional instances of the Switchboard master device. The system should have one and only one Switchboard device. Virtual switches are created only from the Switchboard control panel buttons as described above.

## Switchboard Virtual Switch Features

Switchboard's virtual switches use entirely Vera-native device types and service definitions, and this is what makes them work better than the old Virtual Switch devices (which had a custom device type that Vera really didn't recognize everywhere).

Switchboard's virtual switches can be hidden using the "command and control" interface in the "Status" tab of the Switchboard control panel. Here you will see all of your virtual switches in one place, and be able to control them all, and set options.

Currently, there are only two options: visibility, and self-reset. The visibility option allows you to hide virtual switches, so if you have a large number of them, you can easily get them off your UI7 device list without having to tuck them into a virtual room, etc. The self-reset option creates an "pulse" switch--a switch that provides an "on" pulse and then automatically turns itself off. You can control the length of the pulse for each switch independently; a pulse length of zero means the switch doesn't use pulse timing.

NOTE: Turning "on" a pulse switch that is already on does not extend pulse timing.

NOTE: When a switch is hidden, it will also not be visible in Vera's scene trigger menus and other places in the UI, so if you're trying to create a new scene using a hidden virtual switch, you will first need to go into the Switchboard status panel and un-hide the switch. You can re-hide it after; that doesn't affect the scene's ability to *use* the switch.

## Virtual Window Covering

It may seem odd to have virtual window coverings, but in Vera, the window covering implementation uses the `Dimming1` service to set the opening (e.g. 0% is closed, and 50% is half open, and 100% is fully open). Calling `SetLoadLevelTarget` as one would for a dimmer controls the shade opening. The `SwitchPower` action `SetTarget` can also be used to quickly fully-open or fully-close the covering.

By default, Switchboard will simulate motor movement of the covering by ramping `LoadLevelStatus` at a rate of 5% per second to the target value. If your application requires a different rate, it can be set by setting `RampRatePerSecond` (as percent per second). Setting it to 0 disables ramp and causes the covering to go immediately to the requested target value.

## Legacy Virtual Switch Features

To maintain compatibility with the older Virtual Switch plugin's switches, Switchboard's switches implement the services and behaviors of the older plugin, in addition to the standard Vera binary switch behaviors.

The old Virtual Switch plugin supported two text fields for each switch. These have made their way into Switchboard's switches as well, for compatibility. However, because the Vera-native UI is used for Switchboard's virtual switches, there is no way to display them in the native Vera switch UI. They are visible and editable in the Switchboard "Status" tab, however.

If you have existing virtual switches from the old "Virtual Switch" plugin, you can "adopt" those switches and make them Switchboard devices, which then allows you to uninstall the old "Virtual Switch" plugin. The device numbers will stay the same, so no changes to scenes, Lua, Reactor, PLEG, etc. should be needed.

## Virtual Scene Controllers

Switchboard allows you to create a virtual scene controller. This gives you a multi-button UI that allows you to trigger scenes or Reactor/PLEG rules, etc. I also use this for establishing "modes" that often unrelated to house modes--sometimes you want/need more than the standard Vera house mode delivers. For example, I now use a virtual scene controller to set and track if my home theater is in "Movie Prep", "Preview", "Show", "Pause" or "Off" mode. Over my whole house, I use a virtual scene controller to let my other Reactors know if it is currently "Morning", "Day", "Evening" or "Night".

The virtual scene controllers (VSCs) can have any number of buttons, although 24 seems to be a practical limit for the UI. You determine the number of buttons a VSC can have by providing a comma-separated list of button labels in the VSC's control panel UI. Changing the labels, unfortunately, requires a Luup reload, and you must do a hard-refresh of your browser, for proper display. 

When a VSC is in *single state* mode, only one button can be "down" at a time--only one "mode" can be active at a time. When a button is pressed, the VSC sets its `sl_SceneActivated` state variable to the index number of button pressed (starting from 1). If a previous state was in effect, `sl_SceneDeactivated` is also set to the previous index for that old mode. In this way, a VSC in single state mode operates very similar to many physical scene controllers in the Vera world. The UI analogue for this behavior is "radio buttons". Also see the description of the `Value` and `Active` state variables below.

When a VSC is in *multi-state* mode, the UI allows more than one mode to be set. Pressing a mode button in the UI toggles the mode's on/off state. It is thus possible for multiple modes, or no mode at all, to be active at any given time. The UI analogue for this is checkboxes. In multi-state mode, the VSC sets `sl_SceneDeactivated` for the mode when it is turned off, and `sl_SceneActivated` as each is turned on. These values both containly only the state of the most-recently changed mode.

The `Value` state variable is also used to store the effective mode. For single-state VSCs, this will only ever contain one value: the last mode selected. For multi-state VSCs, it will contain a comma-separated list of all modes that are active.

For convenience when using multi-state VSCs, the VSC also sets the state variable `ActiveN`, where `N` is the index number of the mode, to 1 is the mode is active, or 0 otherwise.

> Now the bad news. Despite using the Vera-defined device definition, Vera's own declared UI for scene controllers, and that supported by the mobile apps, does not (currently) make provision for a multi-button interface in those UIs for activating scenes. The standard UIs are basically blank, with the device name and an icon and that's it. The multi-button UI presented by Switchboard VSCs is achieved by replacing the Vera standard UI declaration with our own, but the current mobile apps (including third party) do not use this data and so cannot (and likely never will) by able to paint the custom buttons. Sorry, there will be no UI for VSCs in the mobile app world.

### Controlling VSCs

VSCs can be controlled by Lua, Reactor, PLEG, etc. by using the `SetLight` action (in service `urn:micasaverde-com:serviceId:SceneControllerLED1`). The action takes two parameters: `Indicator` and `newValue`. Their use is as follows:

Indicator|newValue|Description
---------|--------|-----------
An integer from 1 to the number of buttons/labels/modes|0 or 1|For multi-state VSCs, turns the mode indexed by `Indicator` on or off according to `newValue` (1=active, 0=inactive, blank=toggle). For single-state VSCs, the mode index in `Indicator` is made the (only) current mode, and `newValue` must be 1 (any other value is invalid/unsupported).
The string `"Set$Labels"`|label list|Configures the list of modes/labels for the target VSC. This will cause a Luup reload. You will also need to hard refresh your browser after this action (but I can't make that happen from the plugin).
The string `"Set$Mask"`|maskbits|Sets the enabled modes to those having one bits in the (integer) mask bits in `newValue` (1=LSB). For example, the value 5 would turn on modes 1 and 3, and turn off all other modes. This is for multi-state VSCs only. Its use is undefined/unsupported for single-state VSCs.
The string `"Increment"`|unused|Set the next ordinal mode (the mode numbered after the current one). If the next mode is off the end of the list, it wraps around and sets the first mode. This action is defined/supported only for single-state VSCs.
The string `"Decrement"`|unused|Set the previous ordinal mode (the mode numbered before the current one). If the next mode is off the end of the list, it wraps around and sets the first mode. This action is defined/supported only for single-state VSCs.

> In case you're wondering, VSCs use the standard definition of a scene controller device, but "standard" (non-LED) scene controller in Vera defines no actions at all, and the only action supported by the extension "scene controller with LEDs" device type is `SetLight`. That is why we must use `SetLight` as the action. We can't add actions to the standard definitions, so I chose to "overload" the definition of `SetLight`.

## Distinguishing Switchboard Virtual Switches from Real Switches

Sometimes it may be necessary to distinguish Switchboard's virtual switches from real switches (e.g. in a startup Lua routine). Device type cannot be used, and Switchboard tries to use Vera-standard devices types to the greatest extent possible. But there are some built-in "tells": all Switchboard child devices will have the manufacturer attribute set to "rigpapa", and the model attribute set to the switch type name. Currently, only two types are defined: "Switchboard Virtual Binary Switch" and "Switchboard Virtual Tri-state Switch".

## License and Warranty

Switchboard, Copyright 2018,2019 Patrick H. Rigney (rigpapa). All Rights Reserved.

Switchboard is offered under the MIT License:
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.