import Foundation

/// The native-output path complements DDC without changing which device the keys control.
enum VolumeKeyRoute {
  case system, display, passthrough

  static func select(canControlSystemOutput: Bool, matchByName: Bool, hasMatchingDisplay: Bool) -> VolumeKeyRoute {
    if matchByName, hasMatchingDisplay { return .display }
    if canControlSystemOutput { return .system }
    return matchByName ? .passthrough : .display
  }
}

protocol SystemVolumeOutput {
  var volumeOutputID: String { get }
  var outputVolume: Float? { get }
  var outputMuted: Bool { get }
  var supportsOutputMute: Bool { get }
  func writeOutputVolume(_ value: Float) -> Bool
  func writeOutputMute(_ muted: Bool) -> Bool
}

final class SystemVolumeController {
  // Some USB outputs have a volume control but no mute control.
  private var volumeBeforeMute: [String: Float] = [:]

  func adjust(_ output: SystemVolumeOutput, isUp: Bool, fine: Bool, amount: Float?) -> Float? {
    guard let current = output.outputVolume, current.isFinite else { return nil }
    let target: Float
    if let amount = amount {
      target = HeldAdjustment<Int>.adjusted(current, isUp: isUp, amount: amount, fine: fine)
    } else {
      let step: Float = (isUp ? 1 : -1) / (fine ? 64 : 16)
      target = min(1, max(0, ceil((current + step / 4) / step) * step))
    }
    guard output.writeOutputVolume(target) else { return nil }
    if output.outputMuted, !output.writeOutputMute(false) { return nil }
    self.volumeBeforeMute.removeValue(forKey: output.volumeOutputID)
    return output.outputVolume ?? target
  }

  func toggleMute(_ output: SystemVolumeOutput) -> Float? {
    guard let current = output.outputVolume, current.isFinite else { return nil }
    if output.supportsOutputMute {
      let muted = !output.outputMuted
      guard output.writeOutputMute(muted) else { return nil }
      return muted ? 0 : current
    }
    if current > 0 {
      guard output.writeOutputVolume(0) else { return nil }
      self.volumeBeforeMute[output.volumeOutputID] = current
      return 0
    }
    guard let restored = self.volumeBeforeMute[output.volumeOutputID] else { return 0 }
    guard output.writeOutputVolume(restored) else { return nil }
    self.volumeBeforeMute.removeValue(forKey: output.volumeOutputID)
    return output.outputVolume ?? restored
  }
}
