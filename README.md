# SYNK

A playable Unity rhythm-game prototype for Android and iOS, inspired by the supplied neon highway reference. All visuals are procedural; the reference image is a design guide and is not bundled as game art.

## Open and play

1. Install Unity **6000.0.62f1** through Unity Hub with Android Build Support (SDK, NDK, OpenJDK), and iOS Build Support on a Mac.
2. Add this directory as a project in Unity Hub and open it. On first import, the editor creates `Assets/Synk/Scenes/Main.unity` and configures mobile settings.
3. Open Main and press Play. Select **PLAY ECLIPSE**. The original procedural demo runs for approximately 94 seconds.
4. Use landscape orientation. Tap near the glowing judgement line when a note arrives. Hold a ribbon through its tail; follow slide ribbons horizontally; swipe in the direction of a flick arrow. Multitouch is supported. Mouse clicks and drags also work in the editor.

The pause button and Escape pause/resume. Focus loss also pauses. Resume sustained ribbons by touching their current lane. Timing offset is adjustable from -200 to +200 ms; a positive value advances the chart relative to audio. Prefer wired audio when calibrating. Scores and the timing offset persist locally.

## Included

- 13-lane perspective highway, cyan/magenta notes, layered glow, animated background, hit flashes.
- Tap, hold, curved slide and four-direction flick notes.
- DSP-clock scheduling, timing windows of 45/90/160 ms, combo, accuracy, million-point score and rank.
- Start, pause and results screens, personal best, device safe-area HUD.
- Deterministic 96-note demonstration chart and an original synthesized soundtrack.
- Runtime graphics in one batched UI mesh, without external art or shader dependencies.

## Android

Use **SYNK > Build Android APK**, or select Android in Build Profiles and build manually. The setup selects ARM64, IL2CPP and minimum Android API 26. Configure your own application ID, signing keystore and store-required target API in Player Settings before distribution. For Google Play, enable App Bundle in Build Profiles and create a signed AAB. Test timing, touch accuracy, thermals and audio latency on real devices.

## iOS

Open the project on macOS with Unity's iOS module. Use **SYNK > Export iOS Xcode project**. Open the exported project in Xcode, choose your Apple development team and bundle identifier, connect an iPhone, and build. App Store submission requires your certificates/provisioning and Apple developer account. The initial minimum iOS version is 15.

## Make a song

### In-game chart maker

Select **RECORD NEW CHART** from the game menu. After a three-second count-in, the current song plays and your gestures near the judgement line become chart notes. Recording uses the same DSP clock and timing offset as gameplay. Multiple fingers can record simultaneous notes.

- **AUTO**: a short stationary touch records a tap; holding for at least 220 ms records a hold; a longer horizontal drag records a slide; a short swipe records a directional flick.
- **TAP / HOLD / SLIDE / FLICK**: force a note type when an automatic gesture would be ambiguous. Choose the tool before starting the gesture. Slides preserve their sampled path, including turns. Short flicks use touch-down time as the note time.
- **UNDO** removes the latest completed gesture. **STOP** opens a review screen. Pausing, canceled touches and stopping discard unfinished gestures.
- **TEST DRAFT** plays your unsaved chart. From results, **BACK TO DRAFT** returns to review so you can save it afterward.
- **SAVE CHART** saves locally and replaces the previous saved chart for this song. **PLAY SAVED CHART** loads it for gameplay, including after restarting the app. **PLAY ORIGINAL** plays the original chart. **RECORD NEW CHART** clears the current draft; the saved chart stays until explicitly overwritten.

Charts are JSON files under `Application.persistentDataPath/Charts`. Imported songs use a content hash to connect their audio and chart; the demo uses its metadata, duration and audio offset. This version saves one chart per song on each device. Personal bests are tracked separately for each chart. Gesture recording is free-time; timeline edits can snap to beats. Chart sharing is not included.

### Chart Studio: import, seek and edit

Open **CHART STUDIO / IMPORT AUDIO** from the menu, review screen or results.

