//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AudioToolbox
import Cocoa
import Foundation
import MediaKeyTap
import SimplyCoreAudio
import os.log

class MediaKeyTapManager: MediaKeyTapDelegate {
  private let heldAdjustment = HeldAdjustment<MediaKey>()
  private let systemVolume = SystemVolumeController()
  private var volumeRoute = VolumeKeyRoute.display
  private var systemVolumeOutput: AudioDevice?

  var mediaKeyTap: MediaKeyTap?
  var keyRepeatTimers: [MediaKey: Timer] = [:]

  func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
    let isPressed = event?.keyPressed ?? true
    if isPressed, mediaKey == .mute { self.heldAdjustment.stop() }
    if !isPressed { self.heldAdjustment.stop(mediaKey) }
    let isRepeat = event?.keyRepeat ?? false
    let isControl = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.control])) ?? false
    let isCommand = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.command])) ?? false
    let isOption = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.option])) ?? false
    let isShift = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.shift])) ?? false
    if MirrorShortcut.handle(isBrightnessDown: mediaKey == .brightnessDown, command: isCommand, control: isControl, pressed: isPressed, repeating: isRepeat, available: app.sleepID == 0 && app.reconfigureID == 0, toggle: {
      self.heldAdjustment.stop()
      _ = DisplayManager.engageMirror()
    }) {
      return
    }
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return
    }
    if isPressed, self.handleOpenPrefPane(mediaKey: mediaKey, event: event, modifiers: modifiers) {
      return
    }
    var isSmallIncrement = isOption && isShift
    let isContrast = isControl && isOption && isCommand
    if [.brightnessUp, .brightnessDown].contains(mediaKey), prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue) {
      isSmallIncrement = !isSmallIncrement
    }
    if [.volumeUp, .volumeDown, .mute].contains(mediaKey), prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue) {
      isSmallIncrement = !isSmallIncrement
    }
    if isPressed, [.brightnessUp, .brightnessDown, .volumeUp, .volumeDown].contains(mediaKey), !prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) {
      self.heldAdjustment.start(mediaKey) { [weak self] amount in
        guard let self = self, app.sleepID == 0, app.reconfigureID == 0, !prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) else { return false }
        if isControl, !isOption, [.brightnessUp, .brightnessDown].contains(mediaKey) {
          self.handleDirectedBrightness(isCommandModifier: isCommand, isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement, amount: amount)
        } else {
          self.sendDisplayCommand(mediaKey: mediaKey, isRepeat: true, isSmallIncrement: isSmallIncrement, isPressed: true, isContrast: isContrast, amount: amount)
        }
        return true
      }
      return
    }
    if isPressed, isControl, !isOption, mediaKey == .brightnessUp || mediaKey == .brightnessDown {
      self.handleDirectedBrightness(isCommandModifier: isCommand, isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
      return
    }
    let oppositeKey: MediaKey? = self.oppositeMediaKey(mediaKey: mediaKey)
    // If the opposite key to the one being held has an active timer, cancel it - we'll be going in the opposite direction
    if let oppositeKey = oppositeKey, let oppositeKeyTimer = self.keyRepeatTimers[oppositeKey], oppositeKeyTimer.isValid {
      oppositeKeyTimer.invalidate()
    } else if let mediaKeyTimer = self.keyRepeatTimers[mediaKey], mediaKeyTimer.isValid {
      // If there's already an active timer for the key being held down, let it run rather than executing it again
      if isRepeat {
        return
      }
      mediaKeyTimer.invalidate()
    }
    self.sendDisplayCommand(mediaKey: mediaKey, isRepeat: isRepeat, isSmallIncrement: isSmallIncrement, isPressed: isPressed, isContrast: isContrast)
  }

  func handleDirectedBrightness(isCommandModifier: Bool, isUp: Bool, isSmallIncrement: Bool, amount: Float? = nil) {
    if isCommandModifier {
      for otherDisplay in DisplayManager.shared.getOtherDisplays() {
        otherDisplay.stepBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement, amount: amount)
      }
      for appleDisplay in DisplayManager.shared.getAppleDisplays() where !appleDisplay.isBuiltIn() {
        appleDisplay.stepBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement, amount: amount)
      }
      return
    } else if let internalDisplay = DisplayManager.shared.getBuiltInDisplay() as? AppleDisplay {
      internalDisplay.stepBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement, amount: amount)
      return
    }
  }

  private func sendDisplayCommand(mediaKey: MediaKey, isRepeat: Bool, isSmallIncrement: Bool, isPressed: Bool, isContrast: Bool = false, amount: Float? = nil) {
    self.sendDisplayCommandVolumeMute(mediaKey: mediaKey, isRepeat: isRepeat, isSmallIncrement: isSmallIncrement, isPressed: isPressed, amount: amount)
    self.sendDisplayCommandBrightnessContrast(mediaKey: mediaKey, isRepeat: isRepeat, isSmallIncrement: isSmallIncrement, isPressed: isPressed, isContrast: isContrast, amount: amount)
  }

  private func sendDisplayCommandVolumeMute(mediaKey: MediaKey, isRepeat: Bool, isSmallIncrement: Bool, isPressed: Bool, amount: Float? = nil) {
    guard [.volumeUp, .volumeDown, .mute].contains(mediaKey), app.sleepID == 0, app.reconfigureID == 0 else { return }
    if self.volumeRoute == .system {
      self.sendSystemVolumeCommand(mediaKey: mediaKey, isRepeat: isRepeat, fine: isSmallIncrement, isPressed: isPressed, amount: amount)
      return
    }
    guard [.volumeUp, .volumeDown, .mute].contains(mediaKey), app.sleepID == 0, app.reconfigureID == 0, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true) else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      switch mediaKey {
      case .mute:
        // The mute key should not respond to press + hold or keyup
        if !isRepeat, isPressed, let display = display as? OtherDisplay {
          display.toggleMute()
          if !wasNotIsPressedVolumeSentAlready, display.readPrefAsInt(for: .audioMuteScreenBlank) != 1, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
            app.playVolumeChangedSound()
            wasNotIsPressedVolumeSentAlready = true
          }
        }
      case .volumeUp, .volumeDown:
        // volume only matters for other displays
        if let display = display as? OtherDisplay {
          if isPressed {
            display.stepVolume(isUp: mediaKey == .volumeUp, isSmallIncrement: isSmallIncrement, amount: amount)
          } else if !wasNotIsPressedVolumeSentAlready, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
            app.playVolumeChangedSound()
            wasNotIsPressedVolumeSentAlready = true
          }
        }
      default: continue
      }
    }
  }

  private func sendSystemVolumeCommand(mediaKey: MediaKey, isRepeat: Bool, fine: Bool, isPressed: Bool, amount: Float?) {
    guard let output = self.systemVolumeOutput, output.id == app.coreAudio.defaultOutputDevice?.id else {
      // Never carry a held adjustment across an output-device change.
      self.heldAdjustment.stop()
      return
    }
    guard isPressed else {
      if mediaKey != .mute, !output.outputMuted, (output.outputVolume ?? 0) > 0 { app.playVolumeChangedSound() }
      return
    }
    if mediaKey == .mute, isRepeat { return }
    let level = mediaKey == .mute
      ? self.systemVolume.toggleMute(output)
      : self.systemVolume.adjust(output, isUp: mediaKey == .volumeUp, fine: fine, amount: amount)
    OSDUtils.showSystemVolume(name: output.name, value: level ?? output.outputVolume ?? 0, unavailable: level == nil)
  }

  private func sendDisplayCommandBrightnessContrast(mediaKey: MediaKey, isRepeat _: Bool, isSmallIncrement: Bool, isPressed: Bool, isContrast: Bool = false, amount: Float? = nil) {
    guard [.brightnessUp, .brightnessDown].contains(mediaKey), app.sleepID == 0, app.reconfigureID == 0, isPressed, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) else {
      return
    }
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      switch mediaKey {
      case .brightnessUp:
        if isContrast, let otherDisplay = display as? OtherDisplay {
          otherDisplay.stepContrast(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement, amount: amount)
        } else {
          var isAnyDisplayInSwAfterBrightnessMode = false
          for display in affectedDisplays where ((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false) && prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) {
            isAnyDisplayInSwAfterBrightnessMode = true
          }
          if !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false))) {
            display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement, amount: amount)
          }
        }
      case .brightnessDown:
        if isContrast, let otherDisplay = display as? OtherDisplay {
          otherDisplay.stepContrast(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement, amount: amount)
        } else {
          display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement, amount: amount)
        }
      default: continue
      }
    }
  }

  private func oppositeMediaKey(mediaKey: MediaKey) -> MediaKey? {
    if mediaKey == .brightnessUp {
      return .brightnessDown
    } else if mediaKey == .brightnessDown {
      return .brightnessUp
    } else if mediaKey == .volumeUp {
      return .volumeDown
    } else if mediaKey == .volumeDown {
      return .volumeUp
    }
    return nil
  }

  func updateMediaKeyTap() {
    self.heldAdjustment.stop()
    var keys: [MediaKey] = []
    if [KeyboardBrightness.media.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue)) {
      keys.append(contentsOf: [.brightnessUp, .brightnessDown])
    }
    if [KeyboardVolume.media.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue)) {
      keys.append(contentsOf: [.mute, .volumeUp, .volumeDown])
    }
    // Remove brightness keys if no external displays are connected, but only if brightness fine control is not active
    var disengageBrightness = true
    for display in DisplayManager.shared.getAllDisplays() where !display.isBuiltIn() {
      disengageBrightness = false
    }
    // Disengage brightness keys on sleep so MacBook native screen can be controlled meanwhile
    if app.sleepID != 0 || app.reconfigureID != 0 {
      disengageBrightness = true
    }
    if disengageBrightness, !prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue) {
      let keysToDelete: [MediaKey] = [.brightnessUp, .brightnessDown]
      keys.removeAll { keysToDelete.contains($0) }
    }
    // Preserve upstream's target selection, but handle native outputs ourselves
    // so standard volume keys also get continuous adjustment and our HUD.
    self.systemVolumeOutput = nil
    self.volumeRoute = .display
    if let defaultAudioDevice = app.coreAudio.defaultOutputDevice {
      let matchByName = prefs.integer(forKey: PrefKey.multiKeyboardVolume.rawValue) == MultiKeyboardVolume.audioDeviceNameMatching.rawValue
      let hasMatchingDisplay = matchByName && DisplayManager.shared.updateAudioControlTargetDisplays(deviceName: defaultAudioDevice.name) > 0
      self.volumeRoute = VolumeKeyRoute.select(canControlSystemOutput: defaultAudioDevice.canSetVirtualMainVolume(scope: .output), matchByName: matchByName, hasMatchingDisplay: hasMatchingDisplay)
      if self.volumeRoute == .system { self.systemVolumeOutput = defaultAudioDevice }
    }
    if self.volumeRoute == .passthrough {
      keys.removeAll { [.volumeUp, .volumeDown, .mute].contains($0) }
    }
    self.mediaKeyTap?.stop()
    self.mediaKeyTap = nil
    // returning an empty array listens for all mediakeys in MediaKeyTap
    if keys.count > 0 {
      self.mediaKeyTap = MediaKeyTap(delegate: self, on: KeyPressMode.keyDownAndUp, for: keys, observeBuiltIn: true)
      self.mediaKeyTap?.start()
    }
  }

  func handleOpenPrefPane(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) -> Bool {
    guard let modifiers = modifiers else { return false }
    if !(modifiers.contains(.option) && !modifiers.contains(.shift) && !modifiers.contains(.control) && !modifiers.contains(.command)) {
      return false
    }
    if event?.keyRepeat == true {
      return false
    }
    switch mediaKey {
    case .brightnessUp, .brightnessDown:
      NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane"))
    case .mute, .volumeUp, .volumeDown:
      NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
    default:
      return false
    }
    return true
  }

  static func acquirePrivileges(firstAsk: Bool = false) {
    if !self.readPrivileges(prompt: true), !firstAsk {
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Shortcuts not available", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("You need to enable MonitorControl in System Settings > Security and Privacy > Accessibility for the keyboard shortcuts to work", comment: "Shown in the alert dialog")
      alert.runModal()
    }
  }

  static func readPrivileges(prompt: Bool) -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: prompt]
    let status = AXIsProcessTrustedWithOptions(options)
    os_log("Reading Accessibility privileges - Current access status %{public}@", type: .info, String(status))
    return status
  }
}

extension AudioDevice: SystemVolumeOutput {
  var volumeOutputID: String { self.uid ?? String(self.id) }
  var outputVolume: Float? { self.virtualMainVolume(scope: .output) }
  var outputMuted: Bool { self.isMainChannelMuted(scope: .output) ?? false }
  var supportsOutputMute: Bool { self.canMute(channel: 0, scope: .output) }
  func writeOutputVolume(_ value: Float) -> Bool { self.setVirtualMainVolume(value, scope: .output) }
  func writeOutputMute(_ muted: Bool) -> Bool { self.setMute(muted, channel: 0, scope: .output) }
}
