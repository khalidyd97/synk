extends Control
const ScreenStyle = preload("res://scripts/screen_style.gd")

# Audio sync helper. A metronome clicks on every beat while notes fall onto a hit line.
# The player moves the delay until each note lands exactly when they hear its click,
# or taps along with the clicks and lets the helper measure the delay for them.
const Action = preload("res://scripts/settings_action.gd")
const SettingsScreen = preload("res://scripts/settings_screen.gd")
const BACKGROUND = preload("res://assets/lobby/city_background.png")
const TEXT = Color("eef0ff")
const MUTED = Color(.8,.82,.95,.6)
const BPM = 100.0
const BEATS_PER_LOOP = 4
const MIX_RATE = 44100
# How many seconds of travel the falling notes show above the hit line.
const LOOKAHEAD = 1.4
const TAPS_NEEDED = 8
const LOOP_PADDING = 1024

var game: Control
var safe_content: Control
var player: AudioStreamPlayer
var lane: Control
var delay_input: SettingsScreen.Stepper
var tap_result_label: Label
var use_tap_button: Button
var taps: Array = []
var flash = 0.0
var last_flash_beat = -1

static func beat_period() -> float: return 60.0/BPM

# One loop of four clicks, the first accented, so playback never drifts from the beat grid.
static func metronome_stream() -> AudioStreamWAV:
	var period = beat_period()
	var frames = int(round(period*BEATS_PER_LOOP*MIX_RATE))
	# Silent padding after the loop end: the mixer's resampler reads a few frames ahead of the
	# loop point, and without it Android's audio thread read past the buffer and crashed.
	var data = PackedByteArray(); data.resize((frames+LOOP_PADDING)*2); data.fill(0)
	for beat in BEATS_PER_LOOP:
		var start = int(round(beat*period*MIX_RATE))
		var pitch = 1760.0 if beat==0 else 1320.0
		for i in int(.045*MIX_RATE):
			var t = float(i)/MIX_RATE
			var sample = sin(TAU*pitch*t)*exp(-t*90.0)*(.9 if beat==0 else .7)
			data.encode_s16((start+i)*2,int(clampf(sample,-1,1)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = MIX_RATE; stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_begin = 0; stream.loop_end = frames
	return stream

# The median of tap errors (tap time minus the scheduled click) is the delay the player hears.
static func measured_delay_ms(errors: Array) -> float:
	if errors.is_empty(): return 0.0
	var sorted = errors.duplicate(); sorted.sort()
	var middle = sorted.size()/2
	var median = sorted[middle] if sorted.size()%2==1 else (sorted[middle-1]+sorted[middle])*.5
	return clampf(median*1000.0,0,600)

func place(node: Control, parent: Control, left: float, top: float, right: float, bottom: float) -> void:
	if parent==self and safe_content!=null: parent=safe_content
	parent.add_child(node)
	node.anchor_left = left; node.anchor_top = top; node.anchor_right = right; node.anchor_bottom = bottom
	node.offset_left = 0; node.offset_top = 0; node.offset_right = 0; node.offset_bottom = 0

func text(parent: Control, value: String, left: float, top: float, right: float, bottom: float, font_size: int, color: Color = TEXT) -> Label:
	var result = Label.new(); place(result,parent,left,top,right,bottom)
	result.text = value; result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func action(parent: Control, caption: String, left: float, top: float, right: float, bottom: float, callback: Callable, variant: String = "tool") -> Button:
	var result=Action.new(); result.text=caption; result.primary=variant=="primary"
	result.caption_size=18 if variant=="tool" else 22
	place(result,parent,left,top,right,bottom); result.pressed.connect(callback)
	return result

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background = TextureRect.new(); place(background,self,0,0,1,1)
	background.texture = BACKGROUND; background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preload("res://scripts/background_motion.gd").attach(background,preload("res://scripts/image_atmosphere.gdshader"))
	var shade = ColorRect.new(); place(shade,self,0,0,1,1); shade.color = Color(0.017,0.017,0.017,.86); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_content=game.safe_parent("SafeSyncControls",self)
	action(self,"‹  BACK",.035,.035,.17,.15,close,"nav")
	text(self,"AUDIO SYNC",.2,.04,.6,.115,42)
	ScreenStyle.rule(self,.035,.965,.18)
	text(self,"Wear your headphones. Change the delay until every note lands on the line exactly when you hear its click.",.2,.11,.93,.17,17,MUTED)

	# The practice lane: notes fall on each beat; tapping it measures the delay.
	lane = Control.new(); place(lane,self,.035,.2,.5,.95)
	lane.mouse_filter = Control.MOUSE_FILTER_STOP
	lane.draw.connect(draw_lane)
	lane.gui_input.connect(lane_input)
	ScreenStyle.glass(self,Rect2(.035,.20,.465,.75),Color("65dfff"),2)

	var panel = Panel.new(); place(panel,self,.53,.2,.965,.95)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.041,0.041,0.041,.84); style.set_corner_radius_all(22)
	style.border_color = Color(.55,.4,.9,.30); style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	text(panel,"HEADSET DELAY",.07,.03,.93,.11,20,Color("bdadff"))
	text(panel,"Notes too early? Raise it. Notes too late? Lower it.",.07,.1,.93,.18,15,MUTED)
	delay_input = SettingsScreen.Stepper.new(0,600,1,game.bluetooth_latency_ms," ms",0)
	place(delay_input,panel,.22,.2,.78,.34)
	delay_input.readout.add_theme_font_size_override("font_size",34)
	action(panel,"−10",.04,.20,.20,.34,func(): delay_input.value -= 10)
	action(panel,"+10",.80,.20,.96,.34,func(): delay_input.value += 10)

	var rule = ColorRect.new(); place(rule,panel,.07,.38,.93,.383); rule.color = Color(1,1,1,.08); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text(panel,"TAP TO MEASURE",.07,.40,.93,.46,16,Color("9b8cff"))
	text(panel,"Tap the lane each time you hear a click. After %d taps the helper suggests a delay." % TAPS_NEEDED,.07,.46,.93,.54,15,MUTED)
	tap_result_label = text(panel,"",.07,.54,.93,.63,20)
	use_tap_button = action(panel,"USE MEASURED DELAY",.07,.65,.6,.79,use_measurement)
	action(panel,"RESET TAPS",.62,.65,.93,.79,reset_taps)
	action(panel,"SAVE",.25,.82,.75,.96,save,"primary")

	player = AudioStreamPlayer.new(); add_child(player)
	player.stream = metronome_stream()
	visibility_changed.connect(func(): if not visible: player.stop())
	refresh_taps()
	move_child(safe_content,get_child_count()-1)

func open() -> void:
	delay_input.value = game.bluetooth_latency_ms
	reset_taps()
	visible = true
	player.play()

func close() -> void:
	player.stop()
	visible = false
	game.close_sync_helper()

func save() -> void:
	# Saving turns headset mode on, since the delay only applies while it is enabled.
	game.bluetooth_toggle.button_pressed = delay_input.value > 0
	game.bluetooth_latency_input.value = delay_input.value
	close()

# Seconds since the loop started, as heard from this device's audio clock.
func clock() -> float:
	if not player.playing: return 0.0
	return maxf(0,player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())

# Where notes are drawn: behind the audio clock by the chosen delay, like the real game.
func visual_time() -> float:
	return clock()-delay_input.value/1000.0

func _process(delta: float) -> void:
	if not visible: return
	var beat = floori(visual_time()/beat_period())
	if beat != last_flash_beat:
		last_flash_beat = beat; flash = 1.0
	flash = maxf(0,flash-delta*4.0)
	lane.queue_redraw()

func lane_input(event: InputEvent) -> void:
	var pressed = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT)
	if not pressed: return
	# Error from the nearest scheduled click, kept in the range of a plausible headset delay.
	var period = beat_period()
	var error = fposmod(clock(),period)
	if error > period-.1: error -= period
	taps.append(error)
	if taps.size() > TAPS_NEEDED*2: taps.pop_front()
	refresh_taps()

