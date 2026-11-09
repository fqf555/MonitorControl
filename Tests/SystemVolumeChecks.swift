import Foundation

final class Output: SystemVolumeOutput {
  let volumeOutputID: String
  var level: Float = 0.4
  var muted = false
  var supportsOutputMute = true
  var failWrites = false
  var outputVolume: Float? { self.level }
  var outputMuted: Bool { self.muted }
  init(_ id: String) { self.volumeOutputID = id }
  func writeOutputVolume(_ value: Float) -> Bool {
    guard !self.failWrites else { return false }
    self.level = value
    return true
  }
  func writeOutputMute(_ value: Bool) -> Bool {
    guard !self.failWrites else { return false }
    self.muted = value
    return true
  }
}

func close(_ actual: Float?, _ expected: Float) {
  guard let actual = actual else { fatalError("Unexpected write failure") }
  assert(abs(actual - expected) < 0.00001, "\(actual) != \(expected)")
}

// Preserve upstream targets: native speakers/headphones, DDC for uncontrollable
// outputs, and explicit display-name matching ahead of native control.
assert(VolumeKeyRoute.select(canControlSystemOutput: true, matchByName: false, hasMatchingDisplay: false) == .system)
assert(VolumeKeyRoute.select(canControlSystemOutput: false, matchByName: false, hasMatchingDisplay: false) == .display)
assert(VolumeKeyRoute.select(canControlSystemOutput: true, matchByName: true, hasMatchingDisplay: true) == .display)
assert(VolumeKeyRoute.select(canControlSystemOutput: true, matchByName: true, hasMatchingDisplay: false) == .system)
assert(VolumeKeyRoute.select(canControlSystemOutput: false, matchByName: true, hasMatchingDisplay: false) == .passthrough)

let controller = SystemVolumeController()
let speakers = Output("speakers")
close(controller.adjust(speakers, isUp: true, fine: false, amount: 0.005), 0.405)
close(controller.adjust(speakers, isUp: false, fine: true, amount: 0.02), 0.4)
close(controller.adjust(speakers, isUp: true, fine: false, amount: nil), 0.4375)
close(controller.adjust(speakers, isUp: false, fine: false, amount: nil), 0.375)
close(controller.toggleMute(speakers), 0)
assert(speakers.muted && speakers.level == 0.375)
close(controller.toggleMute(speakers), 0.375)
assert(!speakers.muted)
_ = controller.toggleMute(speakers)
close(controller.adjust(speakers, isUp: true, fine: false, amount: 0.005), 0.38)
assert(!speakers.muted)

let usb = Output("usb")
usb.supportsOutputMute = false
close(controller.toggleMute(usb), 0)
assert(usb.level == 0)
let headphones = Output("headphones")
headphones.supportsOutputMute = false
headphones.level = 0.7
close(controller.toggleMute(headphones), 0)
close(controller.toggleMute(usb), 0.4)
close(controller.toggleMute(headphones), 0.7)
_ = controller.toggleMute(usb)
_ = controller.adjust(usb, isUp: true, fine: false, amount: 0.005)
close(controller.toggleMute(usb), 0)
close(controller.toggleMute(usb), 0.005) // Manual adjustment replaces the old restore level.

speakers.level = 0.999
close(controller.adjust(speakers, isUp: true, fine: false, amount: 0.005), 1)
speakers.level = 0.001
close(controller.adjust(speakers, isUp: false, fine: false, amount: 0.005), 0)
speakers.failWrites = true
assert(controller.adjust(speakers, isUp: true, fine: false, amount: 0.005) == nil)
assert(controller.toggleMute(speakers) == nil)

// Exercise the actual timed controller with the native-output path, including release.
speakers.failWrites = false
speakers.level = 0.4
var time = 0.0
let held = HeldAdjustment<Int>(clock: { time })
held.start(1) { controller.adjust(speakers, isUp: false, fine: false, amount: $0) != nil }
for _ in 0..<30 { time += 1.0 / 60; held.advance() }
close(speakers.level, 0.295)
held.stop(1)
time += 0.1
held.advance()
close(speakers.level, 0.295)
print("PASS: native/DDC routing, smooth/stepped/fine volume, release, bounds, mute/unmute, per-device restore and write failures")
