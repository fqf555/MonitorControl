import Foundation

/// A main-thread, elapsed-time ramp independent of the system key-repeat delay.
/// Callers retain target selection, mute handling and the hardware's quantization.
final class HeldAdjustment<Key: Equatable> {
  private(set) var key: Key?
  private var timer: Timer?
  private var action: ((Float) -> Bool)?
  private var lastTime: TimeInterval = 0
  private var startTime: TimeInterval = 0
  private let clock: () -> TimeInterval

  init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
    self.clock = clock
  }

  deinit { self.timer?.invalidate() }

  func start(_ key: Key, action: @escaping (Float) -> Bool) {
    guard self.key != key else { return } // Ignore OS key-repeat events.
    self.stop()
    self.key = key
    self.action = action
    self.lastTime = self.clock()
    self.startTime = self.lastTime
    // A brief tap remains useful, but never jumps to a 1/16th notch.
    guard action(0.005), self.key == key else { self.stop(); return }
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.advance() }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func advance() {
    guard self.key != nil, let action = self.action else { return }
    let now = self.clock()
    // Stop after a lost key-up; a normal full-range sweep takes five seconds.
    guard now - self.startTime < 30 else { self.stop(); return }
    let elapsed = max(0, min(0.1, now - self.lastTime))
    self.lastTime = now
    if elapsed > 0, !action(Float(elapsed) * 0.2) { self.stop() }
  }

  func stop(_ key: Key? = nil) {
    if let key = key, self.key != key { return }
    self.timer?.invalidate()
    self.timer = nil
    self.key = nil
    self.action = nil
  }

  static func adjusted(_ value: Float, isUp: Bool, amount: Float, fine: Bool) -> Float {
    min(1, max(0, value + (isUp ? 1 : -1) * amount * (fine ? 0.25 : 1)))
  }
}
