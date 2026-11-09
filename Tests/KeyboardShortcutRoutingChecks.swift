extension KeyboardShortcuts {
  static func checkEventRouting() {
    let name = Name("routing-test-\(UUID().uuidString)")
    let shortcut = Shortcut(carbonKeyCode: kVK_F19, carbonModifiers: controlKey | optionKey | shiftKey)
    var downs = 0
    var ups = 0
    setShortcut(shortcut, for: name)
    onKeyDown(for: name) { downs += 1 }
    onKeyUp(for: name) { ups += 1 }
    guard let hotKey = hotKeys.values.first(where: { $0.shortcut == shortcut }) else { fatalError("Registration failed") }
    func deliver(_ kind: UInt32) {
      var event: EventRef?
      assert(CreateEvent(nil, OSType(kEventClassKeyboard), kind, 0, 0, &event) == noErr)
      var id = EventHotKeyID(signature: hotKeySignature, id: UInt32(hotKey.id))
      assert(SetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &id) == noErr)
      assert(SendEventToEventTarget(event, GetEventDispatcherTarget()) == noErr)
      ReleaseEvent(event)
    }
    deliver(UInt32(kEventHotKeyPressed))
    deliver(UInt32(kEventHotKeyReleased))
    assert(downs == 1 && ups == 1)
    disable(name)
    assert(!registeredShortcuts.contains(shortcut))
    enable(name)
    assert(registeredShortcuts.contains(shortcut))
    isPaused = true
    assert(!registeredShortcuts.contains(shortcut))
    isPaused = false
    assert(registeredShortcuts.contains(shortcut))
    setShortcut(nil, for: name)
    removeAllHandlers()
    print("PASS: Carbon registration, press/release dispatch, enable/disable and recorder pause/resume")
  }
}
KeyboardShortcuts.checkEventRouting()
