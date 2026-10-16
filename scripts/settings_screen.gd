extends Control

# Full-page settings opened from the lobby gear. BACK returns to the lobby.
const NeonAction = preload("res://scripts/neon_action.gd")
const ScreenStyle = preload("res://scripts/screen_style.gd")
const BACKGROUND = preload("res://assets/lobby/city_background.png")
const TEXT = Color("eef0ff")
const MUTED = Color(0.8,0.82,0.95,.78)
const ACCENT = Color("9b8cff")

var game: Control
var note_speed_input: Stepper
var highway_angle_input: Stepper
var timing_input: Stepper
var bluetooth_toggle: Switch
var bluetooth_latency_input: Stepper
var song_preview_toggle: Switch
var metronome_toggle: Switch
var shape_tiles: Dictionary = {}

# A − value + control. Setting `value` (in code or with the buttons) emits value_changed.
class Stepper extends Control:
	signal value_changed(value: float)
	var min_value = 0.0
	var max_value = 1.0
	var step = 1.0
	var suffix = ""
	var decimals = 0
	var minus: Button
	var plus: Button
	var readout: Label
	var _value = 0.0
	var value: float:
		get: return _value
		set(v):
			v = clampf(snappedf(v,step),min_value,max_value)
			var changed = not is_equal_approx(v,_value)
			_value = v; refresh()
			if changed: value_changed.emit(v)
	var editable = true:
		set(v): editable = v; modulate.a = 1.0 if v else .35; refresh()

	func _init(low: float, high: float, increment: float, start: float, unit: String, places: int) -> void:
		min_value = low; max_value = high; step = increment; suffix = unit; decimals = places; _value = start
		mouse_filter = Control.MOUSE_FILTER_PASS
		minus = NeonAction.new(); minus.caption_text = "−"; minus.variant = "tool"; minus.compact = true; minus.caption_size = 26
		plus = NeonAction.new(); plus.caption_text = "+"; plus.variant = "tool"; plus.compact = true; plus.caption_size = 26
		readout = Label.new(); readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		readout.add_theme_font_size_override("font_size",24); readout.add_theme_color_override("font_color",TEXT)
		var value_style=StyleBoxFlat.new(); value_style.bg_color=Color("0a1025")
		value_style.corner_radius_top_left=6; value_style.corner_radius_bottom_right=6; value_style.border_color=Color("4a3d70"); value_style.set_border_width_all(1)
		readout.add_theme_stylebox_override("normal",value_style)
		for node in [minus,readout,plus]: add_child(node)
		anchor(minus,0,.24); anchor(readout,.26,.74); anchor(plus,.76,1)
		minus.pressed.connect(func(): if editable: value -= step)
		plus.pressed.connect(func(): if editable: value += step)
		refresh()

	func anchor(node: Control, left: float, right: float) -> void:
		node.anchor_left = left; node.anchor_right = right; node.anchor_top = 0; node.anchor_bottom = 1
		node.offset_left = 0; node.offset_right = 0; node.offset_top = 0; node.offset_bottom = 0

	func refresh() -> void:
		if readout == null: return
		readout.text = (("%." + str(decimals) + "f") % _value) + suffix
		minus.disabled = not editable or _value <= min_value
		plus.disabled = not editable or _value >= max_value

