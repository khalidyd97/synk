param([string]$AndroidSdk='D:/Android/sdk',[string]$LlvmMinGW='', [ValidateSet('all','android','windows')][string]$Target='all')
$ErrorActionPreference='Stop'
$repo=Resolve-Path "$PSScriptRoot/../.."
$deps="$repo/.tools/acoustid"
python "$PSScriptRoot/prepare.py"
if($LASTEXITCODE -ne 0){throw 'Dependency preparation failed'}
$cmake="$AndroidSdk/cmake/3.22.1/bin/cmake.exe"
$ninja="$AndroidSdk/cmake/3.22.1/bin/ninja.exe"
$common=@('-S',$PSScriptRoot,'-G','Ninja',"-DCMAKE_MAKE_PROGRAM=$ninja",'-DCMAKE_BUILD_TYPE=Release',"-DKISSFFT_SOURCE_DIR=$deps/kissfft-131.1.0")
if($Target -in @('all','android')){
 $out="$deps/build-android"
 & $cmake @common -B $out "-DCMAKE_TOOLCHAIN_FILE=$AndroidSdk/ndk/28.2.13676358/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_STL=c++_static
 if($LASTEXITCODE -ne 0){throw 'Android configure failed'}
 & $cmake --build $out --parallel 8
 if($LASTEXITCODE -ne 0){throw 'Android build failed'}
 Copy-Item "$out/libsynk_chromaprint.so","$out/chromaprint/src/libchromaprint.so" "$repo/assets/native/chromaprint/android/"
 & "$AndroidSdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe" --strip-unneeded "$repo/assets/native/chromaprint/android/libchromaprint.so" "$repo/assets/native/chromaprint/android/libsynk_chromaprint.so"
}
if($Target -in @('all','windows')){
 if(!$LlvmMinGW){$LlvmMinGW="$deps/llvm-mingw-20261020-ucrt-x86_64"}
 $out="$deps/build-windows"
 & $cmake @common -B $out "-DCMAKE_C_COMPILER=$LlvmMinGW/bin/x86_64-w64-mingw32-clang.exe" "-DCMAKE_CXX_COMPILER=$LlvmMinGW/bin/x86_64-w64-mingw32-clang++.exe"
 if($LASTEXITCODE -ne 0){throw 'Windows configure failed'}
 & $cmake --build $out --parallel 8
 if($LASTEXITCODE -ne 0){throw 'Windows build failed'}
 Copy-Item "$out/libsynk_chromaprint.dll","$out/chromaprint/src/libchromaprint.dll" "$repo/assets/native/chromaprint/windows/"
}
