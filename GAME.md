# SYNK — Game Guide and Project Reference

SYNK is a neon rhythm game built with Godot 4.7 and GDScript. Play a 13-lane perspective highway, import your own music, record or edit charts, and preview them with Auto Play. The built-in track **Eclipse** is a 96-second synthesized demo at 128 BPM with a sample chart.

This guide describes the game implemented in this repository. The interface is designed for landscape play with touch input, and a mouse for desktop testing. Android uses fullscreen display and respects the device's safe area.

## Start playing

1. Launch SYNK. After the SYNK logo splash, the lobby opens with Eclipse selected.
2. Choose a track in the browser on the right. Use **All**, **Originals**, **Imported**, or search to narrow the list.
3. Select the animated **Play** button. If the song has no chart, its action opens Chart Studio so you can make one.
4. A loading card shows the song's cover, title and a progress bar. The cover then flies down the highway as the camera swoops onto the stage, and a 3–2–1 countdown runs before the music starts: a colored ring drains around each number, three step dots fill in, a tick sounds on each number, and a brighter tone plays as the music starts. Restarting from pause replays only the swoop.
5. Tap, hold, slide, or flick notes as they reach the glowing hit bar.
6. Use the pause button or Escape to pause. **Resume** gives a 3–2–1 countdown; **Restart** begins the run again; **Home** returns to the lobby.

The lobby's bottom row has **Chart Studio**, **Record**, and **Auto Play** next to the large **Play** button, and a **Settings** gear sits in the top-right corner. The selected song's cover art fills the left side as a faded photo with its details on top, over a looping animated background. Chart Studio opens the album-art Chart Library first. Auto Play previews the selected chart without requiring input, and its score is not saved as a personal best.

### Reading the buttons

Every button's look tells you what kind of action it is:

| Look | Role | Examples |
| --- | --- | --- |
| Filled violet-to-pink plate | Main next step on the screen | Play, Save, Create Chart, Import Audio (library) |
| Filled red-to-orange plate | Start or stop recording | Record, Rec Here, Stop |
| Outlined blue plate | Other actions | Auto Play, Chart Studio, Test Chart, Add |
| Rounded lavender chip | Tools and settings; fills in when selected or on | Tap / Hold / Slide / Flick, Snap, Loop, Lines, filter tabs |
| Rounded red chip | Removes or discards work | Delete, Reload |
| See-through plate with ‹ | Moves to another screen | Back, Home, Library, Lobby |

## The highway and notes

Charts use lanes numbered **1–13** in the interface and **0–12** in saved data. Notes approach through a tilted 3D highway. During normal play, the stage omits lane guide lines; recording shows guides to help place notes. The note art and effects use a neon blue, purple, and yellow palette.

| Note | Color | What to do | Judgment |
| --- | --- | --- | --- |
| Tap | Blue | Tap when its head reaches the hit bar. | One judgment at contact. |
| Hold | Purple | Press at the head and keep the finger down to the tail. | Start and end are judged, plus any checkpoint dots on the trail. |
| Slide | Purple | Press at the head and follow the ribbon toward its final lane. | The start and end matter, plus any checkpoint dots; elsewhere the path has generous tracking tolerance. |
| Flick | Yellow | Swipe in the arrow's direction at the hit bar. | One judgment after the correct swipe is detected. |

Flicks support **up, right, and left**. Down flicks are not created by the recorder; older chart data with a down direction is changed to up when loaded for editing or play. In recording, **Auto** recognizes taps, holds, and slides. Select **Flick** explicitly to capture one.

Touches near the hit bar select the nearest eligible note in the corresponding lane. Multitouch supports chords; the recorder aligns different-lane notes made within 60 ms so double taps land together. A mouse can be used for desktop play and editing.

### Scoring and feedback

The four visible judgments are **PERFECT**, **GREAT**, **GOOD**, and **MISS**. For a successful judgment, timing error of up to 45 ms is Perfect, up to 90 ms is Great, and a later valid hit is Good. Tap, hold, and flick starts can be picked up within 160 ms; slides allow up to 230 ms. Scoring value is 1.0, 0.8, or 0.5 for Perfect, Great, or Good, respectively; a miss contributes zero. Hold starts and ends each contribute a judgment. The displayed score scales earned value to **1,000,000** against the chart's possible judgments.

