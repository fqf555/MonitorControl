//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

class KeyboardShortcutsManager {
  private let brightnessShortcuts: [KeyboardShortcuts.Name] = [.brightnessUp, .brightnessDown, .contrastUp, .contrastDown]
  private let volumeShortcuts: [KeyboardShortcuts.Name] = [.volumeUp, .volumeDown, .mute]

  private let heldAdjustment = HeldAdjustment<KeyboardShortcuts.Name>()

  var initialKeyRepeat = 0.21
  var keyRepeat = 0.028
  var keyRepeatCount = 0

  var currentCommand = KeyboardShortcuts.Name.none
  var isFirstKeypress = false
  var currentEventId = 0
  var isHold = false

  init() {
    KeyboardShortcuts.onKeyDown(for: .brightnessUp) { [self] in
      self.engage(KeyboardShortcuts.Name.brightnessUp)
    }
    KeyboardShortcuts.onKeyDown(for: .brightnessDown) { [self] in
      self.engage(KeyboardShortcuts.Name.brightnessDown)
    }
    KeyboardShortcuts.onKeyDown(for: .contrastUp) { [self] in
      self.engage(KeyboardShortcuts.Name.contrastUp)
    }
    KeyboardShortcuts.onKeyDown(for: .contrastDown) { [self] in
      self.engage(KeyboardShortcuts.Name.contrastDown)
    }
    KeyboardShortcuts.onKeyDown(for: .volumeUp) { [self] in
      self.engage(KeyboardShortcuts.Name.volumeUp)
    }
    KeyboardShortcuts.onKeyDown(for: .volumeDown) { [self] in
      self.engage(KeyboardShortcuts.Name.volumeDown)
    }
    KeyboardShortcuts.onKeyDown(for: .mute) { [self] in
      self.mute()
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessUp) { [self] in
      self.release(.brightnessUp)
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessDown) { [self] in
      self.release(.brightnessDown)
    }
    KeyboardShortcuts.onKeyUp(for: .contrastUp) { [self] in
      self.release(.contrastUp)
    }
    KeyboardShortcuts.onKeyUp(for: .contrastDown) { [self] in
      self.release(.contrastDown)
    }
    KeyboardShortcuts.onKeyUp(for: .volumeUp) { [self] in
      self.release(.volumeUp)
    }
    KeyboardShortcuts.onKeyUp(for: .volumeDown) { [self] in
      self.release(.volumeDown)
    }
    self.updateRegistrations()
  }

  func updateRegistrations() {
    let brightnessEnabled = [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    let volumeEnabled = [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    let enabledShortcuts = (brightnessEnabled ? self.brightnessShortcuts : []) + (volumeEnabled ? self.volumeShortcuts : [])
    let disabledShortcuts = (brightnessEnabled ? [] : self.brightnessShortcuts) + (volumeEnabled ? [] : self.volumeShortcuts)

    self.disengage()
    for shortcut in enabledShortcuts {
      KeyboardShortcuts.enable(shortcut)
    }
    for shortcut in disabledShortcuts {
      KeyboardShortcuts.disable(shortcut)
    }
  }

  func engage(_ shortcut: KeyboardShortcuts.Name) {
    os_log("Shortcut received: %{public}@; sleep=%d reconfigure=%d", type: .info, shortcut.rawValue, app.sleepID, app.reconfigureID)
    guard self.isEnabled(shortcut) else {
      return
    }
    if !prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) {
      self.currentCommand = shortcut
      self.heldAdjustment.start(shortcut) { [weak self] amount in
        guard let self = self, app.sleepID == 0, app.reconfigureID == 0, self.isEnabled(shortcut), !prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) else { return false }
        switch shortcut {
        case .brightnessUp: self.brightness(isUp: true, amount: amount)
        case .brightnessDown: self.brightness(isUp: false, amount: amount)
        case .contrastUp: self.contrast(isUp: true, amount: amount)
        case .contrastDown: self.contrast(isUp: false, amount: amount)
        case .volumeUp: self.volume(isUp: true, isPressed: true, amount: amount)
        case .volumeDown: self.volume(isUp: false, isPressed: true, amount: amount)
        default: return false
        }
        return true
      }
      return
    }
    self.initialKeyRepeat = max(15, UserDefaults.standard.double(forKey: "InitialKeyRepeat")) * 0.014
    self.keyRepeat = max(2, UserDefaults.standard.double(forKey: "KeyRepeat")) * 0.014
    self.currentCommand = shortcut
    self.isFirstKeypress = true
    self.isHold = true
    self.currentEventId += 1
    self.keyRepeatCount = 0
    self.apply(shortcut, eventId: self.currentEventId)
  }

