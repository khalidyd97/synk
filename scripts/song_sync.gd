extends Control
const ScreenStyle = preload("res://scripts/screen_style.gd")

# Song sync: the built-in Eclipse track plays on the real highway with auto play, one note
# on every kick drum. The player moves the headset delay until the hit flashes land on the
# kicks they hear, or taps along by ear and lets the screen measure the delay.
const Action = preload("res://scripts/settings_action.gd")
const TEXT = Color("eef0ff")
const MUTED = Color(.8,.82,.95,.65)
const EARLY = Color("65dcff")
const LATE = Color("ff82d2")
# Eclipse (SynkLibrary.synth_demo) has a kick exactly on every beat at 128 BPM from 0 s.
const BPM = 128.0
const FIRST_BEAT = 8
const LAST_TIME = 92.0
const LANES = [2,4,5,7,6,3]
const TAPS_NEEDED = 8
# Tap errors beyond this are treated as missed beats and ignored.
const TAP_WINDOW = .2

var game: Control
var active = false
var previous: Dictionary = {}
var taps: Array = []
var last_tap_usec = -1000000
var delay_label: Label
var hint_label: Label
var tap_label: Label
var use_button: Button
var meter: Control

static func beat_period() -> float: return 60.0/BPM

static func sync_notes() -> Array:
	var notes: Array=[]
	var beat=FIRST_BEAT
	while beat*beat_period()<LAST_TIME:
		notes.append(SynkChart.note(beat*beat_period(),LANES[beat%LANES.size()]))
		beat+=1
	return notes

# The middle tap error, in seconds. Positive means the beat was heard late.
static func median(values: Array) -> float:
	if values.is_empty(): return 0.0
	var sorted=values.duplicate(); sorted.sort()
	var middle=sorted.size()/2
	return sorted[middle] if sorted.size()%2==1 else (sorted[middle-1]+sorted[middle])*.5

static func stable(values: Array) -> bool:
	if values.size()<TAPS_NEEDED: return false
	var center=median(values)
	var spread: Array=[]
	for value in values: spread.append(absf(float(value)-center))
	return median(spread)<=.035

func place(node: Control,parent: Control,left: float,top: float,right: float,bottom: float) -> void:
	parent.add_child(node)
	node.anchor_left=left; node.anchor_top=top; node.anchor_right=right; node.anchor_bottom=bottom
	node.offset_left=0; node.offset_top=0; node.offset_right=0; node.offset_bottom=0

func text(parent: Control,value: String,left: float,top: float,right: float,bottom: float,font_size: int,color: Color=TEXT) -> Label:
	var result=Label.new(); place(result,parent,left,top,right,bottom)
	result.text=value; result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func action(parent: Control,caption: String,left: float,top: float,right: float,bottom: float,callback: Callable,primary: bool=false) -> Button:
	var result=Action.new(); result.text=caption; result.primary=primary; result.caption_size=18
	place(result,parent,left,top,right,bottom); result.pressed.connect(callback)
	return result

func card(parent: Control,left: float,top: float,right: float,bottom: float) -> Panel:
	var panel=Panel.new(); place(panel,parent,left,top,right,bottom)
	var style=StyleBoxFlat.new(); style.bg_color=Color(.03,.03,.04,.82); style.set_corner_radius_all(20)
	style.border_color=Color(.55,.45,1,.35); style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	return panel

func _ready() -> void:
	# Taps anywhere outside the panels measure the delay; the highway itself ignores input in auto play.
	mouse_filter=Control.MOUSE_FILTER_STOP
	gui_input.connect(tap_input)
	var safe=game.safe_parent("SafeSongSync",self)
	var left=card(safe,.015,.03,.255,.72)
	text(left,"HEADSET DELAY",.05,.02,.95,.11,17,Color("bdadff"))
	delay_label=text(left,"",.05,.11,.95,.27,40)
	action(left,"−10",.05,.29,.48,.42,func(): nudge(-10))
	action(left,"+10",.52,.29,.95,.42,func(): nudge(10))
	action(left,"−1",.05,.44,.48,.57,func(): nudge(-1))
	action(left,"+1",.52,.44,.95,.57,func(): nudge(1))
	hint_label=text(left,"Watch the hit flashes and listen to the kick drum.\nFlash BEFORE the kick: raise the delay.\nFlash AFTER the kick: lower it.",.05,.59,.95,.98,14,MUTED)

	var right=card(safe,.745,.03,.985,.72)
	text(right,"OR TAP BY EAR",.05,.02,.95,.11,17,Color("bdadff"))
	text(right,"Close your eyes and tap anywhere on each kick you hear.",.05,.11,.95,.25,14,MUTED)
	meter=Control.new(); place(meter,right,.06,.27,.94,.45); meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter.draw.connect(draw_meter)
	tap_label=text(right,"",.05,.46,.95,.6,16)
	use_button=action(right,"USE THIS DELAY",.06,.62,.94,.77,use_measurement)
	action(right,"RESET TAPS",.06,.8,.94,.93,reset_taps)

	var bottom=card(safe,.015,.76,.255,.97)
	action(bottom,"CANCEL",.06,.15,.47,.85,func(): finish(false))
	action(bottom,"SAVE",.53,.15,.94,.85,func(): finish(true),true)
	visible=false

