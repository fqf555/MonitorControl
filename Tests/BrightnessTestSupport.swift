// Isolated dependencies for the real Display and AppleDisplay implementations.
// No DisplayServices calls, gamma writes, HUDs, or persistent user preferences.
import Cocoa
let DEBUG_VIRTUAL = false
let testPreferencesDomain = "MonitorControl-tests-\(UUID().uuidString)"
let prefs = UserDefaults(suiteName: testPreferencesDomain)!
final class AppState { var sleepID = 0; var reconfigureID = 0 }
let app = AppState()
final class SliderHandler {
  var value: Float = -1
  func setValue(_ value: Float, displayID: CGDirectDisplayID) { self.value = value }
}
final class DisplayManager {
  static let shared = DisplayManager()
  var gammaInterferenceWarningShown = false
  var gammaInterferenceCounter = 0
  func updateShade(displayID: CGDirectDisplayID) -> Bool { false }
  func destroyShade(displayID: CGDirectDisplayID) -> Bool { false }
  func setShadeAlpha(value: Float, displayID: CGDirectDisplayID) -> Bool { fatalError("Unexpected shade write") }
  func getShadeAlpha(displayID: CGDirectDisplayID) -> Float? { nil }
  func moveGammaActivityEnforcer(displayID: CGDirectDisplayID) { fatalError("Unexpected gamma write") }
  func enforceGammaActivity() {}
  static func resolveEffectiveDisplayID(_ id: CGDirectDisplayID) -> CGDirectDisplayID { id }
  func getOtherDisplays() -> [Display] { [] }
}
final class PrefsView { func loadDisplayList() {} }
let displaysPrefsVc: PrefsView? = nil
enum OSDUtils {
  static func showOsd(displayID: CGDirectDisplayID, command: Command, value: Float, maxValue: Float) {}
}
var readFails = false
var writeFails = false
var hardware: Float = 0.2
var writes: [Float] = []
func DisplayServicesGetBrightness(_ id: CGDirectDisplayID, _ output: inout Float) -> Int32 {
  if readFails { return -1 }
  output = hardware
  return 0
}
func DisplayServicesSetBrightness(_ id: CGDirectDisplayID, _ value: Float) -> Int32 {
  writes.append(value)
  if writeFails { return -1 }
  hardware = value
  return 0
}
