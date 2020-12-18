# Switchboard -- Change Log

## Version 1.9 (development, 20353)

* Support for ALTUI 2.52

## Version 1.8 (released, 20179)

* Timer availability is now per-device-type, and removed from UI where not applicable.
* Completely restructure inits at switch startup.

## Version 1.7 (released)

* Tri-state switches will now timer-reset to the `TimerResetState` when set to any state other than that (not just "on" as in 1.6).
* New virtual Scene Controller! Set the `Values` state variable to the (comma-separated) list of button values. You can do this directly, or through the device's own UI (not the Switchboard master device--go into the device control panel on the virtual scene controller). See the README for more.

## Version 1.6 (released)

* Add Lock, Water Valve, and Relay virtual devices. Note that lock has a separate service for `Target` and `Status` from all other binary on/off devices &mdash; it does not use `urn:upnp-org:serviceId:SwitchPower1`, but rather `urn:micasaverde-com:serviceId:DoorLock1`.
* Make post-timer return state configurable via `TimerResetState`; this enables TriState virtual switches to return to off or void.

## Version 1.5 (released)

* Fix an issue with window covering ramp rate not properly handling zero value (disable ramp).

## Version 1.4 (released)

* Add support for virtual window covering (Vera implements these as dimmers, so while it seems an odd thing to do here, it's a natural for Vera).

## Version 1.3 (released)

* Fix TriState initialization

## Version 1.2 (released)

* Support repeat triggering. By default, the virtual switch will only set its status if it changes, and as a result, scenes will only trigger on changes in status. In some cases, it is useful to trigger scenes/watches whenever the switch state is set, regardless of whether or not that results in a change in status (repeat triggering), so add a new flag for this purpose.
* Fix notices and links in copyright area.

## Version 1.1 (released)

* Maintenance/fixes

## Version 1.0 (released)

* Initial public release.