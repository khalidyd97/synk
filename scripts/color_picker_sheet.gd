extends Control
# A touch colour picker in the middle of the screen: a saturation/brightness square, a hue
# bar, quick swatches and a hex field. Changes apply live through on_change; Cancel (or a tap
# outside the card) restores the colour it opened with, Done keeps the new one.
const Soft = preload("res://scripts/soft_button.gd")
const Action = preload("res://scripts/settings_action.gd")
const PRESETS = ["f3ece1","ffd257","ff9a3c","ff7a59","ff4d6a","ff5fd2","a36aff","5b7cff","38baff","3ce0c0","59e36b","ffffff"]
var on_change: Callable
var on_done: Callable
var on_cancel: Callable
var preview: Control
var original = Color.WHITE
var hue = 0.0
var saturation = 1.0
var value = 1.0
var card: Panel
var square: Control
var hue_bar: Control
var square_fill: ColorRect
var square_marker: Control
var hue_marker: Control
var before_chip: ColorRect
var after_chip: ColorRect
var hex: LineEdit
var title: Label
var dragging = ""

# changed: live, while dragging. done/cancelled: once, on close. game: shows the live highway.
static func open(host: Control, heading: String, start: Color, changed: Callable, done: Callable = Callable(), cancelled: Callable = Callable(), game: Control = null) -> Control:
	var sheet = load("res://scripts/color_picker_sheet.gd").new()
	sheet.on_done = done; sheet.on_cancel = cancelled
	if game:
		sheet.preview = preload("res://scripts/highway_look_preview.gd").new(); sheet.preview.game = game
		sheet.card.add_child(sheet.preview); sheet.preview.custom_minimum_size = Vector2.ZERO
	host.add_child(sheet); sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.on_change = changed; sheet.original = start
	sheet.hue = start.h; sheet.saturation = start.s; sheet.value = start.v
	sheet.title.text = heading; sheet.before_chip.color = start
	sheet.sync(false)
	return sheet

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new(); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0,0,0,.55); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card = Panel.new(); add_child(card); card.mouse_filter = Control.MOUSE_FILTER_STOP
	var plate = StyleBoxFlat.new(); plate.bg_color = Color("1f1e24"); plate.set_corner_radius_all(26)
	plate.set_border_width_all(1); plate.border_color = Color(1,1,1,.07)
	plate.shadow_color = Color(0,0,0,.5); plate.shadow_size = 30; plate.shadow_offset = Vector2(0,12)
	card.add_theme_stylebox_override("panel",plate)
	title = Label.new(); card.add_child(title); title.add_theme_font_override("font",Soft.BOLD)
	title.add_theme_font_size_override("font_size",26); title.add_theme_color_override("font_color",Soft.TEXT)
	# Each area: an input Control, its shader fill, then a marker layer drawn on top.
	square = Control.new(); card.add_child(square); square.gui_input.connect(func(event): drag_input(event,"square"))
	square_fill = ColorRect.new(); square.add_child(square_fill); square_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	square_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; square_fill.material = shader_material(SQUARE_SHADER)
	square_marker = Control.new(); square.add_child(square_marker); square_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	square_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE; square_marker.draw.connect(draw_square_marker)
	hue_bar = Control.new(); card.add_child(hue_bar); hue_bar.gui_input.connect(func(event): drag_input(event,"hue"))
	var hue_fill = ColorRect.new(); hue_bar.add_child(hue_fill); hue_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hue_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; hue_fill.material = shader_material(HUE_SHADER)
	hue_marker = Control.new(); hue_bar.add_child(hue_marker); hue_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hue_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE; hue_marker.draw.connect(draw_hue_marker)
	before_chip = ColorRect.new(); card.add_child(before_chip); before_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	after_chip = ColorRect.new(); card.add_child(after_chip); after_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hex = LineEdit.new(); card.add_child(hex); hex.max_length = 7; hex.alignment = HORIZONTAL_ALIGNMENT_CENTER
	hex.add_theme_font_size_override("font_size",22)
	hex.text_submitted.connect(func(_text): read_hex()); hex.focus_exited.connect(read_hex)
	for code in PRESETS:
		var swatch = Button.new(); card.add_child(swatch); swatch.set_meta("preset",code)
		swatch.focus_mode = Control.FOCUS_NONE
		var face = StyleBoxFlat.new(); face.bg_color = Color(code); face.set_corner_radius_all(40)
		face.set_border_width_all(2); face.border_color = Color(1,1,1,.12)
		for state in ["normal","hover","pressed"]: swatch.add_theme_stylebox_override(state,face)
		swatch.pressed.connect(func(): set_color(Color(code)))
	var cancel = Action.new(); card.add_child(cancel); cancel.text = "CANCEL"; cancel.caption_size = 20; cancel.name = "Cancel"
	cancel.pressed.connect(close.bind(false))
	var done = Action.new(); card.add_child(done); done.text = "DONE"; done.caption_size = 20; done.primary = true; done.name = "Done"
	done.pressed.connect(close.bind(true))
	resized.connect(layout)

