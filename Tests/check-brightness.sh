#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
cp Tests/BrightnessChecks.swift "$check_dir/main.swift"
xcrun swiftc MonitorControl/Enums/Command.swift MonitorControl/Enums/PrefKey.swift \
  MonitorControl/Support/HeldAdjustment.swift MonitorControl/Support/MirrorShortcut.swift \
  MonitorControl/Model/Display.swift MonitorControl/Model/AppleDisplay.swift \
  Tests/BrightnessTestSupport.swift "$check_dir/main.swift" -o "$check_dir/check"
"$check_dir/check"