Each successful judgment increases the combo; a miss resets it. The combo uses illustrated digit art, and the latest judgment art stays visible in the center of the highway until another judgment replaces it. Active holds pulse the combo and sustain the hit effect. Flicks have directional effects. Misses give the stage a small shake; failed slides fade to gray instead of vanishing immediately. The score display animates toward its new value.

During play, the score sits in a panel at the top right with a song-progress bar. When the song ends, the results screen shows the cover, your rank, the score counting up (with a **New Best** badge when you beat your record), accuracy, maximum combo, and a Perfect / Great / Good / Miss breakdown, with **Lobby**, **Chart Studio**, and **Retry** buttons. Ranks are **SS** at 98% accuracy, **S** at 95%, **A** at 90%, **B** at 80%, and **C** below 80%. Personal bests are stored only after manual play, keyed to the song and chart content.

## Import music and create a chart

Open **Chart Studio** from the lobby. The Chart Library presents songs as cards with cover art, title, and chart information. Choose a card to edit it, or select **Import Audio** to add a track. Imported songs also appear in the lobby browser. You can drop an audio file onto the desktop game window while in the lobby, library, or editor.

Each card in the Chart Library has a **Delete** chip. It asks first, then **Delete chart** removes the saved notes and keeps the song, and **Delete song** (imported songs only) also removes its audio, cover, section marks and library entry. Deleting Eclipse's chart restores its original chart. Deleting cannot be undone.

Supported audio formats are **MP3, WAV, and OGG Vorbis**. A file must be nonempty, at most **150 MB**, and between **0.2 seconds and 20 minutes** long. SYNK identifies duplicates by SHA-256 hash and keeps a copy in its local library. AAC/M4A and protected audio are not supported. Album art can be set in Studio from a PNG or JPG under **12 MB**, at least **64 × 64 pixels**. It is center-cropped and saved as a 512 × 512 PNG. Songs without custom art use the default cover with a distinct tint.

Song metadata, waveform, chart count, and cover are prepared in the background when the library loads. Selecting a song may briefly show a loading state while audio is decoded, without freezing the lobby. Importing a new file itself still requires reading and copying that file.

### Record a take

1. In Chart Studio, move the playhead to the section you want. Use the waveform, seek slider, **−5s / +5s**, and zoom controls.
2. Press **Rec Here**. Recording starts at the chosen position after a three-second count-in. Earlier notes stay in the chart, so a take can overdub them.
3. Choose **Auto**, **Tap**, **Hold**, **Slide**, or **Flick** at the top of the recording screen. Auto infers tap versus hold versus slide from gesture duration and travel. Choose Flick when you want a directional swipe note.
4. Play near the hit bar while the song runs. Newly recorded notes move up the stage so you can see the take forming. Visible lane guides help aim taps.
5. Use **Undo** for the last note in the current take. Press **Stop** to add the take to Studio. One Studio undo can remove the newly added take.

Touches that are canceled or unfinished when recording stops are discarded. The editor marks unsaved changes with `*` in its title.

### Song info, sections and play modes

In Chart Studio, edit the song's **Title** and **Album** under its cover; changes save when you press Enter or leave the field. The lobby, track list, song intro and results use them.

Mark where **Verse 2** and the **Bridge** begin, either in the recorder with the ◆ Verse 2 / ◆ Bridge buttons (marks the current song time) or in Chart Studio with the same buttons beside the note info (marks the playhead). Pressing a mark again within a quarter second of it clears it. Marks appear on the Studio timeline and are saved with the song immediately.

The lobby's track panel then offers up to four play modes:

| Mode | Plays | Needs |
| --- | --- | --- |
| Full | The whole song | — |
| Verse 1 | Start to Verse 2 | Verse 2 mark |
| Verse 2 | Verse 2 to the Bridge (or the end if there is no Bridge mark) | Verse 2 mark |
| Bridge | Bridge to the end | Bridge mark |

