#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
# Compile alongside the implementation to exercise its private Carbon dispatcher
# with an isolated, temporary shortcut; no user bindings or UI input are changed.
cat MonitorControl/Support/KeyboardShortcuts.swift Tests/KeyboardShortcutRoutingChecks.swift > "$check_dir/main.swift"
xcrun swiftc "$check_dir/main.swift" -o "$check_dir/check"
"$check_dir/check"
