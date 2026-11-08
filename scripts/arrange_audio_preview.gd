extends Node

const SEEK_INTERVAL = 0.05
const GRAIN_SECONDS = 0.14
var game: Control
var player = AudioStreamPlayer.new()
var pending = false
var target = 0.0
var cooldown = 0.0
var remaining = 0.0
var seeks = 0
var playback_target = 0.0
func _ready() -> void :
	add_child(player)
# Correct mode is silent: moving or selecting notes no longer plays audio snippets.
const ENABLED = false
func request(chart_time: float) -> void :
	if not ENABLED or game.mode != "record" or not game.arranging or game.audio.stream == null: return
	target = clampf(chart_time - game.effective_timing_ms() / 1000.0, 0, maxf(0, game.length() - 0.02))
	pending = true;remaining = GRAIN_SECONDS
func stop() -> void :
	player.stop();pending = false;remaining = 0;cooldown = 0
func _process(delta: float) -> void :
	if game.mode != "record" or not game.arranging:
		if player.playing or pending: stop()
		return
	cooldown = maxf(0, cooldown - delta)
	remaining = maxf(0, remaining - delta)
	if pending and cooldown <= 0:
		player.bus = game.audio.bus;player.volume_db = game.audio.volume_db
		player.pitch_scale = game.record_speed
		if player.stream != game.audio.stream: player.stream = game.audio.stream
		if not player.playing: player.play(target);seeks += 1
		elif absf(player.get_playback_position() - target) > 0.025: player.seek(target);seeks += 1
		playback_target = target;pending = false;cooldown = SEEK_INTERVAL
	if remaining <= 0 and player.playing: player.stop()
