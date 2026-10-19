# Setting ownership

Global Settings: display/note speed and shape, device timing calibration and Bluetooth compensation, visual effects, song previews, metronome, MR playback preference, recorder speed, ghost guides and alignment guides. These are personal preferences, never chart file data. Recorder/editor quick controls are shortcuts to those preferences or temporary transport tools.

Note size (60–125%) and hold/slide trail width (30–150%) are independent global visual preferences under Settings → Visual Effects. They do not change lane spacing, capture coordinates, hit windows or chart data. Hold and slide trails use the same selected width. Note heads, flick arrows, release rings, recorder ghosts and calibration notes use the selected note size.

Recorder preferences: pre-roll bars, Free/Soft/Strict recording quantization, recording grid subdivision, rhythm-guide subdivision and guide volume are global personal preferences under Settings → Editor Prefs → Recorder Preferences. Session setup exposes shortcuts to the same values.

Song: source audio, title, album, cover. These describe the shared audio asset and apply across its chart versions.

Chart version: notes, BPM, beat-grid offset, Verse 2/Bridge section markers, bookmarks. Stored in `chart_settings` alongside notes in the chart/draft/export file. Edits are dirty, undoable and recoverable. Each version loads its own values. Legacy shared timing/bookmarks are copied as migration defaults; later changes do not alter the legacy song values or other chart versions.

Session only: editor zoom, snap division, playhead, selection, clipboard, audition speed, loop A/B, practice configuration and autoplay choice. These are temporary editing/transport tools, not saved musical chart content.

Recording session: punch boundaries, layer/replace, loop-take bank, recording pass, locked note types, comparison, splice point and provisional take selection. They never enter chart metadata. Settings are frozen at session start so changing next-session setup cannot reinterpret a live take. Keeping a take commits only the resulting notes to the chart draft, with one undo checkpoint for the entire take.

Do not introduce a preference into a broader scope merely for convenient UI access. UI labels and storage must agree. New chart configuration must participate in autosave hashing, recovery, undo/redo and import/export validation.
