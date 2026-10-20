extends Node

# Plays the UI sound effects in assets/sfx: recorded sounds from Kenney's CC0 packs
# (Interface, Impact and Sci-fi Sounds; see assets/sfx/CREDITS.txt).
# main.gd adds one instance; buttons reach it through the static helpers below.
const SOUNDS = {
	"click": preload("res://assets/sfx/click.wav"),
	"toggle": preload("res://assets/sfx/toggle.wav"),
	"confirm": preload("res://assets/sfx/confirm.wav"),
	"record": preload("res://assets/sfx/record.wav"),
	"back": preload("res://assets/sfx/back.wav"),
	"danger": preload("res://assets/sfx/danger.wav"),
	"play": preload("res://assets/sfx/play.wav"),
	"transition": preload("res://assets/sfx/transition.wav"),
	"count": preload("res://assets/sfx/count.wav"),
	"go": preload("res://assets/sfx/go.wav"),
	"whoosh": preload("res://assets/sfx/whoosh.wav"),
	"bonus": preload("res://assets/sfx/bonus.wav"),
}
# Each button role in the design system (NeonAction.VARIANTS) has its own sound.
const VARIANT_SOUNDS = {"primary":"confirm","record":"record","secondary":"click","tool":"toggle","danger":"danger","nav":"back"}
const VOLUME_DB = -6.0
const VOICES = 4

var players: Array[AudioStreamPlayer] = []
var next_voice = 0
var last_played: Dictionary = {}

func _ready() -> void:
	add_to_group("ui_sound")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player = AudioStreamPlayer.new(); add_child(player)
		player.volume_db = VOLUME_DB
		players.append(player)

func emit_sound(sound: String) -> void:
	if not SOUNDS.has(sound): return
	# A sound retriggered within 40 ms (e.g. a press that also changes screen) is skipped.
	var now = Time.get_ticks_msec()
	if now - int(last_played.get(sound, -1000)) < 40: return
	last_played[sound] = now
	# Headless runs (tests, exports) have no audio output.
	if DisplayServer.get_name() == "headless": return
	var player = players[next_voice]; next_voice = (next_voice + 1) % VOICES
	player.stream = SOUNDS[sound]
	player.pitch_scale = randf_range(.98, 1.02)
	player.play()

static func play(context: Node, sound: String) -> void:
	if context == null or not context.is_inside_tree(): return
	var node = context.get_tree().get_first_node_in_group("ui_sound")
	if node: node.emit_sound(sound)

static func sound_for(target: BaseButton) -> String:
	if target.has_meta("ui_sound"): return str(target.get_meta("ui_sound"))
	var variant = target.get("variant")
	if variant is String and VARIANT_SOUNDS.has(variant): return VARIANT_SOUNDS[variant]
	return "click"
