# Music recognition

Song Details → RECOGNIZE SONG uses Chromaprint 1.6.2 and AcoustID, with optional AudD fallback.
Available from the studio song list and SSRG's DETAILS button on Android arm64 and Windows x64.

Register a non-commercial application at https://acoustid.org/new-application and enter its
application API key. A user/submission API key is different and cannot authorize lookups.
Keys stay in user://recognition.cfg on the device; they are not bundled in exports.
An optional AudD token enables fallback. Leave it blank to disable fallback. AudD account
allowances/pricing apply; see https://audd.io/pricing/.
The free AcoustID service permits non-commercial use and at most three requests per second.
SYNK allows one lookup at a time, with at least one second between recognition starts.

SYNK decodes up to the first 120 seconds on a worker thread and fingerprints locally.
Only the fingerprint, whole-file duration and lookup parameters are sent over HTTPS.
No audio is sent to AcoustID, and no database submissions are made.
If AcoustID returns no confident match and an AudD token is configured, SYNK makes one
AudD request with a 12-second mono WAV excerpt, starting up to 24 seconds into the file.
A successful AcoustID match, invalid key, network error or cancellation never triggers AudD.
The dialog explains the fallback upload before recognition; progress identifies each service.
MusicBrainz metadata and optional Cover Art Archive artwork populate editable fields.
Weak matches are rejected. Missing fields or artwork preserve existing values.
Review and press SAVE to apply; CANCEL leaves the song unchanged.
Closing Song Details cancels requests and discards late responses.
Charts, drafts, timing, BPM and imported audio are unchanged.

Native build: tools/chromaprint/build.ps1. Dependency URLs and hashes are pinned in
 tools/chromaprint/dependencies.json. Android requires NDK 28.2.13676358; Windows uses
LLVM-MinGW. Chromaprint is dynamically linked so the LGPL library can be replaced.
Bundled notices, LGPL text and full corresponding Chromaprint/KissFFT source archives
are in assets/native/chromaprint. Godot-cpp is MIT licensed.

Validation: godot_tests/test_music_recognition.gd covers native fingerprint generation,
actual fingerprint-only HTTP requests to a local mock, review/save/cancel, SSRG navigation,
weak/no-match/error responses, MusicBrainz/cover mapping and cancellation.
godot_tests/test_music_recognition_fallback.gd covers conditional routing, bounded audio
upload, primary success, weak/no matches, service errors, disabled fallback and cancellation.
Live fallback was verified using the supplied 1004.a.bytes.ogg: AcoustID no match, then
AudD returned Very Nice / Seventeen. Live recognition needs valid provider credentials.
