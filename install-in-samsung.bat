@echo off
setlocal EnableExtensions DisableDelayedExpansion
title SYNK - Build and install on Samsung

rem Double-click to build and update SYNK without removing app data.
rem Run install-in-samsung.bat --check for a tools/device check only.
rem Each run signs a fresh file; streamed installs avoid incremental APK locks.
set "GAME_DIR=%~dp0"
set "GODOT=%GAME_DIR%.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
set "ADB=D:\Android\sdk\platform-tools\adb.exe"
set "APKSIGNER=D:\Android\sdk\build-tools\36.1.0\apksigner.bat"
set "BUILD_LOG=%GAME_DIR%.tools\samsung-install-build.log"
set "DEVICE_LIST=%GAME_DIR%.tools\samsung-install-devices.txt"
set "MAKER_FILE=%GAME_DIR%.tools\samsung-install-manufacturer.txt"
set "CHECK_ONLY=0"
set "RESULT=1"
set "NO_PAUSE=0"
if /i "%~1"=="--no-pause" set "NO_PAUSE=1"
if /i "%~1"=="--check" set "CHECK_ONLY=1"

pushd "%GAME_DIR%"
if errorlevel 1 exit /b 1

echo.
echo SYNK - Samsung installer
echo ========================
if not exist "%GODOT%" (
    echo ERROR: Godot was not found at:
    echo "%GODOT%"
    goto finish
)
if not exist "%ADB%" (
    echo ERROR: Android platform tools were not found at:
    echo "%ADB%"
    goto finish
)
if not exist "%APKSIGNER%" (
    echo ERROR: Android APK signature verifier was not found:
    echo "%APKSIGNER%"
    goto finish
)
if not exist "%GAME_DIR%project.godot" (
    echo ERROR: Keep this script in the SYNK game folder beside project.godot.
    goto finish
)

echo Checking the USB connection...
"%ADB%" start-server
if errorlevel 1 goto adb_failed
"%ADB%" devices > "%DEVICE_LIST%"
if errorlevel 1 goto adb_failed
set "SAMSUNG_COUNT=0"
set "PHONE_SERIAL="
for /f "usebackq skip=1 tokens=1,2" %%A in ("%DEVICE_LIST%") do if "%%B"=="device" call :check_samsung "%%A"

if "%SAMSUNG_COUNT%"=="0" (
    echo.
    type "%DEVICE_LIST%"
    echo ERROR: No authorized Samsung phone was found.
    echo Connect your phone with a USB data cable and unlock it.
    echo Enable Developer options and USB debugging, then accept
    echo the Allow USB debugging prompt on the phone and run this again.
    goto finish
)
if not "%SAMSUNG_COUNT%"=="1" (
    echo ERROR: More than one Samsung is connected.
    echo Disconnect the other Samsung devices and run this again.
    goto finish
)
echo Samsung connected: %PHONE_SERIAL%

if "%CHECK_ONLY%"=="1" (
    echo Tools and device check passed. No build or installation was performed.
    set "RESULT=0"
    goto finish
)

:new_build_folder
set "RUN_DIR=%GAME_DIR%builds\android\samsung\run-%RANDOM%-%RANDOM%"
if exist "%RUN_DIR%" goto new_build_folder
mkdir "%RUN_DIR%"
if errorlevel 1 goto folder_failed
set "APK=%RUN_DIR%\SYNK.apk"
set "BUILD_LOG=%RUN_DIR%\build.log"
echo.
echo Building the latest Android APK. Please wait...
echo Build log: "%BUILD_LOG%"
"%GODOT%" --headless --path "%CD%" --export-debug Android "%APK%" > "%BUILD_LOG%" 2>&1
if errorlevel 1 goto build_failed
rem Reject script/export failures and stale APKs even if Godot returns zero.
findstr /l /c:"SCRIPT ERROR" /c:"Parse Error" /c:"Failed to export" /c:"Project export for preset" /c:"returned with error" "%BUILD_LOG%" >nul
if not errorlevel 1 goto build_failed
if not exist "%APK%" goto build_failed
echo Verifying the signed APK...
call "%APKSIGNER%" verify --verbose "%APK%" >> "%BUILD_LOG%" 2>&1
if errorlevel 1 goto build_failed

echo.
echo Installing SYNK on %PHONE_SERIAL%...
echo Existing charts and app data will be preserved.
"%ADB%" -s "%PHONE_SERIAL%" install --no-incremental -r "%APK%"
if errorlevel 1 goto install_failed
"%ADB%" -s "%PHONE_SERIAL%" shell pm path com.synkstudio.rhythm
if errorlevel 1 goto install_failed
echo.
echo SUCCESS: SYNK is installed. Open it on your Samsung.
echo Signed APK: "%APK%"
set "RESULT=0"
goto finish

:check_samsung
"%ADB%" -s "%~1" shell getprop ro.product.manufacturer > "%MAKER_FILE%" 2>nul
findstr /i /x /c:"samsung" "%MAKER_FILE%" >nul
if errorlevel 1 exit /b
set /a SAMSUNG_COUNT+=1 >nul
set "PHONE_SERIAL=%~1"
exit /b

:folder_failed
echo ERROR: Could not create a fresh APK build folder.
goto finish

:adb_failed
echo ERROR: Could not communicate with Android Debug Bridge.
goto finish

:build_failed
echo.
echo ERROR: APK build failed. Nothing was installed.
type "%BUILD_LOG%"
goto finish

:install_failed
echo.
echo ERROR: Installation failed. Check the phone for an approval prompt.
echo If Android reports a signing mismatch, stop and check the signing key.
echo This script will never uninstall SYNK or delete your charts.
goto finish

:finish
echo.
if "%CHECK_ONLY%"=="0" if "%NO_PAUSE%"=="0" pause
popd
exit /b %RESULT%