func begin() -> void:
	previous={"song":game.song,"stream":game.audio.stream,"bluetooth_mode":game.bluetooth_mode,"latency":game.bluetooth_latency_ms}
	active=true; reset_taps()
	# Headset mode must be on for the delay to apply while it is being tuned.
	if not game.bluetooth_mode: game.change_bluetooth_mode(true)
	game.apply_song(game.eclipse_song(),game.demo_stream)
	game.start_game(sync_notes(),true)
	refresh(); visible=true

# The song ran out: start it again so tuning can continue.
func restart() -> void:
	game.start_game(sync_notes(),true)

func finish(save: bool) -> void:
	if not active: return
	active=false; visible=false
	if not save:
		game.change_bluetooth_latency(float(previous.latency))
		if game.bluetooth_mode!=bool(previous.bluetooth_mode): game.change_bluetooth_mode(bool(previous.bluetooth_mode))
	elif game.bluetooth_latency_ms<=0 and game.bluetooth_mode: game.change_bluetooth_mode(false)
	game.end_song_sync(previous.song,previous.stream)

func nudge(amount: float) -> void:
	set_delay(game.bluetooth_latency_ms+amount)

func set_delay(value: float) -> void:
	game.change_bluetooth_latency(clampf(roundf(value),0,600))
	refresh()

func tap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device==-1: return
	var pressed=(event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT)
	if not pressed or game.mode!="play" or game.countdown>0: return
	var now=Time.get_ticks_usec()
	if now-last_tap_usec<180000: return
	last_tap_usec=now
	# Error from the nearest kick on the chart clock (which already includes the current delay).
	var time=game.chart_time()
	var error=time-roundf(time/beat_period())*beat_period()
	if absf(error)>TAP_WINDOW: return
	taps.append(error)
	if taps.size()>TAPS_NEEDED*2: taps.pop_front()
	refresh()

func use_measurement() -> void:
	if not stable(taps): return
	set_delay(game.bluetooth_latency_ms+median(taps)*1000.0)
	reset_taps()
	tap_label.text="Delay updated. Tap again to check it."

func reset_taps() -> void:
	taps.clear(); last_tap_usec=-1000000
	if tap_label: refresh()

func refresh() -> void:
	delay_label.text="%d ms" % roundi(game.bluetooth_latency_ms)
	if taps.size()<TAPS_NEEDED:
		tap_label.text="Taps: %d / %d" % [taps.size(),TAPS_NEEDED]
	elif stable(taps):
		var change=median(taps)*1000.0
		tap_label.text="You hear the beat %d ms %s.\nSuggested delay: %d ms" % [roundi(absf(change)),"late" if change>0 else "early",roundi(clampf(game.bluetooth_latency_ms+change,0,600))]
	else:
		tap_label.text="Keep tapping steadily…"
	use_button.disabled=not stable(taps)
	meter.queue_redraw()

# Early | on time | late, with a dot per tap and a bar at the middle tap.
func draw_meter() -> void:
	var size_value=meter.size
	var middle=size_value.y*.5
	meter.draw_rect(Rect2(0,middle-3,size_value.x,6),Color(1,1,1,.12))
	meter.draw_rect(Rect2(size_value.x*.5-1.5,middle-size_value.y*.38,3,size_value.y*.76),Color(1,1,1,.7))
	var font=preload("res://scripts/arcade_style.gd").sans(600)
	meter.draw_string(font,Vector2(0,size_value.y-2),"EARLY",HORIZONTAL_ALIGNMENT_LEFT,-1,12,EARLY)
	meter.draw_string(font,Vector2(size_value.x-34,size_value.y-2),"LATE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,LATE)
	var x_for=func(error: float) -> float: return size_value.x*(.5+clampf(error/TAP_WINDOW,-1,1)*.5)
	for i in taps.size():
		var error=float(taps[i])
		var fresh=float(i+1)/taps.size()
		meter.draw_circle(Vector2(x_for.call(error),middle),5,Color(EARLY if error<0 else LATE,.35+.65*fresh))
	if taps.size()>=3:
		var center=median(taps)
		meter.draw_rect(Rect2(x_for.call(center)-2.5,middle-size_value.y*.3,5,size_value.y*.6),Color("ffd447"))

func _process(_delta: float) -> void:
	if active and visible and game.bluetooth_latency_ms!=float(delay_label.text.to_int()): refresh()
