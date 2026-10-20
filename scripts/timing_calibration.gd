extends Control
# Tap-along timing calibration (first launch, and Settings > Audio).
# Plays a generated metronome: 4 lead-in clicks, then 8 clicks to tap along to. Each tap is
# timed on the same clock gameplay uses (audio position + output latency + current offset),
# so the median tap error is exactly how early/late notes would be judged. Saving subtracts it
# from the timing offset (audio/offset_ms).
signal closed
const BPM = 100.0
const LEAD_IN = 4
const MEASURED = 8
const FIRST_BEAT = .6        # seconds into the click track
const RATE = 44100
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
var game: Control
var player: AudioStreamPlayer
var errors: Array = []
var state = "intro"          # intro, running, result
var result_ms = 0.0
var pulse = 0.0
var last_beat = -1
var title: Label
var body: Label
var primary: Button
var secondary: Button
var skip: Button

func beat_time(i: int) -> float: return FIRST_BEAT + i * 60.0 / BPM
func total_beats() -> int: return LEAD_IN + MEASURED

func click_track() -> AudioStreamWAV:
	var length = beat_time(total_beats()) + .6
	var frames = int(length * RATE)
	var data = PackedByteArray(); data.resize(frames * 2)
	for b in total_beats():
		var start = int(beat_time(b) * RATE)
		var freq = 1500.0 if b < LEAD_IN else 1000.0
		for k in int(.035 * RATE):
			var t = float(k) / RATE
			var v = sin(TAU * freq * t) * exp(-t * 90.0) * (.55 if b < LEAD_IN else .8)
			data.encode_s16((start + k) * 2, int(clampf(v, -1, 1) * 32767))
	var wav = AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE; wav.stereo = false; wav.data = data
	return wav

# Same clock as gameplay's chart_time(), applied to the click track.
func clock() -> float:
	var position = player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return position + game.effective_timing_ms() / 1000.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new(); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, .9); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = label(.1, .1, .9, .2, 40); body = label(.15, .2, .85, .34, 20)
	body.add_theme_color_override("font_color", Color("c9c4dd")); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primary = make_button("START", .36, .8, .64, .9, start_test, true)
	secondary = make_button("RETRY", .2, .8, .44, .9, start_test, false)
	skip = make_button("SKIP", .82, .05, .97, .13, close_view, false)
	player = AudioStreamPlayer.new(); add_child(player); player.stream = click_track()
	show_intro()

func label(l: float, t: float, r: float, b: float, size_px: int) -> Label:
	var n = Label.new(); add_child(n)
	n.anchor_left = l; n.anchor_top = t; n.anchor_right = r; n.anchor_bottom = b
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", size_px); n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

func make_button(text_value: String, l: float, t: float, r: float, b: float, callback: Callable, main_action: bool) -> Button:
	var n = preload("res://scripts/settings_action.gd").new(); add_child(n)
	n.text = text_value; n.primary = main_action; n.caption_size = 22
	n.anchor_left = l; n.anchor_top = t; n.anchor_right = r; n.anchor_bottom = b
	n.pressed.connect(callback)
	return n

func show_intro() -> void:
	state = "intro"
	title.text = "Tune your timing"
	body.text = "Use the headphones or speaker you play with. After 4 count-in clicks, tap anywhere on every click (8 taps). It takes about 10 seconds."
	primary.text = "START"; primary.visible = true; secondary.visible = false
	primary.anchor_left = .36; primary.anchor_right = .64

func start_test() -> void:
	errors.clear(); last_beat = -1; state = "running"
	title.text = "Listen…"; body.text = "Tap on each click after the count-in."
	primary.visible = false; secondary.visible = false
	player.play()

func _gui_input(event: InputEvent) -> void:
	if state != "running": return
	var pressed = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed: return
	var now = clock()
	# Nearest measured beat; taps more than 0.25 s away are ignored.
	var best = INF
	for b in range(LEAD_IN, total_beats()):
		var e = now - beat_time(b)
		if absf(e) < absf(best): best = e
	if absf(best) <= .25: errors.append(best)
	pulse = 1.0
	accept_event()

func _process(delta: float) -> void:
	pulse = move_toward(pulse, 0.0, delta * 4.0)
	if state == "running":
		var now = clock()
		var beat = floori((now - FIRST_BEAT) * BPM / 60.0 + .5)
		if beat != last_beat and beat >= 0 and beat < total_beats():
			last_beat = beat
			title.text = "Count-in  %d" % (LEAD_IN - beat) if beat < LEAD_IN else "Tap!   %d / %d" % [beat - LEAD_IN + 1, MEASURED]
		if not player.playing: finish()
	queue_redraw()

func finish() -> void:
	state = "result"
	primary.visible = true; secondary.visible = true
	primary.anchor_left = .56; primary.anchor_right = .8
	if errors.size() < 5:
		title.text = "Not enough taps"
		body.text = "Only %d taps landed near a click. Tap on every click after the count-in, then try again." % errors.size()
		primary.text = "TRY AGAIN"; primary.pressed.disconnect(save_result) if primary.pressed.is_connected(save_result) else null
		if not primary.pressed.is_connected(start_test): primary.pressed.connect(start_test)
		secondary.visible = false; primary.anchor_left = .36; primary.anchor_right = .64
		return
	var sorted = errors.duplicate(); sorted.sort()
	var median = sorted[sorted.size() / 2]
	result_ms = clampf(game.timing_ms - median * 1000.0, -200.0, 200.0)
	var spread = (sorted[-1] - sorted[0]) * 1000.0
	title.text = "Offset  %+d ms" % roundi(result_ms)
	body.text = "You tapped %d ms %s on average (spread %d ms). Saving sets the timing offset to %+d ms; you can fine-tune it later in Settings > Audio." % [
		roundi(absf(median) * 1000.0), "late" if median > 0 else "early", roundi(spread), roundi(result_ms)]
	primary.text = "SAVE"
	if primary.pressed.is_connected(start_test): primary.pressed.disconnect(start_test)
	if not primary.pressed.is_connected(save_result): primary.pressed.connect(save_result)

func save_result() -> void:
	game.change_audio_offset(roundf(result_ms))
	game.tell("Timing offset set to %+d ms." % roundi(result_ms))
	close_view()

func close_view() -> void:
	player.stop()
	game.prefs.set_value("audio", "calibrated", true); game.prefs.save("user://preferences.cfg")
	if game.settings_panel: game.settings_panel.refresh()
	closed.emit(); queue_free()

func _draw() -> void:
	# A ring that pulses on each tap (not on the click, so it never becomes a visual cue).
	var c = size * Vector2(.5, .58); var r = size.y * .12
	draw_arc(c, r * (1.0 + .18 * pulse), 0, TAU, 96, Color(1, .3, .45, .35 + .5 * pulse), 4.0 + 6.0 * pulse, true)
	draw_circle(c, r * .82, Color(1, .2, .35, .12 + .25 * pulse))
	var dots = MEASURED; var gap = size.x * .03
	for i in dots:
		var x = size.x * .5 + (i - (dots - 1) * .5) * gap
		draw_circle(Vector2(x, size.y * .74), size.y * .008, Color(1, 1, 1, .9) if i < errors.size() else Color(1, 1, 1, .2))
