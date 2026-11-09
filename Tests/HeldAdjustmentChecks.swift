import Foundation

func close(_ a: Float, _ b: Float) { assert(abs(a - b) < 0.00001, "\(a) != \(b)") }
var now = 0.0
let hold = HeldAdjustment<String>(clock: { now })
var value: Float = 0.4
var calls = 0
let up: (Float) -> Bool = { amount in
  value = HeldAdjustment<String>.adjusted(value, isUp: true, amount: amount, fine: false)
  calls += 1
  return true
}
hold.start("up", action: up)
close(value, 0.405)
hold.start("up", action: up)
assert(calls == 1, "OS repeats must not restart the hold")
for _ in 0..<180 { now += 1.0 / 60; hold.advance() }
close(value, 1)
assert(calls == 181, "Continuous holds must not stop at 100 repeats")
hold.start("down") { amount in
  value = HeldAdjustment<String>.adjusted(value, isUp: false, amount: amount, fine: false)
  return true
}
hold.stop("up") // A late release from the previous direction must not stop the new one.
assert(hold.key == "down")
now += 0.05
hold.advance()
close(value, 0.985)
hold.stop("down")
now += 0.05
hold.advance()
close(value, 0.985)
assert(hold.key == nil)
hold.start("blocked") { _ in false }
assert(hold.key == nil, "Unavailable/sleeping targets cancel")
close(HeldAdjustment<String>.adjusted(0.501, isUp: true, amount: 0.003, fine: false), 0.504)
close(HeldAdjustment<String>.adjusted(0.5, isUp: true, amount: 0.02, fine: true), 0.505)
close(HeldAdjustment<String>.adjusted(0.001, isUp: false, amount: 0.01, fine: false), 0)
// Delayed callbacks must not make a giant jump after a main-thread stall.
hold.start("up", action: up)
let beforeStall = value
now += 3
hold.advance()
close(value, min(1, beforeStall + 0.02))
now += 30
hold.advance()
assert(hold.key == nil, "Lost key-up watchdog must stop")
// Equal elapsed time gives the same result at different timer frequencies.
func ramp(_ frequency: Int) -> Float {
  var time = 0.0
  var result: Float = 0.2
  let ramp = HeldAdjustment<Int>(clock: { time })
  ramp.start(1) { result += $0; return true }
  for _ in 0..<frequency { time += 1.0 / Double(frequency); ramp.advance() }
  ramp.stop()
  return result
}
close(ramp(30), ramp(60))
print("PASS: tap, timed hold, repeats, reversal, release, cancellation, fine control, bounds, stall and watchdog")
