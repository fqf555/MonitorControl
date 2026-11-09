# App and monitor brightness percentages

Combined hardware/software brightness uses one slider for two ranges. At the default switching point, app values from 0% to 50% control software dimming while hardware brightness stays at zero. App values from 50% to 100% control hardware brightness from 0% to 100%. Consequently, the app percentage does not match the monitor's physical OSD percentage in this mode.

`OtherDisplay.setDirectBrightness` maps the upper range using `(value - switchingPoint) / (1 - switchingPoint)`. `combinedBrightnessSwitchingValue` defaults to 0.5. With the default linear DDC curve and 0–100 hardware range, a saved app value of 0.753908 produces a rounded hardware value of 51. This explains the reported 75% versus 51% mismatch without a failed DDC write.

For matching percentages, disable combined hardware/software brightness in General preferences and use the default linear DDC curve and hardware range. This removes software dimming below the monitor's hardware minimum from the combined slider. Reading settings from the display at startup also avoids initializing the slider from an old cached value. The existing General preference toggle sets displays to maximum brightness before reconfiguring, so changing it through the UI may temporarily increase brightness.

## Local verification — 2026-11-09

The owner's running installation had combined brightness enabled, default brightness mapping, and a Dell P3421W cached brightness of 0.753908. After quitting the app, setting `disableCombinedBrightness` to true and `startupAction` to 2 (read), and relaunching, the app logged a successful DDC brightness read of 51 and saved a normalized brightness of 0.51. Hardware brightness was preserved. The physical OSD value of 51 was reported by the owner; the agent independently verified the DDC read and saved app value, not the physical OSD. No application binary changes were necessary.
