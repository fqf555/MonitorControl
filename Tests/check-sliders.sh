#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
cp Tests/SliderChecks.swift "$check_dir/main.swift"
xcrun swiftc MonitorControl/Enums/Command.swift MonitorControl/Enums/PrefKey.swift \
  MonitorControl/Support/HeldAdjustment.swift MonitorControl/Support/SliderHandler.swift \
  Tests/SliderTestSupport.swift "$check_dir/main.swift" -o "$check_dir/check"
"$check_dir/check"
