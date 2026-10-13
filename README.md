# SYNK — Godot rhythm game

SYNK now runs entirely in **Godot 4.5.1+**, using GDScript and the Compatibility renderer. Unity, C#, Unity Hub and external file-picker packages are no longer required.

## Play

On this development computer, double-click **Play-SYNK.cmd**. It uses the official portable Godot executable downloaded to the ignored `.tools` folder. **Open-SYNK.cmd** opens the editor.

For a fresh GitHub checkout, install standard (non-.NET) [Godot 4.5.1](https://godotengine.org/download/archive/4.5.1-stable/), import **project.godot**, and press **F5**. No project package downloads are required. Launchers also work when `godot` or `godot4` is on PATH.

Choose **PLAY ORIGINAL** for Eclipse, the original synthesized demo. Touch or click near the glowing line when notes arrive. Tap on arrival, hold until the tail ends, follow slide ribbons, and swipe in a flick arrow's direction. Multitouch is supported on phones; mouse input works on desktop. Escape and the pause button pause. Focus loss pauses gameplay and stops editor auditioning. Timing offset and per-chart best scores persist locally.

## Chart Studio

Open **CHART STUDIO / IMPORT AUDIO**.

1. **IMPORT AUDIO** accepts standard MP3, WAV and OGG (up to 150 MB and 20 minutes). Audio is copied into the persistent local library. Select a song after restarting to reopen its saved chart. You can also drop an audio file onto the desktop window. M4A/AAC/DRM audio is not supported.
2. Touch the waveform, scrub the slider, or use **−5s / +5s** to navigate. **ZOOM + / −** changes the visible span. The yellow line is the playhead; the waveform samples the actual decoded track.
3. **PLAY** auditions from the playhead. **SPEED** cycles 1x, 0.75x and 0.5x (pitch changes with speed). Set **A**, set **B** after A, and enable **LOOP** to repeat that section. Loops apply to auditioning, not recording.
4. **REC HERE** counts in for three seconds and records from the chosen position at normal speed. Existing notes remain visible and are kept. **AUTO** distinguishes taps, holds, slides and short flicks; explicit note-type buttons resolve ambiguity. Slides preserve sampled turns. **STOP** adds the take to Studio; one undo removes it. Pausing, canceled touches and stopping discard unfinished gestures.
5. Tap a note head to select it; drag to change time and lane. **SNAP** cycles sixteenth, eighth, quarter notes and free timing. Set BPM manually with the BPM field.
6. **TAP / HOLD / SLIDE / FLICK** converts a selected note. **DIRECTION** rotates a flick. **TIME / LANE −/+** makes precise changes. **TAIL −/+** resizes a sustain and scales recorded slide timing. **END LANE** changes a slide destination and replaces its curve with a smooth path.
7. **ADD**, **DELETE**, **DUPLICATE**, **UNDO**, **REDO**, and **TEST CHART** support manual editing. Testing plays the whole draft; reopen Studio from results to continue. Undo keeps up to 100 snapshots.
8. **SAVE** keeps one chart per song on this device, including empty charts. A `*` marks unsaved edits. **RELOAD** explicitly discards edits. Save or reload before closing Studio, switching songs or quitting. Drafts/undo history are not crash-persistent.

**RECORD NEW** starts a new chart in memory. A saved chart remains until explicitly overwritten. **PLAY SAVED** plays the saved chart. **PLAY ORIGINAL** always uses Eclipse's demo chart; imported tracks use their saved chart.

## Android and iOS

Export presets are included under **Project → Export**. Install matching Godot export templates, configure platform SDK paths, and supply your own bundle IDs/signing credentials.

- **Android:** configure Android SDK and Java SDK in Editor Settings. The preset targets ARM64. Native file selection requires Android 10+; older versions fall back to Godot's browser with storage limitations. Test timing and multitouch on devices.
- **iOS:** export on macOS and build/sign in Xcode with your Apple development team. Godot 4.5 has no built-in native iOS document picker. The preset exposes Documents through Files/iTunes sharing: copy music into **Files → On My iPhone → SYNK**, then choose **IMPORT AUDIO** and select that file in the game's browser. This Files-based workflow replaces the Unity picker's workflow.

Android/iOS binaries have not been built or device-tested. The neon graphics are procedural approximations of the reference, not a pixel-perfect reproduction.

## Data and migration

Songs, JSON charts and preferences live in Godot's `user://` directory. Use **Project → Open User Data Folder** on desktop to inspect it. Content hashes associate imported audio with charts. Saves retain the previous file as `.bak`; invalid charts are rejected without deleting the original.

Unity source/configuration and generated files were preserved locally under the ignored **legacy_unity** folder, and prior Unity code remains in Git history. Unity cache folders may remain locally but are excluded from Godot scanning and Git. Fresh clones contain only the Godot project. Existing Unity-format saved charts are not automatically converted; Godot uses a separate data directory/schema.

## Verification

Validated using the official Godot 4.5.1 executable:

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script godot_tests/test_core.gd
godot --headless --path . --script godot_tests/test_game.gd
```

Core tests cover gesture types, multitouch, slide turns, conversion, snapping, deep undo/redo, resizing, JSON persistence, runtime WAV import and library reopening. Scene tests cover startup, scoring, flick release, waveform decoding, recording from a chosen section, overdubbing and inspector updates. Desktop rendering is verified separately. Mobile testing remains necessary.

Godot references: [runtime audio loading](https://docs.godotengine.org/en/4.5/tutorials/io/runtime_file_loading_and_saving.html), [native FileDialog support](https://docs.godotengine.org/en/4.5/classes/class_filedialog.html), [iOS Files access](https://docs.godotengine.org/en/4.5/classes/class_editorexportplatformios.html).
