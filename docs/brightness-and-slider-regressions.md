# Brightness, mirroring, and slider regression fixes

## Changes

- Reject failed, non-finite, and out-of-range native brightness reads. Failed reads preserve the cached value, animation origin, slider, and synchronization baseline rather than fabricating zero. A successful read of zero remains valid.
- Propagate native write failures. Smooth adjustment stops and restores its last successful value when a write fails.
- Refresh the animation origin after native brightness changes, preventing the next smooth adjustment from starting at an old value.
- Consume repeated and released mirror-shortcut events without toggling or falling through to brightness control. Suppress toggling during sleep or display reconfiguration, and cancel a held adjustment before toggling.
- Place menu icons in a separate column beside the tracks and align optional percentages with the slider. Use semantic icon colors.
- Explicitly invalidate sliders after updating their custom highlight state so keyboard changes request a redraw.

## Verification

`Tests/check-brightness.sh` compiles the production Display and AppleDisplay classes with isolated preferences, simulated native brightness APIs, and stub UI dependencies. It covers read failures, invalid values, legitimate zero, direct and smooth write failures, native-change animation origins, active-animation polling, startup fallback, and mirror-shortcut routing. It never writes real display brightness.

`Tests/check-sliders.sh` compiles the production SliderHandler and HeldAdjustment classes with stub display dependencies. It checks icon separation and percentage bounds for brightness, volume, and contrast with ticks and percentages enabled/disabled, live value updates in the menu tracking run-loop mode, and combined-display highlights. Both new checks run during release preparation.

All six check scripts passed on 2026-11-09. The arm64 Release build succeeded with the existing Developer ID identity, and `codesign --verify --deep --strict` passed. No release was published or installed as part of this change.

The friend's original brightness failure was not reproduced on physical hardware. Computer Use exposed only MonitorControl's gamma helper window and timed out when accessing SystemUIServer, so live menu inspection and physical-key verification remain unverified. The separate report of stale menu sliders is not yet narrowed down to open-menu repainting versus an incorrect control target; explicit invalidation addresses repainting, but is not proof that the friend's reported cause is resolved. A Dell DDC volume slider intentionally represents the Dell, not unrelated Mac speakers or headphones.
