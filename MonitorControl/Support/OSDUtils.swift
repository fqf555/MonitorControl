//  Copyright © MonitorControl. @victorchabbert, @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

class OSDUtils: NSObject {
  enum OSDImage: Int64 {
    case brightness = 1
    case audioSpeaker = 3
    case audioSpeakerMuted = 4
    case contrast = 0
  }

  static func getOSDImageByCommand(command: Command, value: Float = 1) -> OSDImage {
    var osdImage: OSDImage
    switch command {
    case .audioSpeakerVolume: osdImage = value > 0 ? .audioSpeaker : .audioSpeakerMuted
    case .audioMuteScreenBlank: osdImage = .audioSpeakerMuted
    case .contrast: osdImage = .contrast
    default: osdImage = .brightness
    }
    return osdImage
  }

  static func showOsd(displayID: CGDirectDisplayID, command: Command, value: Float, maxValue: Float = 1, roundChiclet: Bool = false, lock: Bool = false) {
    if #available(macOS 26.0, *) {
      self.showModern(displayID: displayID, command: command, value: value, maximum: maxValue, unavailable: lock)
      return
    }
    self.withOSD { manager in
      let osdImage = self.getOSDImageByCommand(command: command, value: value)
      let filledChiclets: Int
      let totalChiclets: Int
      if roundChiclet {
        let osdChiclet = OSDUtils.chiclet(fromValue: value, maxValue: maxValue)
        filledChiclets = Int(round(osdChiclet))
        totalChiclets = 16
      } else {
        filledChiclets = Int(value * 100)
        totalChiclets = Int(maxValue * 100)
      }
      manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000, filledChiclets: UInt32(filledChiclets), totalChiclets: UInt32(totalChiclets), locked: lock)
    }
  }

  static func showOsdVolumeDisabled(displayID: CGDirectDisplayID) {
    if #available(macOS 26.0, *) {
      self.showModern(displayID: displayID, command: .audioMuteScreenBlank, value: 0, unavailable: true)
      return
    }
    self.withOSD { manager in
      manager.showImage(22, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
    }
  }

  static func showSystemVolume(name: String, value: Float, unavailable: Bool = false) {
    let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
    let displayID = screen?.displayID ?? CGMainDisplayID()
    if #available(macOS 26.0, *) {
      ModernHUD.shared.show(displayID: displayID, title: name,
                            symbol: unavailable ? "nosign" : (value <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"),
                            level: ModernHUD.normalizedLevel(value, maximum: 1), unavailable: unavailable)
    } else {
      self.showOsd(displayID: displayID, command: .audioSpeakerVolume, value: value, lock: unavailable)
    }
  }

  static func showOsdMuteDisabled(displayID: CGDirectDisplayID) {
    if #available(macOS 26.0, *) {
      self.showModern(displayID: displayID, command: .audioMuteScreenBlank, value: 0, unavailable: true)
      return
    }
    self.withOSD { manager in
      manager.showImage(21, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
    }
  }

  static func popEmptyOsd(displayID: CGDirectDisplayID, command: Command) {
    if #available(macOS 26.0, *) {
      self.showModern(displayID: displayID, command: command, value: 0)
      return
    }
    self.withOSD { manager in
      let osdImage = self.getOSDImageByCommand(command: command)
      manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 0)
    }
  }

  private static func showModern(displayID: CGDirectDisplayID, command: Command, value: Float, maximum: Float = 1, unavailable: Bool = false) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.showModern(displayID: displayID, command: command, value: value, maximum: maximum, unavailable: unavailable) }
      return
    }
    let name = DisplayManager.shared.displays.first { $0.identifier == displayID }?.name ?? "MonitorControl"
    let label: String
    let symbol: String
    switch command {
    case .audioSpeakerVolume, .audioMuteScreenBlank:
      label = NSLocalizedString("Volume", comment: "HUD volume title")
      symbol = unavailable || value <= 0 || command == .audioMuteScreenBlank ? "speaker.slash.fill" : "speaker.wave.2.fill"
    case .contrast:
      label = NSLocalizedString("Contrast", comment: "HUD contrast title")
      symbol = "circle.lefthalf.filled"
    default:
      label = NSLocalizedString("Brightness", comment: "HUD brightness title")
      symbol = "sun.max.fill"
    }
    ModernHUD.shared.show(displayID: displayID, title: "\(name) · \(label)", symbol: unavailable ? "nosign" : symbol,
                          level: ModernHUD.normalizedLevel(value, maximum: maximum), unavailable: unavailable)
  }

  private static func withOSD(_ show: @escaping (OSDUIHelperProtocol) -> Void) {
    if let manager = OSDManager.sharedManager() as? OSDManager { show(manager) }
  }

  static let chicletCount: Float = 16

  static func chiclet(fromValue value: Float, maxValue: Float, half: Bool = false) -> Float {
    (value * self.chicletCount * (half ? 2 : 1)) / maxValue
  }

  static func value(fromChiclet chiclet: Float, maxValue: Float, half: Bool = false) -> Float {
    (chiclet * maxValue) / (self.chicletCount * (half ? 2 : 1))
  }

  static func getDistance(fromNearestChiclet chiclet: Float) -> Float {
    abs(chiclet.rounded(.towardZero) - chiclet)
  }
}
