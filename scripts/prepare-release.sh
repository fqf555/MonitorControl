#!/bin/bash
# Build and notarize an arm64 release. Publishing is a separate, explicit step.
set -euo pipefail
cd "$(dirname "$0")/.."
release_derived="${MONITORCONTROL_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/MonitorControl-local}"
release_identity='Developer ID Application: Qifeng Fu (9L6898HMMN)'
release_profile='Personal-Mac-Releases'
release_account='fqf555.MonitorControl'
release_repo='fqf555/MonitorControl'
mkdir -p dist
xcrun notarytool history --keychain-profile "$release_profile" --output-format json > /dev/null
Tests/check-brightness.sh
Tests/check-sliders.sh
Tests/check-held-adjustment.sh
Tests/check-system-volume.sh
Tests/check-modern-hud.sh
xcodebuild -project MonitorControl.xcodeproj -scheme MonitorControl -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$release_derived" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_STYLE=Manual \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS=--timestamp \
  CODE_SIGN_IDENTITY="$release_identity" DEVELOPMENT_TEAM=9L6898HMMN build > dist/build.log 2>&1
release_app="$release_derived/Build/Products/Release/MonitorControl.app"
release_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$release_app/Contents/Info.plist")
release_build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$release_app/Contents/Info.plist")
release_tools="$release_derived/SourcePackages/artifacts/sparkle/Sparkle/bin"
release_output="$PWD/dist/$release_version-$release_build"
if [[ -e "$release_output" ]]; then
  echo "Release directory already exists: $release_output. Use a new version/build or inspect the existing artifacts." >&2
  exit 1
fi
mkdir -p "$release_output/updates" "$release_output/staging"
ditto "$release_app" "$release_output/staging/MonitorControl.app"
release_app="$release_output/staging/MonitorControl.app"
# Sparkle's SPM artifact contains nested executables that Xcode's outer
# CodeSignOnCopy does not fully sign for distribution. Sign inside-out.
release_framework="$release_app/Contents/Frameworks/Sparkle.framework"
for component in \
  "$release_framework/Versions/B/Autoupdate" \
  "$release_framework/Versions/B/Updater.app" \
  "$release_framework/Versions/B/XPCServices/org.sparkle-project.Downloader.xpc" \
  "$release_framework/Versions/B/XPCServices/org.sparkle-project.InstallerLauncher.xpc" \
  "$release_framework" \
  "$release_app/Contents/Library/LoginItems/MonitorControlHelper.app" \
  "$release_app"; do
  codesign --force --sign "$release_identity" --options runtime --timestamp --preserve-metadata=entitlements "$component"
done
test "$(lipo -archs "$release_app/Contents/MacOS/MonitorControl")" = arm64
codesign --verify --deep --strict "$release_app"
test "$(/usr/libexec/PlistBuddy -c 'Print SUFeedURL' "$release_app/Contents/Info.plist")" = "https://github.com/$release_repo/releases/latest/download/appcast.xml"
test "$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$release_app/Contents/Info.plist")" = "$("$release_tools/generate_keys" --account "$release_account" -p)"
ditto -c -k --keepParent "$release_app" "$release_output/notarization.zip"
xcrun notarytool submit "$release_output/notarization.zip" --keychain-profile "$release_profile" --wait --output-format json > "$release_output/notarization.json"
/usr/bin/plutil -extract status raw "$release_output/notarization.json" | /usr/bin/grep -qx Accepted
xcrun stapler staple "$release_app"
xcrun stapler validate "$release_app"
spctl --assess --type execute --verbose=2 "$release_app"
release_archive="$release_output/updates/MonitorControl-$release_version-arm64.zip"
ditto -c -k --keepParent "$release_app" "$release_archive"
"$release_tools/generate_appcast" --account "$release_account" --maximum-deltas 0 \
  --download-url-prefix "https://github.com/$release_repo/releases/download/v$release_version/" \
  --link "https://github.com/$release_repo/releases/tag/v$release_version" "$release_output/updates"
(cd "$release_output/updates" && shasum -a 256 "MonitorControl-$release_version-arm64.zip" > SHA256SUMS)
echo "Prepared notarized release: $release_output"
