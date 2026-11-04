# Dynamic SSRG Games

SSRG Playables opens Games, then a selected game's song carousel.
The list is data-driven: imported library game assignments plus games explicitly added
with ADD GAME. There is no preset list of empty games. Recognized folder names have optional
friendly names and badge colors. ICON lets the player supply their own game artwork.
Custom games persist in preferences.cfg; icons in user://ssrg_games/.

Imports started inside a game are locked to that selected destination for the whole import
session. Changing game clears the previous idle review plan so sources cannot leak across games.
The scanner, transaction and source retention use the selected game consistently.

Game assignment is stored separately as ssrg_game. Album/artist recognition no longer changes
membership. Legacy songs retain their IDs and are grouped by their old album/folder field until
updated; loading the Games screen does not rewrite any library, charts or drafts.

New selected-game imports use a game-scoped song ID, with the original audio hash retained in
ssrg_import.audio_sha256. Identical audio may exist under multiple games without sharing charts.
Reimporting within the same game finds its existing ID and retains chart/draft protections.
Legacy imports within that game reuse their existing IDs. Existing album metadata is preserved.

Validation: test_ssrg_games.gd checks empty/data-driven lists, selection, custom game persistence,
icons, locked import target, actual scanner/transaction commits, album independence, cross-game
identical audio and safe reimport. Existing import transaction, validation, wizard and scrolling
regressions also apply.
