# Held-key brightness speed investigation

## Observations (2026-11-09)

The supplied six-second video shows the app's brightness HUD for “Color LCD”. Samples at half-second intervals are approximately 79%, 81%, 84%, 86%, 89%, 89%, 87%, 84%, 82%, 79%, 77%, and 74%. The upward and downward portions both run at roughly five percentage points per second. The recording does not show keyboard modifiers or preferences, so it cannot establish the exact configuration.

## Explanation supported by the code

`HeldAdjustment.advance()` applies 0.2 of the full range per second in smooth mode, independent of macOS key-repeat events. `HeldAdjustment.adjusted()` multiplies this by 0.25 for fine control. Normal mode therefore moves 20 percentage points per second (about five seconds across the full range); fine mode moves five points per second (about twenty seconds). There is also a small initial tap increment.

`MediaKeyTapManager.handle()` enables fine brightness control with Shift+Option, and inverts that choice when `useFineScaleBrightness` is enabled. Custom shortcuts use the preference directly. The video closely matches fine mode, but this remains a diagnosis to confirm on the friend's machine, not proof of a hardware or timer defect.

The owner's local `app.monitorcontrol.MonitorControl` preferences had no explicit `useFineScaleBrightness` or `disableSmoothBrightness` value during inspection. Both default to false with the current code, consistent with normal-speed smooth adjustment on this machine.

## Friend's check

1. Open MonitorControl Settings → Keyboard. In the brightness section, uncheck **Use fine OSD scale for brightness and contrast** (Simplified Chinese: **使用精细的OSD刻度**). Despite its wording, this changes adjustment speed as well as the scale.
2. Hold a brightness key without Shift or Option. In the app's smooth mode, moving from 40% to 60% should take approximately one second, rather than four seconds. Start away from either limit.
3. If fine mode is preferred for small changes, leave it enabled and use Shift+Option with the standard brightness keys to temporarily invert it to normal speed. This modifier inversion applies to the media-key path, not custom shortcuts.
4. If the rate remains near five points per second with fine mode off, collect the app version/build, Keyboard and smooth-adjustment settings, and a new timed recording showing the key hold. Check whether keyboard remapping or stuck modifiers are supplying Shift+Option.

Changing macOS Key Repeat is not the first remedy: the smooth path ignores operating-system repeats. The legacy path used when smooth adjustment is disabled behaves differently.

## Verification and limits

`Tests/check-held-adjustment.sh` passes, covering timer-frequency independence at 30/60 Hz, repeat suppression, release, fine scaling, reversal, bounds, and cancellation. No runtime changes, preference changes, build, installation, or release were made for this investigation. The other active chat owns the native-volume fix and installed test build.

The timer caps each callback's elapsed time at 0.1 seconds, so sustained callbacks slower than 10 Hz could also reduce speed. The video alone cannot rule that out, but its consistent five-points-per-second ramp matches fine mode exactly; changing the stall safeguard without confirming settings would be premature.
