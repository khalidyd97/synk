# Validation workflow

- After game code, UI, asset, or export changes, build the Android APK and send it to the connected Samsung's Downloads folder. The user will test it; do not launch or test the game on the phone, or install the APK, unless explicitly asked.
- The known Samsung serial is `RZCW10J7R7A` (SM-A736B); verify that it is connected and authorized before transferring the APK. Use `install-in-samsung.bat` only when installation is explicitly requested.
- Build into a fresh output folder and verify the APK signature. For explicitly requested installations, use `adb install --no-incremental -r` to preserve app data and avoid incremental-install file locks.
- Do not uninstall the app or clear its data. Keep the user's charts and drafts.
- If the phone is offline, disconnected, or unauthorized, complete the build and available desktop checks, attempt a normal ADB reconnect, and report the transfer limitation accurately. Never claim that phone testing passed without doing it.
- GitHub release publishing requires a user request; the standing build-and-phone-test preference does not imply publishing a release.
