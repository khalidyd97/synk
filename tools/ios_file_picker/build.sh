#!/bin/bash
# Builds the SYNK iOS file picker GDExtension into addons/synk_ios_picker (macOS + Xcode only).
# Usage: tools/ios_file_picker/build.sh <project root>
set -euo pipefail
root="$1"
here="$(cd "$(dirname "$0")" && pwd)"
work="${TMPDIR:-/tmp}/synk_ios_picker"
rm -rf "$work"; mkdir -p "$work"
git clone -q --depth 1 --branch godot-4.5-stable https://github.com/godotengine/godot-cpp "$work/godot-cpp"
python3 -m venv "$work/venv"
"$work/venv/bin/pip" install -q scons
(cd "$work/godot-cpp" && "$work/venv/bin/scons" -Q platform=ios arch=arm64 target=template_release ios_simulator=no -j"$(sysctl -n hw.ncpu)")
cpp_lib=$(find "$work/godot-cpp/bin" -name 'libgodot-cpp.ios.template_release*.a' -print -quit)
test -n "$cpp_lib"
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
fw="$work/synk_ios_picker.framework"
mkdir -p "$fw"
xcrun --sdk iphoneos clang++ -arch arm64 -isysroot "$sdk" -miphoneos-version-min=15.0 -std=c++17 -fobjc-arc -fPIC -O2 \
  -I"$work/godot-cpp/include" -I"$work/godot-cpp/gen/include" -I"$work/godot-cpp/gdextension" \
  -dynamiclib "$here/synk_ios_picker.mm" "$cpp_lib" -framework UIKit -framework PhotosUI -framework CoreGraphics -framework Foundation \
  -install_name @rpath/synk_ios_picker.framework/synk_ios_picker -o "$fw/synk_ios_picker"
cat > "$fw/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>synk_ios_picker</string>
	<key>CFBundleIdentifier</key><string>com.synkstudio.iospicker</string>
	<key>CFBundleName</key><string>synk_ios_picker</string>
	<key>CFBundlePackageType</key><string>FMWK</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
	<key>MinimumOSVersion</key><string>15.0</string>
</dict>
</plist>
PLIST
out="$root/addons/synk_ios_picker"
rm -rf "$out"; mkdir -p "$out"
xcodebuild -create-xcframework -framework "$fw" -output "$out/synk_ios_picker.xcframework"
cat > "$out/synk_ios_picker.gdextension" <<'EXT'
[configuration]
entry_symbol = "synk_ios_picker_init"
compatibility_minimum = "4.5"

[libraries]
ios.debug = "res://addons/synk_ios_picker/synk_ios_picker.xcframework"
ios.release = "res://addons/synk_ios_picker/synk_ios_picker.xcframework"
EXT
echo "Built $out"