A section starts the music at its mark, uses only the notes inside it, and shows the results once its last note has passed. Personal bests are kept separately for each section. Retry repeats the same section; Test Chart in Studio always plays the full song.

### Arrange on the recording stage

Holds and slides can carry **checkpoint dots**: glowing beads along the trail. When a dot reaches the hit bar, the finger must be over the trail (within two lanes). Each dot passed scores a Perfect and adds to the combo; missing one breaks the hold or slide, which then counts as a miss along with its remaining dots. Held trails shrink into the hit bar as they are played.

Press **Arrange** while recording to pause playback and edit notes directly on the highway. Drag a note **inside** the highway to move it in time and across lanes. Scroll from the area **outside** either highway edge so scrolling is distinct from moving a note. Select a note, then use the type buttons to turn it into a tap, hold, slide, or flick. The first tool changes to **Delete** in Arrange mode. Press **Record** to leave arrangement and continue the take.

To place checkpoint dots, turn on **● Dots** in Arrange mode, select a hold or slide, then tap along its trail to add a dot; tap an existing dot to remove it.

### Edit in Chart Studio

| Control | Purpose |
| --- | --- |
| Waveform, seek slider, zoom, ±5s | Navigate the song and choose an edit or recording point. |
| Play / Pause, Speed | Audition from the playhead at 1×, 0.75×, or 0.5×. Speed also changes pitch. |
| Set A, Set B, Loop | Repeat a section while auditioning. |
| BPM, Snap | Set tempo and place notes on 1/16, 1/8, 1/4, or free timing. |
| Add, Duplicate, Delete | Create, copy, or remove selected notes. Add places a tap in the center lane. |
| Tap, Hold, Slide, Flick | Convert the selected note's type. |
| Direction | Cycle a flick through up, right, and left. |
| Time ±, Lane ± | Move a selected note by a snap unit or one lane. |
| Tail ±, End Lane | Resize a hold or slide, or move a slide destination. |
| Undo, Redo | Traverse up to 100 chart snapshots. |
| Test Chart | Play the current draft from the beginning. |
| Save, Reload | Persist the chart, or discard unsaved edits and reload the saved version. |

Tap a note on the timeline to select it and drag it to change time and lane. Slide paths can contain sampled turns from recording; changing the end lane in Studio resets the saved path to a smooth route. **Save** writes one chart per song, including an empty chart. Unsaved drafts and undo history do not survive a crash or restart. The editor asks you to save or reload before switching songs or closing it.

From the results screen, **Chart Studio** opens the editor, where **Record** starts a fresh chart. A previously saved chart remains on disk until you save over it.

## Settings and audio sync

Open **Settings** with the gear icon at the top right of the lobby. The pause menu contains only the run controls.

| Setting | Range / default | Effect |
| --- | --- | --- |
| Timing offset | −200 to +200 ms / 0 ms | Shifts chart timing relative to the audio clock. |
| Note speed | 0.5× to 3× / 1× | Changes note travel speed without changing music speed or hit timing. |
| Note shape | Circle by default; Rectangle optional | Switches note heads between raised circular pucks and the original bar art. An existing saved choice is preserved. |
| Bluetooth headset mode | Off by default | Enables additional headset delay compensation. |
| Extra headset delay | 0–600 ms / 180 ms | With Bluetooth mode on, compensates for audio heard later through the headset. |

If notes appear to arrive before the sound in Bluetooth headphones, enable headset mode and adjust the extra delay until the hit bar matches what you hear. The game also accounts for the audio output latency reported by Godot. Settings persist between sessions in `user://preferences.cfg`.

## Saved files and chart format

Godot's `user://` directory is the game's persistent per-user storage. On desktop, use **Project → Open User Data Folder** in the Godot editor to find its actual location. On Android, it is inside the app's private data. Copy these files before uninstalling the app if you want to keep your charts.

| Path under `user://` | Contents |
| --- | --- |
| `songs/library.json` | Imported track IDs, titles, album names, filenames, BPM, and Verse 2 / Bridge marks (`verse2`, `bridge` in seconds). |
| `songs/<sha256>.<ext>` | Copied imported audio. |
| `charts/<song-id>.json` | One version-1 chart for a song. |
| `covers/<song-id>.png` | Optional custom album art. |
| `preferences.cfg` | Audio settings, note speed, personal bests, and the built-in Eclipse track's title, album and section marks. |

