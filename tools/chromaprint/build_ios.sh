#!/usr/bin/env bash
set -euo pipefail
root="${1:-$(pwd)}"
cd "$root"
python3 tools/chromaprint/prepare.py
build="$root/.tools/acoustid/build-ios"
cmake -S tools/chromaprint -B "$build" -G "Unix Makefiles" -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)" -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DCMAKE_BUILD_TYPE=Release -DKISSFFT_SOURCE_DIR="$root/.tools/acoustid/kissfft-131.1.0" -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build "$build" --parallel 4
mkdir -p assets/native/chromaprint/ios
bindings=$(find "$build" -name 'libgodot-cpp*.a' -print -quit)
test -n "$bindings"
xcrun libtool -static -o assets/native/chromaprint/ios/libsynk_chromaprint.a "$build/libsynk_chromaprint.a" "$bindings"
cp "$build/chromaprint/src/libchromaprint.a" assets/native/chromaprint/ios/
python3 - <<'PYCODE'
from pathlib import Path
p=Path('assets/native/chromaprint/chromaprint.gdextension')
s=p.read_text().replace('[libraries]','[libraries]\nios.arm64="res://assets/native/chromaprint/ios/libsynk_chromaprint.a"').replace('[dependencies]','[dependencies]\nios.arm64={"res://assets/native/chromaprint/ios/libchromaprint.a":""}')
p.write_text(s)
p=Path('scripts/music_recognition.gd');s=p.read_text().replace('["Windows","Android"]','["Windows","Android","iOS"]');p.write_text(s)
PYCODE