func _ready() -> void:
	layout.call_deferred()
	layout()
	card.pivot_offset = card.size*.5; card.scale = Vector2.ONE*.94; modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self,"modulate:a",1.0,.18)
	tween.tween_property(card,"scale",Vector2.ONE,.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func shader_material(code: String) -> ShaderMaterial:
	var shader = Shader.new(); shader.code = code
	var material = ShaderMaterial.new(); material.shader = shader; return material

const SQUARE_SHADER = """shader_type canvas_item;
uniform float hue = 0.0;
vec3 hsv(float h, float s, float v){ vec3 k = clamp(abs(mod(h*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0,0.0,1.0); return v*mix(vec3(1.0),k,s); }
void fragment(){ COLOR = vec4(hsv(hue,UV.x,1.0-UV.y),1.0); }"""
const HUE_SHADER = """shader_type canvas_item;
vec3 hsv(float h){ return clamp(abs(mod(h*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0,0.0,1.0); }
void fragment(){ COLOR = vec4(hsv(UV.x),1.0); }"""

# Card centred on screen, sized for touch: square on the left, swatches and actions on the right.
func layout() -> void:
	if card == null: return
	var w = minf(size.x-48,1020.0); var h = minf(size.y-48,560.0)
	card.size = Vector2(w,h); card.position = (size-card.size)*.5; card.pivot_offset = card.size*.5
	var pad = 28.0
	title.position = Vector2(pad,pad-4); title.size = Vector2(w*.6,40)
	var left = Rect2(pad,pad+52,w*.5-pad*1.5,h-pad*2-52-74)
	square.position = left.position; square.size = left.size
	hue_bar.position = Vector2(pad,left.end.y+22); hue_bar.size = Vector2(left.size.x,46)
	var right_x = w*.5+pad*.5; var right_w = w*.5-pad*1.5
	# Right column: the live highway (when shown), old/new colour, hex, swatches, actions.
	var y = pad+52
	if preview:
		preview.custom_minimum_size = Vector2.ZERO; preview.position = Vector2(right_x,y); preview.size = Vector2(right_w,118); y += 128
	before_chip.position = Vector2(right_x,y); before_chip.size = Vector2(right_w*.5,44)
	after_chip.position = Vector2(right_x+right_w*.5,y); after_chip.size = Vector2(right_w*.5,44)
	hex.position = Vector2(right_x,y+54); hex.size = Vector2(right_w,52)
	var swatch_top = y+116
	var columns = 6; var gap = 10.0; var side = minf(minf((right_w-gap*(columns-1))/columns,64.0),(h-pad-74-12-swatch_top-gap)*.5)
	var index = 0
	for child in card.get_children():
		if not child.has_meta("preset"): continue
		child.position = Vector2(right_x+(index%columns)*(side+gap),swatch_top+(index/columns)*(side+gap)); child.size = Vector2(side,side)
		index += 1
	var cancel = card.get_node("Cancel"); var done = card.get_node("Done")
	cancel.position = Vector2(right_x,h-pad-74); cancel.size = Vector2(right_w*.5-6,74)
	done.position = Vector2(right_x+right_w*.5+6,h-pad-74); done.size = Vector2(right_w*.5-6,74)
	square_marker.queue_redraw(); hue_marker.queue_redraw()

func current() -> Color: return Color.from_hsv(hue,saturation,value)

func set_color(color: Color) -> void:
	# Grey colours have no hue of their own: keep the bar where it was.
	if color.s > .01: hue = color.h
	saturation = color.s; value = color.v; sync(true)

func sync(notify: bool) -> void:
	var color = current()
	square_fill.material.set_shader_parameter("hue",hue)
	after_chip.color = color
	if not hex.has_focus(): hex.text = "#"+color.to_html(false).to_upper()
	square_marker.queue_redraw(); hue_marker.queue_redraw()
	if notify and on_change.is_valid(): on_change.call(color)

func read_hex() -> void:
	var code = hex.text.strip_edges().trim_prefix("#")
	if Color.html_is_valid(code): set_color(Color(code))
	else: sync(false)

func drag_input(event: InputEvent, target: String) -> void:
	var area: Control = square if target=="square" else hue_bar
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = target if event.pressed else ""
	if dragging != target: return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var p = (event.position/area.size).clamp(Vector2.ZERO,Vector2.ONE)
		if target == "square": saturation = p.x; value = 1.0-p.y
		else: hue = minf(p.x,.999)
		sync(true); accept_event()

func draw_square_marker() -> void:
	var at = Vector2(saturation,1.0-value)*square.size
	square_marker.draw_circle(at,16,Color(0,0,0,.35)); square_marker.draw_circle(at,13,Color.WHITE); square_marker.draw_circle(at,10,current())

func draw_hue_marker() -> void:
	var x = hue*hue_bar.size.x
	var knob = StyleBoxFlat.new(); knob.bg_color = Color.from_hsv(hue,1,1); knob.set_corner_radius_all(8)
	knob.set_border_width_all(4); knob.border_color = Color.WHITE
	hue_marker.draw_style_box(knob,Rect2(x-12,-6,24,hue_bar.size.y+12))

func _gui_input(event: InputEvent) -> void:
	# A tap on the dimmed area outside the card cancels.
	if event is InputEventMouseButton and event.pressed and not card.get_global_rect().has_point(event.global_position): close(false)

func close(keep: bool) -> void:
	if keep and on_done.is_valid(): on_done.call(current())
	elif not keep:
		if on_cancel.is_valid(): on_cancel.call()
		elif on_change.is_valid(): on_change.call(original)
	var tween = create_tween(); tween.tween_property(self,"modulate:a",0.0,.14); tween.tween_callback(queue_free)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
