import Foundation
defer { prefs.removePersistentDomain(forName: testPreferencesDomain) }

func close(_ actual: Float, _ expected: Float) {
  assert(abs(actual - expected) < 0.00001, "\(actual) != \(expected)")
}
// Invalid display ID prevents even gamma-table reads from targeting a real screen.
let display = AppleDisplay(UInt32.max, name: "Regression", vendorNumber: nil, modelNumber: nil, serialNumber: nil)
let slider = SliderHandler()
display.sliderHandler[.brightness] = slider
hardware = 0.8
_ = display.refreshBrightness()
close(display.getBrightness(), 0.8)
close(display.smoothBrightnessTransient, 0.8)
let baseline = display.brightnessSyncSourceValue
let sliderValue = slider.value
for invalid: Float in [.nan, .infinity, -0.1, 1.1] {
  hardware = invalid
  assert(display.getAppleBrightness() == nil)
  close(display.refreshBrightness(), 0)
  close(display.getBrightness(), 0.8)
  close(display.brightnessSyncSourceValue, baseline)
  close(slider.value, sliderValue)
}
hardware = 0.8
readFails = true
assert(display.getAppleBrightness() == nil)
close(display.refreshBrightness(), 0)
close(display.getBrightness(), 0.8)
close(display.smoothBrightnessTransient, 0.8)
readFails = false
// Legitimate zero remains valid, unlike a failed read.
hardware = 0
assert(display.getAppleBrightness() == 0)
_ = display.refreshBrightness()
close(display.getBrightness(), 0)
close(display.smoothBrightnessTransient, 0)
// A native change must affect the first real animation write, not just the cache.
hardware = 0.8
_ = display.refreshBrightness()
assert(display.setSmoothBrightness(0.9))
assert(writes.last! > 0.8 && writes.last! < 0.9)
let previous = display.smoothBrightnessTransient
// Polling must not overwrite an in-progress target.
_ = display.refreshBrightness()
close(display.getBrightness(), 0.9)
writeFails = true
assert(!display.setSmoothBrightness())
assert(!display.smoothBrightnessRunning)
close(display.smoothBrightnessTransient, previous)
close(display.getBrightness(), previous)
close(display.brightnessSyncSourceValue, previous)
assert(!display.setDirectBrightness(0.1))
close(display.getBrightness(), previous)
assert(!display.setDirectBrightness(.nan))
assert(!display.setSmoothBrightness(.infinity))
writeFails = false
assert(display.setDirectBrightness(0.4))
close(hardware, 0.4)
close(display.getBrightness(), 0.4)
// Test both final-write branches of the smoother on failure.
writeFails = true
assert(!display.setSmoothBrightness(0.405))
close(display.getBrightness(), 0.4)
assert(!display.setSmoothBrightness(0.4))
close(display.getBrightness(), 0.4)
// Fresh startup read failure has a neutral fallback, never fabricated zero.
readFails = true
let fresh = AppleDisplay(UInt32.max - 1, name: "Fresh", vendorNumber: nil, modelNumber: nil, serialNumber: nil)
close(fresh.getBrightness(), 1)
assert(!fresh.prefExists(for: .brightness))

var toggles = 0
func chord(pressed: Bool = true, repeating: Bool = false, available: Bool = true, command: Bool = true, control: Bool = false, down: Bool = true) -> Bool {
  MirrorShortcut.handle(isBrightnessDown: down, command: command, control: control, pressed: pressed, repeating: repeating, available: available) { toggles += 1 }
}
assert(chord())
assert(toggles == 1)
assert(chord(repeating: true))
assert(chord(pressed: false))
assert(chord(available: false))
assert(toggles == 1)
assert(!chord(command: false))
assert(!chord(control: true))
assert(!chord(down: false))
assert(chord())
assert(toggles == 2)
print("PASS: native refresh, invalid/failed reads, failed direct/smooth writes, animation origin, mirror repeats/release/reconfiguration")
