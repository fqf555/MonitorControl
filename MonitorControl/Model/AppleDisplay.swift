//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import CoreGraphics
import Foundation
import os.log

class AppleDisplay: Display {
  private var displayQueue: DispatchQueue

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, serialNumber: UInt32?, isVirtual: Bool = false, isDummy: Bool = false) {
    self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
  }

  func getAppleBrightness() -> Float? {
    guard !self.isDummy else {
      return 1
    }
    var brightness: Float = .nan
    guard DisplayServicesGetBrightness(self.identifier, &brightness) == 0, brightness.isFinite, (0 ... 1).contains(brightness) else {
      return nil
    }
    return brightness
  }

  func setAppleBrightness(value: Float) -> Bool {
    guard !self.isDummy, value.isFinite else {
      return false
    }
    return self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, value) == 0
    }
  }

  override func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    guard !self.isDummy else {
      return false
    }
    let value = max(min(to, 1), 0)
    guard to.isFinite, self.setAppleBrightness(value: value) else {
      return false
    }
    if !transient {
      self.savePref(value, for: .brightness)
      self.brightnessSyncSourceValue = value
      self.smoothBrightnessTransient = value
    }
    return true
  }

  override func getBrightness() -> Float {
    guard !self.isDummy else {
      return 1
    }
    if self.prefExists(for: .brightness) {
      return self.readPrefAsFloat(for: .brightness)
    } else {
      return self.getAppleBrightness() ?? self.smoothBrightnessTransient
    }
  }

  override func refreshBrightness() -> Float {
    guard !self.smoothBrightnessRunning else {
      return 0
    }
    guard let brightness = self.getAppleBrightness() else {
      return 0
    }
    // Native slider and ambient-light changes become the next animation origin.
    self.smoothBrightnessTransient = brightness
    let oldValue = self.brightnessSyncSourceValue
    self.savePref(brightness, for: .brightness)
    if brightness != oldValue {
      os_log("Pushing slider and reporting delta for Apple display %{public}@", type: .info, String(self.identifier))
      var newValue: Float

      if abs(brightness - oldValue) < 0.01 {
        newValue = brightness
      } else if brightness > oldValue {
        newValue = oldValue + max((brightness - oldValue) / 3, 0.005)
      } else {
        newValue = oldValue + min((brightness - oldValue) / 3, -0.005)
      }
      self.brightnessSyncSourceValue = newValue
      if let sliderHandler = self.sliderHandler[.brightness] {
        sliderHandler.setValue(newValue, displayID: self.identifier)
      }
      return newValue - oldValue
    }
    return 0
  }
}
