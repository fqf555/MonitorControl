/// Consume the mirror chord on both edges, but toggle only on an initial press.
/// Repeats must never fall through into brightness adjustment.
enum MirrorShortcut {
  static func handle(isBrightnessDown: Bool, command: Bool, control: Bool, pressed: Bool, repeating: Bool, available: Bool, toggle: () -> Void) -> Bool {
    guard isBrightnessDown, command, !control else { return false }
    if pressed, !repeating, available { toggle() }
    return true
  }
}
