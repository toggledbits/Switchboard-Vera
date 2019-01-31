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

Installation of Switchboard is best done from the AltAppStore. Find it. Click it. Done.

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

## Legacy Virtual Switch Features

To maintain compatibility with the older Virtual Switch plugin's switches, Switchboard's switches implement the services and behaviors of the older plugin, in addition to the standard Vera binary switch behaviors.

The old Virtual Switch plugin supported two text fields for each switch. These have made their way into Switchboard's switches as well, for compatibility. However, because the Vera-native UI is used for Switchboard's virtual switches, there is no way to display them in the native Vera switch UI. They are visible and editable in the Switchboard "Status" tab, however.

## Distinguishing Switchboard Virtual Switches from Real Switches

Sometimes it may be necessary to distinguish Switchboard's virtual switches from real switches (e.g. in a startup Lua routine). Device type cannot be used, and Switchboard tries to use Vera-standard devices types to the greatest extent possible. But there are some built-in "tells": all Switchboard child devices will have the manufacturer attribute set to "rigpapa", and the model attribute set to the switch type name. Currently, only two types are defined: "Switchboard Virtual Binary Switch" and "Switchboard Virtual Tri-state Switch".

## License and Warranty

This software is provided "as-is" together with all defects, and no warranties, express or implied, are made, including but not
limited to warranties of fitness for the purpose. By using this software, you agree to assume all risks, of whatever kind, arising
in connection with your use. If you do not agree to these terms, you may not use this plugin. In any case, you may not distribute
this plugin or produce any derivative works.
