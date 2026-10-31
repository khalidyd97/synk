extends AudioStreamPlayer
# Background music for the menus. It plays on the lobby, Settings, Song details, Results and
# the Chart Studio song list, and fades out for the song list (previews), gameplay, the
# editor and the recorder, then fades back in where it left off.
const TRACK = "res://assets/audio/music/menu_theme.ogg"
const FADE = 1.2      # seconds for a full fade
var game: Control
var level = 0.0       # current fade position, 0..1
var volume = 0.6      # player preference, 0..1

func _ready() -> void:
	var music = load(TRACK) as AudioStreamOggVorbis
	if music: music.loop = true; stream = music
	volume = clampf(float(game.prefs.get_value("audio", "menu_music", 0.6)), 0.0, 1.0)
	volume_db = -80.0
	process_mode = Node.PROCESS_MODE_ALWAYS

# True on screens that should have music.
func ssrg_preview_active() -> bool:
	var browser=game.ssrg_playables
	return browser!=null and browser.is_visible_in_tree() and browser.preview_player!=null and browser.preview_player.playing

func wanted() -> bool:
	if volume <= 0.0 or stream == null: return false
	match str(game.mode):
		"menu":
			if ssrg_preview_active():return true
			# The song list plays song previews, so the theme steps aside there.
			if game.lobby and game.lobby.browser and game.lobby.browser.is_visible_in_tree(): return false
			return true
		"library", "results": return true
	return false

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	game.prefs.set_value("audio", "menu_music", volume); game.prefs.save("user://preferences.cfg")

func _process(delta: float) -> void:
	var target = 1.0 if wanted() else 0.0
	var duck=ssrg_preview_active() and target>0.0
	if duck:target=sqrt(minf(volume,.05)/maxf(volume,.0001))
	level = move_toward(level, target, delta / (.18 if duck else FADE))
	if level > 0.0 and not playing: play()
	stream_paused = level <= 0.0 and target == 0.0
	volume_db = linear_to_db(maxf(.0001, level * level * volume))
