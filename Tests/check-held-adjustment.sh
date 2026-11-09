#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
cp Tests/HeldAdjustmentChecks.swift "$check_dir/main.swift"
xcrun swiftc MonitorControl/Support/HeldAdjustment.swift "$check_dir/main.swift" -o "$check_dir/check"
"$check_dir/check"