func refresh_taps() -> void:
	if taps.size() < TAPS_NEEDED:
		tap_result_label.text = "Taps: %d / %d" % [taps.size(),TAPS_NEEDED]
		use_tap_button.disabled = true
	else:
		tap_result_label.text = "Measured delay: %d ms" % roundi(measured_delay_ms(taps))
		use_tap_button.disabled = false

func use_measurement() -> void:
	if taps.size() >= TAPS_NEEDED: delay_input.value = roundf(measured_delay_ms(taps))

func reset_taps() -> void:
	taps.clear(); refresh_taps()

func draw_lane() -> void:
	var size_value = lane.size
	var bar_y = size_value.y*.82
	# A narrow perspective lane, wider at the bottom like the real highway.
	var top_half = size_value.x*.12; var bottom_half = size_value.x*.42; var center = size_value.x*.5
	var outline = PackedVector2Array([Vector2(center-top_half,0),Vector2(center+top_half,0),Vector2(center+bottom_half,size_value.y),Vector2(center-bottom_half,size_value.y)])
	lane.draw_colored_polygon(outline,Color(0.077,0.077,0.077,.75))
	lane.draw_polyline(PackedVector2Array([outline[0],outline[3]]),Color("38baff"),2.0,true)
	lane.draw_polyline(PackedVector2Array([outline[1],outline[2]]),Color("a36aff"),2.0,true)
	var half_at = func(y: float) -> float: return lerpf(top_half,bottom_half,y/size_value.y)
	var bar_half = half_at.call(bar_y)
	var bar_color = Color(1,1,1,.55).lerp(Color.WHITE,flash)
	lane.draw_rect(Rect2(center-bar_half,bar_y-4-flash*4,bar_half*2,8+flash*8),Color(bar_color,.85))
	# Falling notes: one per beat, at its scheduled click time.
	var now = visual_time(); var period = beat_period()
	var first = ceili((now-.3)/period)
	for k in range(first,first+int(LOOKAHEAD/period)+2):
		var until = k*period-now
		if until > LOOKAHEAD or until < -.25: continue
		# Perspective spacing: notes speed up as they approach the line.
		var depth = clampf(until/LOOKAHEAD,0,1)
		var y = bar_y*(1.0-depth)/(1.0+1.5*depth) if until >= 0 else bar_y-until/LOOKAHEAD*2.5*bar_y
		var half = half_at.call(y)*.55*game.note_size
		var height = lerpf(6,22,y/size_value.y)*game.note_size
		var accent = posmod(k,BEATS_PER_LOOP)==0
		var color = Color("ffd447") if accent else Color("38baff")
		var alpha = 1.0 if until >= 0 else maxf(0,1.0+until*4.0)
		if game.round_notes():
			lane.draw_set_transform(Vector2(center,y),0,Vector2(1,.38))
			lane.draw_circle(Vector2.ZERO,half*.62,Color(color,alpha))
			lane.draw_arc(Vector2.ZERO,half*.58,0,TAU,40,Color(1,1,1,alpha*.85),3.0,true)
			lane.draw_set_transform(Vector2.ZERO)
		else:
			lane.draw_rect(Rect2(center-half,y-height*.5,half*2,height),Color(color,alpha))
			lane.draw_rect(Rect2(center-half,y-height*.5,half*2,height),Color(1,1,1,alpha*.8),false,2.0)
	var font = ThemeDB.fallback_font
	var hint = "TAP HERE ON EACH CLICK"
	var width = font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	lane.draw_string(font,Vector2(center-width*.5,size_value.y*.94),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,1,1,.45))