# An on/off switch. Uses Button's toggle mode, so button_pressed and toggled work as usual.
class Switch extends Button:
	var knob = 0.0
	func _init() -> void:
		toggle_mode = true; focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		toggled.connect(func(_on): queue_redraw())
	func _process(delta: float) -> void:
		var target = 1.0 if button_pressed else 0.0
		if not is_equal_approx(knob,target):
			knob = move_toward(knob,target,delta*7.0); queue_redraw()
	func _draw() -> void:
		var h=size.y; var w=minf(size.x,h*2.1); var x=size.x-w
		var tint=Color("64708f").lerp(Color("65dcff"),knob)
		var points=PackedVector2Array([Vector2(x+8,0),Vector2(size.x,0),Vector2(size.x-8,h),Vector2(x,h)])
		draw_colored_polygon(points,Color("14243c").lerp(Color("174963"),knob))
		var border=points.duplicate(); border.append(points[0]); draw_polyline(border,tint,2,true)
		var font=ThemeDB.fallback_font; var caption="ON" if button_pressed else "OFF"
		var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_string(font,Vector2(x+(w-width)*.5,h*.5+6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,tint)
		draw_line(Vector2(x+14,h-6),Vector2(x+14+(w-28)*knob,h-6),Color("65dcff"),3,true)

# A selectable tile previewing a note shape.
class ShapeTile extends Button:
	var shape = "rectangle"
	var selected = false:
		set(v): selected = v; queue_redraw()
	func _init(kind: String) -> void:
		shape = kind; focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	func _draw() -> void:
		var style = StyleBoxFlat.new(); style.corner_radius_top_left=12; style.corner_radius_bottom_right=12
		style.bg_color = Color(.55,.45,1.0,.22) if selected else Color(1,1,1,.05)
		style.border_color = Color("b9a6ff") if selected else Color(1,1,1,.14)
		style.set_border_width_all(2 if selected else 1)
		draw_style_box(style,Rect2(Vector2.ZERO,size))
		var center = Vector2(size.x*.5,size.y*.42)
		var tint = Color("38baff")
		if shape == "circle":
			# Preview the raised puck and white/cyan rim used on the highway.
			draw_set_transform(center,0,Vector2(1,.42))
			var r = size.x*.25
			draw_circle(Vector2.ZERO,r*1.18,Color(tint,.14))
			draw_circle(Vector2(0,r*.20),r,Color("063a9c"))
			draw_arc(Vector2(0,r*.20),r*.96,0,TAU,48,Color(tint,.9),r*.045,true)
			draw_circle(Vector2.ZERO,r,Color("0750cf"))
			draw_arc(Vector2.ZERO,r*.89,0,TAU,48,Color(tint,.8),r*.095,true)
			draw_arc(Vector2.ZERO,r*.94,0,TAU,48,Color.WHITE,r*.055,true)
			draw_set_transform(Vector2.ZERO)
		else:
			var bar = Rect2(center-Vector2(size.x*.3,size.y*.08),Vector2(size.x*.6,size.y*.16))
			var glow = StyleBoxFlat.new(); glow.set_corner_radius_all(int(bar.size.y*.5)); glow.bg_color = Color(tint,.18)
			draw_style_box(glow,bar.grow(size.y*.04))
			var body = StyleBoxFlat.new(); body.set_corner_radius_all(int(bar.size.y*.35)); body.bg_color = tint.lerp(Color.WHITE,.25)
			body.border_color = Color.WHITE; body.set_border_width_all(2)
			draw_style_box(body,bar)
		var font = ThemeDB.fallback_font
		var caption = shape.to_upper()
		var font_size = 18
		var width = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,Vector2((size.x-width)*.5,size.y*.86),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE if selected else Color(1,1,1,.65))

func place(node: Control, parent: Control, left: float, top: float, right: float, bottom: float) -> void:
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