1. Select **IMPORT AUDIO** and choose an **MP3, WAV or OGG** from the device's file picker (or a file dialog in the Unity Editor). Audio is copied to the app's private `Songs` directory and listed in the scrollable song library. Select it again after restarting to reopen its saved chart. M4A/AAC/DRM audio is not supported; convert it to a supported format first. Files are limited to 150 MB and 20 minutes.
2. Scrub the slider or touch the waveform/timeline to jump through the song. Use **−5s / +5s** and **ZOOM + / −** to find a passage. The yellow line is the playhead; timestamps show the visible section.
3. **PLAY** auditions from the playhead. **SPEED** cycles 1×, 0.75× and 0.5× (pitch changes with speed). **SET A / SET B** and **LOOP ON** repeat a passage; the loop region is highlighted. Looping applies to auditioning, not recording.
4. Tap a note to select it; drag its head to change time and lane. **SNAP** cycles sixteenth, eighth, quarter notes and free timing. **BPM − / +** changes the grid tempo. Set the BPM for your song manually; automatic tempo detection is not included.
5. **TAP / HOLD / SLIDE / FLICK** converts the selected note. **DIRECTION** rotates a flick. **LANE / TIME −/+** makes precise adjustments; **TAIL −/+** resizes a sustain; **END LANE** changes a slide destination and replaces its recorded curve with a smooth path. **ADD**, **DELETE**, **DUPLICATE**, **UNDO** and **REDO** support manual editing. Undo stores whole edit snapshots for this session.
6. **REC HERE** counts in and records from the current position at normal speed. Existing notes remain visible and are kept. **STOP** adds the take to the editor; one undo removes the entire take. You can delete the old notes in a section before recording if you want to replace them.
7. **TEST CHART** plays the entire draft. Reopen Studio from results to continue editing. **SAVE** persists the chart with the song; **CLOSE** returns to gameplay. A `*` marks unsaved edits. Song switching and closing require saving or pressing **RELOAD**, which explicitly discards edits and reloads the saved chart (or original chart).

You can save an empty chart. Timeline note rendering is capped at 1,000 visible notes to keep the UI mesh within Unity limits; zoom in on unusually dense passages. Drafts and undo history are in memory until saved.

Mobile file selection uses the MIT-licensed [Unity Native File Picker](https://github.com/yasirkula/UnityNativeFilePicker), pinned at `f2347e789ccfe35655d2955ca7b4b21123143efd` in the package manifest. Unity Package Manager needs Git and internet access on first import. Its automatic iOS framework and iCloud capability setup is enabled in `ProjectSettings/NativeFilePicker.json`; configure the app's signing and iCloud capability in your Apple developer account/Xcode. The plugin's iOS documentation requires an Apple Developer Program account. The library is local to the device; enabling the picker capability does not sync charts between devices.

Run `powershell -File Tests/RunChartCaptureTests.ps1` to verify the gesture and chart-editing engines without Unity. Tests cover type conversion, deep undo/redo, slide paths, resizing, bounded dragging, snapping, multitouch and recording timestamps. Unity/device testing is still required for file picking, decoding, UI, storage and audio integration.

Create **Assets > Create > SYNK > Beatmap**, assign an AudioClip and enter notes in the inspector. Assign the asset to the Main scene's SYNK Game component. Times and durations are seconds, lanes are zero-based (0–12), and `endLane` controls slide destinations. `audioOffset` shifts the chart's zero point relative to audio. Use chronological charts with positive hold/slide durations and legal lane values. The prototype judges each hold or slide once at completion; it has no sustain tick scoring. Custom audio should extend beyond the final note. Difficulty labels are metadata.

The generated demo is intentionally sparse so it can be learned with a single pointer; production charts can contain simultaneous notes and use multitouch. This is a prototype foundation, with one demo song and no song-selection library, account system, purchases or online leaderboard.

## Verification status

Unity is not installed in the creation environment. Source and project structure were inspected, but Unity compilation, Play Mode and mobile builds have **not** been run. Open the project in Unity to perform those checks before relying on a device build. The first editor import generates Unity metadata and the Main scene; commit those generated assets afterward.
