extends Control
# A touch colour picker in the middle of the screen: a saturation/brightness square, a hue
# bar, quick swatches and a hex field. Changes apply live through on_change; Cancel (or a tap
# outside the card) restores the colour it opened with, Done keeps the new one.
const Soft = preload("res://scripts/soft_button.gd")
const Action = preload("res://scripts/settings_action.gd")
const PRESETS = ["f3ece1","ffd257","ff9a3c","ff7a59","ff4d6a","ff5fd2","a36aff","5b7cff","38baff","3ce0c0","59e36b","ffffff"]
const RECENT_LIMIT=24
var palette_game:Control
var recent_codes:Array[String]=[]
var preset_grid:GridContainer
var palette_scroll:ScrollContainer
var recent_row:HBoxContainer
var recent_label:Label
var recent_empty:Label
var closing=false
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
	sheet.palette_game=game;sheet.recent_codes=applied_colors(game);sheet.refresh_recent()
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
	palette_scroll=ScrollContainer.new();card.add_child(palette_scroll);palette_scroll.name="PaletteScroll"
	palette_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var palette_box=VBoxContainer.new();palette_scroll.add_child(palette_box);palette_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;palette_box.add_theme_constant_override("separation",8)
	recent_label=Label.new();palette_box.add_child(recent_label);recent_label.text="RECENT COLORS";recent_label.add_theme_font_size_override("font_size",14)
	var recent_scroll=ScrollContainer.new();palette_box.add_child(recent_scroll);recent_scroll.custom_minimum_size.y=48;recent_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;recent_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	recent_row=HBoxContainer.new();recent_scroll.add_child(recent_row);recent_row.name="RecentColors";recent_row.add_theme_constant_override("separation",8)
	recent_empty=Label.new();palette_box.add_child(recent_empty);recent_empty.text="Applied colors appear here.";recent_empty.add_theme_font_size_override("font_size",14)
	var preset_label=Label.new();palette_box.add_child(preset_label);preset_label.text="PRESETS";preset_label.add_theme_font_size_override("font_size",14)
	preset_grid=GridContainer.new();palette_box.add_child(preset_grid);preset_grid.columns=6;preset_grid.add_theme_constant_override("h_separation",8);preset_grid.add_theme_constant_override("v_separation",8)
	for code in PRESETS:preset_grid.add_child(color_swatch(code,false))
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
	var w=minf(size.x-48,1020.0);var h=minf(size.y-48,640.0)
	var compact=h<440
	card.size=Vector2(w,h);card.position=(size-card.size)*.5;card.pivot_offset=card.size*.5
	var pad=20.0 if compact else 28.0
	var heading_height=42.0 if compact else 52.0
	var action_height=52.0 if compact else 74.0
	var hue_height=32.0 if compact else 46.0
	title.position=Vector2(pad,pad-4);title.size=Vector2(w*.6,34 if compact else 40)
	var left=Rect2(pad,pad+heading_height,w*.5-pad*1.5,h-pad*2-heading_height-hue_height-22)
	square.position=left.position;square.size=left.size
	hue_bar.position=Vector2(pad,left.end.y+22);hue_bar.size=Vector2(left.size.x,hue_height)
	var right_x=w*.5+pad*.5;var right_w=w*.5-pad*1.5
	var y=pad+heading_height
	if preview:
		preview.visible=h>=480
		if preview.visible:
			preview.custom_minimum_size=Vector2.ZERO;preview.position=Vector2(right_x,y);preview.size=Vector2(right_w,96 if h>=560 else 58);y+=preview.size.y+10
	var chip_height=30.0 if compact else 44.0
	var hex_height=38.0 if compact else 52.0
	before_chip.position=Vector2(right_x,y);before_chip.size=Vector2(right_w*.5,chip_height)
	after_chip.position=Vector2(right_x+right_w*.5,y);after_chip.size=Vector2(right_w*.5,chip_height)
	hex.position=Vector2(right_x,y+chip_height+10);hex.size=Vector2(right_w,hex_height)
	var swatch_top=hex.position.y+hex.size.y+10
	palette_scroll.position=Vector2(right_x,swatch_top)
	palette_scroll.size=Vector2(right_w,maxf(32,h-pad-action_height-12-swatch_top))
	preset_grid.columns=maxi(3,mini(6,int((right_w+8)/56)))
	var cancel=card.get_node("Cancel");var done=card.get_node("Done")
	cancel.position=Vector2(right_x,h-pad-action_height);cancel.size=Vector2(right_w*.5-6,action_height)
	done.position=Vector2(right_x+right_w*.5+6,h-pad-action_height);done.size=Vector2(right_w*.5-6,action_height)
	square_marker.queue_redraw();hue_marker.queue_redraw()

static func applied_colors(game:Control) -> Array[String]:
	var result:Array[String]=[]
	if game==null:return result
	var saved=game.prefs.get_value("colors","recent",[])
	var candidates:Array=saved.duplicate() if saved is Array else []
	candidates.append_array([game.rail_color,game.band_color,game.hit_color])
	candidates.append_array(game.gameplay_colors.values())
	for item in candidates:
		var code=str(item).strip_edges().trim_prefix("#")
		if code.length()!=6 or not Color.html_is_valid(code):continue
		code=Color(code).to_html(false)
		if not code in result:result.append(code)
		if result.size()>=RECENT_LIMIT:break
	return result

func color_swatch(code:String,recent:bool) -> Button:
	var swatch=Button.new();swatch.custom_minimum_size=Vector2(48,48);swatch.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	swatch.focus_mode=Control.FOCUS_ALL;swatch.tooltip_text="#"+code.to_upper();swatch.set_meta("recent" if recent else "preset",code)
	var face=StyleBoxFlat.new();face.bg_color=Color(code);face.set_corner_radius_all(12);face.set_border_width_all(2);face.border_color=Color(1,1,1,.18)
	for state in ["normal","hover","pressed","focus"]:swatch.add_theme_stylebox_override(state,face)
	swatch.pressed.connect(func():set_color(Color(code)))
	return swatch

func refresh_recent() -> void:
	for child in recent_row.get_children():recent_row.remove_child(child);child.queue_free()
	for code in recent_codes:recent_row.add_child(color_swatch(code,true))
	recent_label.visible=not recent_codes.is_empty();recent_row.get_parent().visible=not recent_codes.is_empty();recent_empty.visible=recent_codes.is_empty()

func remember_color() -> void:
	if palette_game==null:return
	var code=current().to_html(false)
	recent_codes.erase(code);recent_codes.push_front(code)
	if recent_codes.size()>RECENT_LIMIT:recent_codes.resize(RECENT_LIMIT)
	palette_game.prefs.set_value("colors","recent",recent_codes)
	palette_game.prefs.save("user://preferences.cfg")

func current() -> Color: return Color.from_hsv(hue,saturation,value)

func set_color(color: Color) -> void:
	# Grey colours have no hue of their own: keep the bar where it was.
	if color.s > .01: hue = color.h
	saturation = color.s; value = color.v; sync(true)

func sync(notify: bool) -> void:
	if closing and notify:return
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
	if closing:return
	if keep:read_hex()
	closing=true
	if keep:
		if on_done.is_valid():on_done.call(current())
		remember_color()
	elif not keep:
		if on_cancel.is_valid(): on_cancel.call()
		elif on_change.is_valid(): on_change.call(original)
	var tween = create_tween(); tween.tween_property(self,"modulate:a",0.0,.14); tween.tween_callback(queue_free)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
