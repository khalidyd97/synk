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

Create **Assets > Create > SYNK > Beatmap**, assign an AudioClip and enter notes in the inspector. Assign the asset to the Main scene's SYNK Game component. Times and durations are seconds, lanes are zero-based (0–12), and `endLane` controls slide destinations. `audioOffset` shifts the chart's zero point relative to audio. Use chronological charts with positive hold/slide durations and legal lane values. The prototype judges each hold or slide once at completion; it has no sustain tick scoring. Custom audio should extend beyond the final note. Difficulty labels are metadata.

The generated demo is intentionally sparse so it can be learned with a single pointer; production charts can contain simultaneous notes and use multitouch. This is a prototype foundation, with one demo song and no song-selection library, account system, purchases or online leaderboard.

## Verification status

Unity is not installed in the creation environment. Source and project structure were inspected, but Unity compilation, Play Mode and mobile builds have **not** been run. Open the project in Unity to perform those checks before relying on a device build. The first editor import generates Unity metadata and the Main scene; commit those generated assets afterward.