The chart JSON has `version`, `song_id`, and `notes`. Each note includes `time` in seconds, `lane` (0–12), `kind` (`tap`, `hold`, `slide`, `flick`), `duration` in seconds, `end_lane`, `direction` (0 up, 1 right, 2 down legacy, 3 left), and `path`. A slide path is an array of `{ "offset": seconds_from_note_start, "lane": lane_position }` points. Holds and slides may also have `checkpoints`, an increasing array of offsets in seconds from the note start (each greater than 0 and less than `duration`). Chart loading validates the structure and lane/time ranges. If a saved chart is invalid, SYNK keeps the original file and reports an error. JSON saves first write a temporary file and preserve the previous saved file as `.bak` before replacement.

For example:

```json
{
  "version": 1,
  "song_id": "eclipse",
  "notes": [
    {
      "time": 3.0,
      "lane": 6,
      "kind": "tap",
      "duration": 0.0,
      "end_lane": 6,
      "direction": 0,
      "path": []
    }
  ]
}
```

## Run, test, and export

On this development machine, run **`Play-SYNK.cmd`** to launch the game or **`Open-SYNK.cmd`** to open the project. For another checkout, open `project.godot` in standard Godot **4.7** with the Compatibility renderer and press **F5**. The project entry scene is `scenes/main.tscn`.

From a PowerShell terminal in the project root, with Godot available as `godot`:

```powershell
godot --headless --editor --import --path .
godot --headless --path . --script res://godot_tests/test_core.gd
godot --headless --path . --script res://godot_tests/test_game.gd
```

Export presets are provided for Windows, Android, and iOS. Android uses an ARM64 preset and application ID `com.synkstudio.rhythm`. Install Godot 4.7 export templates and configure the platform SDK and signing settings before making a release build. iOS export requires macOS and Xcode. The repository's `builds/` directory may contain local outputs, but source checkout and export presets are the durable project definition.

## Code and assets

| Location | Responsibility |
| --- | --- |
| `scripts/main.gd` | Game modes, timing, scoring, input, UI, settings, and editor flow. |
| `scripts/lobby.gd` | Lobby, track browser, and animated main actions. |
| `scripts/chart_library.gd` | Cover-art library and import entry point. |
| `scripts/chart.gd` | Note model, slide interpolation, validation, and undo/redo. |
| `scripts/capture.gd` | Touch-gesture recognition for recording. |
| `scripts/library.gd` | Audio import, metadata/waveform preparation, chart persistence, demo audio. |
| `scripts/timeline.gd` | Waveform and timeline editing interaction. |
| `scripts/highway.gd`, `scripts/highway_3d.gd` | Perspective highway, note rendering, hit effects, and stage motion. |
| `scripts/neon_play.gd`, `scripts/neon_action.gd`, `scripts/ui_motion.gd` | Animated game-style buttons and screen transitions. |
| `assets/lobby/`, `assets/hud/`, `assets/neon/` | Lobby covers/background, combo and judgment art, and gameplay textures. |
| `assets/sfx/`, `scripts/ui_sound.gd` | UI sound effects; each button role in the design system has its own sound, and moving between menu screens plays a soft whoosh. `tools/ui_sounds/generate.py` re-synthesizes the WAV files. |
| `assets/brand/synk_logo.png`, `tools/logo/generate_logo.py` | Neon SYNK wordmark used in the lobby and as the launch splash; the script re-renders it with Pillow. |
| `tools/lobby_video/` | Standalone project that renders the looping lobby background video `assets/lobby/lobby_loop.ogv`. |
| `godot_tests/` | Core and scene-level checks. |

The supplied combo art is loaded as an atlas for digits **1–9** plus a separate **0** texture. Judgment images are loaded from `assets/hud/PERFECT.png`, `GREAT.png`, `GOOD.png`, and `MISS.png`. Replacing one of those files with compatible art changes the corresponding in-game graphic after Godot reimports it; the atlas layout for digits 1–9 must stay aligned with the regions selected in `scripts/main.gd`.
