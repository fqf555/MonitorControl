import Cocoa
let DEBUG_MACOS10 = false
let testPreferencesDomain = "MonitorControl-slider-tests-\(UUID().uuidString)"
let prefs = UserDefaults(suiteName: testPreferencesDomain)!
final class AppState { var sleepID = 0; var reconfigureID = 0 }
let app = AppState()
class Display {
  var identifier: CGDirectDisplayID = 1
  func readPrefAsBool(key: PrefKey) -> Bool { false }
  func readPrefAsInt(for command: Command) -> Int { 0 }
  func savePref(_ value: Float, for command: Command) {}
}
class AppleDisplay: Display {
  func getAppleBrightness() -> Float? { 0.5 }
  func getBrightness() -> Float { 0.5 }
  func setBrightness(_ value: Float) -> Bool { true }
}
class OtherDisplay: Display {
  func setupSliderCurrentValue(command: Command) -> Float { 0.5 }
  func toggleMute(fromVolumeSlider: Bool) {}
  func setBrightness(_ value: Float) -> Bool { true }
  func isSw() -> Bool { false }
  func convValueToDDC(for command: Command, from value: Float) -> UInt16 { 0 }
  func writeDDCValues(command: Command, value: UInt16) {}
}