func card(title: String, left: float, right: float) -> Panel:
	var result = Panel.new(); place(result,self,left,.2,right,.94)
	var style = StyleBoxFlat.new(); style.bg_color = Color(.025,.03,.09,.84); style.set_corner_radius_all(22)
	style.border_color = Color(.6,.48,.9,.28); style.set_border_width_all(1)
	style.shadow_color=Color(0,0,.02,.3); style.shadow_size=18
	result.add_theme_stylebox_override("panel",style)
	ScreenStyle.chassis(result,Color("9b8cff"))
	text(result,title,.06,.03,.94,.12,20,ACCENT.lightened(.25))
	var rule = ColorRect.new(); place(rule,result,.06,.125,.94,.128); rule.color = Color(1,1,1,.08); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func row_label(parent: Control, title: String, hint: String, top: float, bottom: float) -> void:
	var middle = (top+bottom)*.5
	text(parent,title,.06,top,.52,middle+.005,22)
	text(parent,hint,.06,middle-.005,.55,bottom,15,MUTED)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background = TextureRect.new(); place(background,self,0,0,1,1)
	background.texture = BACKGROUND; background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade = ColorRect.new(); place(shade,self,0,0,1,1); shade.color = Color(.01,.01,.04,.82); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back = NeonAction.new(); back.caption_text = "‹  BACK"; back.variant = "nav"; back.compact = true; back.caption_size = 18
	place(back,self,.035,.055,.17,.13); back.pressed.connect(func(): game.close_lobby_settings())
	text(self,"SETTINGS",.2,.04,.6,.115,42)
	var effects_button=NeonAction.new(); effects_button.caption_text="VISUAL EFFECTS"; effects_button.variant="tool"; effects_button.compact=true; effects_button.caption_size=17
	place(effects_button,self,.805,.055,.965,.13)
	var editor_button=NeonAction.new(); editor_button.caption_text="EDITOR PREFS"; editor_button.variant="tool"; editor_button.compact=true; editor_button.caption_size=17
	place(editor_button,self,.63,.055,.79,.13)
	editor_button.pressed.connect(func(): game.features.open_tools("Authoring"))
	effects_button.pressed.connect(func(): game.features.open_tools("Effects"))
	text(self,"Tune gameplay and sync. Changes save right away.",.2,.11,.7,.16,17,MUTED)
	ScreenStyle.rule(self,.035,.965,.18)

	var gameplay = card("GAME & EDITOR",.035,.49)
	row_label(gameplay,"Note speed","How fast notes travel. Music and timing stay the same.",.13,.27)
	note_speed_input = Stepper.new(.5,3.0,.25,game.note_speed,"×",2); place(note_speed_input,gameplay,.58,.15,.94,.25)
	note_speed_input.value_changed.connect(game.change_note_speed)
	row_label(gameplay,"Highway angle","Lower lies flatter and shows more ahead; higher looks down.",.28,.42)
	highway_angle_input = Stepper.new(18,44,2,game.highway_angle,"°",0); place(highway_angle_input,gameplay,.58,.30,.94,.40)
	highway_angle_input.value_changed.connect(game.change_highway_angle)
	row_label(gameplay,"Note shape","Pick how notes look on the highway.",.42,.53)
	for i in 2:
		var kind = ["rectangle","circle"][i]
		var tile = ShapeTile.new(kind); place(tile,gameplay,.06+i*.45,.535,.49+i*.45,.70)
		tile.pressed.connect(func(): game.change_note_shape(kind))
		shape_tiles[kind] = tile
	row_label(gameplay,"Song previews","Play a short preview while browsing songs.",.72,.84)
	song_preview_toggle=Switch.new(); place(song_preview_toggle,gameplay,.76,.745,.94,.825)
	song_preview_toggle.button_pressed=game.lobby.preview_enabled
	song_preview_toggle.toggled.connect(game.lobby.set_preview_enabled)
	row_label(gameplay,"Metronome","Click to the beat while editing or recording.",.86,.98)
	metronome_toggle=Switch.new(); place(metronome_toggle,gameplay,.76,.885,.94,.965)
	metronome_toggle.button_pressed=game.beat_clock.enabled
	metronome_toggle.toggled.connect(func(on): if game.beat_clock.enabled!=on: game.beat_clock.toggle())

	var audio = card("AUDIO & SYNC",.51,.965)
	row_label(audio,"Timing offset","Move notes earlier (−) or later (+) to match the music.",.16,.34)
	timing_input = Stepper.new(-200,200,5,game.timing_ms," ms",0); place(timing_input,audio,.58,.19,.94,.31)
	timing_input.value_changed.connect(game.change_audio_offset)
	row_label(audio,"Bluetooth headset mode","Compensates for wireless audio delay.",.38,.56)
	bluetooth_toggle = Switch.new(); place(bluetooth_toggle,audio,.76,.42,.94,.52)
	bluetooth_toggle.button_pressed = game.bluetooth_mode
	bluetooth_toggle.toggled.connect(game.change_bluetooth_mode)
	row_label(audio,"Extra headset delay","Raise it if you hear the music after notes hit the bar.",.6,.78)
	bluetooth_latency_input = Stepper.new(0,600,5,game.bluetooth_latency_ms," ms",0); place(bluetooth_latency_input,audio,.58,.63,.94,.75)
	bluetooth_latency_input.editable = game.bluetooth_mode
	bluetooth_latency_input.value_changed.connect(game.change_bluetooth_latency)
	var helper = NeonAction.new(); helper.caption_text = "OPEN AUDIO SYNC HELPER"; helper.variant = "secondary"
	helper.compact = true; helper.caption_size = 18
	place(helper,audio,.06,.82,.94,.93); helper.pressed.connect(func(): game.open_sync_helper())
	refresh()

func refresh() -> void:
	for kind in shape_tiles: shape_tiles[kind].selected = kind == game.note_shape
	if song_preview_toggle: song_preview_toggle.set_pressed_no_signal(game.lobby.preview_enabled)
	if metronome_toggle: metronome_toggle.set_pressed_no_signal(game.beat_clock.enabled)
