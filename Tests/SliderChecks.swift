import Cocoa
defer { prefs.removePersistentDomain(forName: testPreferencesDomain) }
_ = NSApplication.shared
CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(RunLoop.Mode.eventTracking.rawValue as CFString))
for percent in [false, true] {
  prefs.set(percent, forKey: PrefKey.enableSliderPercent.rawValue)
  for ticks in [false, true] {
    prefs.set(ticks, forKey: PrefKey.showTickMarks.rawValue)
    for command in [Command.brightness, .audioSpeakerVolume, .contrast] {
      let handler = SliderHandler(display: nil, command: command)
      let slider = handler.slider!
      let icon = handler.icon!
      assert(icon.frame.maxX + 8 <= slider.frame.minX)
      assert(abs(icon.frame.midY - slider.frame.midY) < 0.01)
      assert(handler.view!.bounds.contains(slider.frame))
      if let label = handler.percentageBox {
        assert(label.frame.minX >= slider.frame.maxX)
        assert(handler.view!.bounds.contains(label.frame))
      }
      // Keyboard updates arrive while NSMenu runs its tracking loop.
      let adjustment = HeldAdjustment<Int>()
      var level: Float = 0.3
      adjustment.start(1) { amount in
        level += amount
        slider.needsDisplay = false
        handler.setValue(level, displayID: 1)
        assert(abs(slider.floatValue - level) < 0.00001)
        return true
      }
      let initial = slider.floatValue
      let until = Date(timeIntervalSinceNow: 0.08)
      while Date() < until { RunLoop.main.run(mode: .eventTracking, before: until) }
      adjustment.stop()
      assert(slider.floatValue > initial)
      assert(abs(slider.floatValue - level) < 0.00001)
      if percent { assert(handler.percentageBox!.stringValue == String(format: "%.0f%%", Double(level) * 100)) }
      handler.setValue(0.8, displayID: 2)
      assert((slider.cell as! SliderHandler.MCSliderCell).isHighlightDisplayItems)
      assert((slider.cell as! SliderHandler.MCSliderCell).displayHighlightItems[2] == 0.8)
      if !percent && !ticks && command == .brightness, let output = ProcessInfo.processInfo.environment["SLIDER_PREVIEW"] {
        let view = handler.view!
        view.appearance = NSAppearance(named: .aqua)
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let preview = NSImage(size: view.bounds.size)
        preview.lockFocus()
        NSColor.white.setFill()
        view.bounds.fill()
        bitmap.draw(in: view.bounds)
        preview.unlockFocus()
        let flattened = NSBitmapImageRep(data: preview.tiffRepresentation!)!
        try! flattened.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
      }
    }
  }
}
print("PASS: icon/track separation, percentage layout, tick modes, live menu-tracking updates and combined highlights")