  private func isEnabled(_ shortcut: KeyboardShortcuts.Name) -> Bool {
    if self.brightnessShortcuts.contains(shortcut) {
      return [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    }
    if self.volumeShortcuts.contains(shortcut) {
      return [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    }
    return false
  }

  private func release(_ shortcut: KeyboardShortcuts.Name) {
    guard self.currentCommand == shortcut else { return }
    if self.heldAdjustment.key != nil, [.volumeUp, .volumeDown].contains(shortcut) {
      self.volume(isUp: true, isPressed: false)
    }
    self.disengage()
  }

  func disengage() {
    self.heldAdjustment.stop()
    self.isHold = false
    self.isFirstKeypress = false
    self.currentCommand = KeyboardShortcuts.Name.none
    self.keyRepeatCount = 0
  }

  func apply(_ shortcut: KeyboardShortcuts.Name, eventId: Int) {
    guard app.sleepID == 0, app.reconfigureID == 0, self.keyRepeatCount <= 100 else {
      self.disengage()
      return
    }
    guard self.currentCommand == shortcut, self.isHold, eventId == self.currentEventId else {
      if [KeyboardShortcuts.Name.volumeUp, KeyboardShortcuts.Name.volumeDown].contains(shortcut) {
        self.volume(isUp: true, isPressed: false)
      }
      return
    }
    if self.isFirstKeypress {
      self.isFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + self.initialKeyRepeat) {
        self.apply(shortcut, eventId: eventId)
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + self.keyRepeat) {
        self.apply(shortcut, eventId: eventId)
      }
    }
    self.keyRepeatCount += 1
    switch shortcut {
    case KeyboardShortcuts.Name.brightnessUp: self.brightness(isUp: true)
    case KeyboardShortcuts.Name.brightnessDown: self.brightness(isUp: false)
    case KeyboardShortcuts.Name.contrastUp: self.contrast(isUp: true)
    case KeyboardShortcuts.Name.contrastDown: self.contrast(isUp: false)
    case KeyboardShortcuts.Name.volumeUp: self.volume(isUp: true, isPressed: true)
    case KeyboardShortcuts.Name.volumeDown: self.volume(isUp: false, isPressed: true)
    default: break
    }
  }

  func brightness(isUp: Bool, amount: Float? = nil) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false), [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue)) else {
      self.disengage()
      return
    }
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      var isAnyDisplayInSwAfterBrightnessMode = false
      for display in affectedDisplays where ((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false) && prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) {
        isAnyDisplayInSwAfterBrightnessMode = true
      }
      if !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false))) {
        display.stepBrightness(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue), amount: amount)
      }
    }
  }

  func contrast(isUp: Bool, amount: Float? = nil) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false), [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue)) else {
      self.disengage()
      return
    }
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      if let otherDisplay = display as? OtherDisplay {
        otherDisplay.stepContrast(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue), amount: amount)
      }
    }
  }

  func volume(isUp: Bool, isPressed: Bool, amount: Float? = nil) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true), [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue)) else {
      self.disengage()
      return
    }
    os_log("Volume targets: %{public}@", type: .info, affectedDisplays.map { $0.name }.joined(separator: ", "))
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      if let display = display as? OtherDisplay {
        if isPressed {
          display.stepVolume(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue), amount: amount)
        } else if !wasNotIsPressedVolumeSentAlready, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
          app.playVolumeChangedSound()
          wasNotIsPressedVolumeSentAlready = true
        }
      }
    }
  }

  func mute() {
    self.disengage()
    guard app.sleepID == 0, app.reconfigureID == 0, [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue)), let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true) else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      if let display = display as? OtherDisplay {
        display.toggleMute()
        if !wasNotIsPressedVolumeSentAlready, display.readPrefAsInt(for: .audioMuteScreenBlank) != 1, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
          app.playVolumeChangedSound()
          wasNotIsPressedVolumeSentAlready = true
        }
      }
    }
  }
}
