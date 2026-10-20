extends Button

const UiMotion = preload("res://scripts/ui_motion.gd")
const ART_SHADER = preload("res://scripts/neon_action.gdshader")

# SYNK button design system. Each role has one look so a button's job reads at a glance:
# primary   - filled violet-to-pink plate: the main next step on a screen (Play, Save).
# record    - filled red-to-orange plate: starts or ends recording.
# secondary - outlined blue plate: other useful actions.
# tool      - rounded lavender chip: editing tools and settings; lights up when selected/on.
# danger    - rounded red chip: removes or discards work.
# nav       - see-through plate: moves between screens (Back, Home, Library).
# track     - song row in the lobby list; the selected song fills in violet-to-pink.
const VARIANTS = {
	"primary": {"accent":Color("b35cff"),"end":Color("ff4fd8"),"fill":1.0,"slant":1.0,"rim":1.0,"ring":.35,"text":Color("ffffff"),"outline":Color("4a1478")},
	"record": {"accent":Color("ff3d6e"),"end":Color("ff8a3d"),"fill":1.0,"slant":1.0,"rim":1.0,"ring":.35,"text":Color("ffffff"),"outline":Color("7a0f2c")},
	"secondary": {"accent":Color("38baff"),"end":Color("38baff"),"fill":0.0,"slant":1.0,"rim":1.0,"ring":0.0,"text":Color("e6f6ff"),"outline":Color("0c4a78")},
	"tool": {"accent":Color("9b8cff"),"end":Color("c77dff"),"fill":0.0,"slant":1.0,"rim":.55,"ring":0.0,"selected_fill":.8,"text":Color("ddd6ff"),"outline":Color("2b2160")},
	"danger": {"accent":Color("ff4d6a"),"end":Color("ff4d6a"),"fill":0.0,"slant":1.0,"rim":.9,"ring":0.0,"text":Color("ffd9df"),"outline":Color("6a0f22")},
	"track": {"accent":Color("9b6cff"),"end":Color("ff4fd8"),"fill":0.0,"slant":1.0,"rim":.6,"ring":.6,"selected_fill":.62,"text":Color("d9d2f5"),"outline":Color("2b1660")},
	"nav": {"accent":Color("a9a3d9"),"end":Color("a9a3d9"),"fill":0.0,"slant":1.0,"rim":.45,"ring":0.0,"ghost":1.0,"text":Color("d9d4f2"),"outline":Color("212121")},
}

var caption_text = ""
# Button text is drawn this much larger than its caption_size, shrinking only as needed to fit.
# Chart Studio marks itself with the "keep_caption_size" meta and keeps its compact text.
const CAPTION_SCALE = 1.4
var fitted_for = ""
var accent_color = Color("b35cff")
var caption_size = 20
var left_aligned = false
var compact = false
var selected = false
# Empty keeps the original look driven by accent_color (lobby track rows).
var variant = ""
var caption_color = Color("f8eeff")
var backdrop: ColorRect
var caption: Label
var content_icon: TextureRect
var glare = false
var art_material: ShaderMaterial
var hover_tween: Tween
var selection_tween: Tween
var disabled_tween: Tween
var previous_disabled = false

func _ready() -> void:
	if not text.is_empty(): caption_text=text
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	backdrop = ColorRect.new(); add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color.WHITE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_material = ShaderMaterial.new(); art_material.shader = ART_SHADER
	var style: Dictionary = VARIANTS.get(variant,{})
	if not style.is_empty(): accent_color=style.accent
	art_material.set_shader_parameter("accent",accent_color)
	art_material.set_shader_parameter("accent_end",style.get("end",accent_color))
	art_material.set_shader_parameter("fill_amount",style.get("fill",0.0))
	art_material.set_shader_parameter("slant",style.get("slant",1.0))
	art_material.set_shader_parameter("rim_strength",style.get("rim",1.0))
	art_material.set_shader_parameter("selected_fill",style.get("selected_fill",0.0))
	art_material.set_shader_parameter("ghost",style.get("ghost",0.0))
	art_material.set_shader_parameter("hover_amount",0.0)
	art_material.set_shader_parameter("press_amount",0.0)
	art_material.set_shader_parameter("disabled_amount",0.0)
	art_material.set_shader_parameter("selected_amount",1.0 if selected else 0.0)
	art_material.set_shader_parameter("ring_strength",style.get("ring",0.22 if compact else 1.0))
	art_material.set_shader_parameter("glare",1.0 if glare else 0.0)
	backdrop.material = art_material
	caption = Label.new(); add_child(caption)
	caption.anchor_left = 0.30 if left_aligned else 0.08
	caption.anchor_right = 0.92
	caption.anchor_top = 0.05; caption.anchor_bottom = 0.95
	caption.text = caption_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left_aligned else HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",caption_size)
	caption_color=style.get("text",Color("f8eeff"))
	caption.add_theme_color_override("font_color",caption_color)
	caption.add_theme_color_override("font_outline_color",style.get("outline",Color(accent_color,.67)))
	caption.add_theme_constant_override("outline_size",4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(update_aspect)
	update_aspect()
	mouse_entered.connect(func(): animate_hover(1.0))
	mouse_exited.connect(func(): animate_hover(0.0))
	button_down.connect(func(): art_material.set_shader_parameter("press_amount",1.0))
	button_up.connect(func(): art_material.set_shader_parameter("press_amount",0.0))
	UiMotion.bind_button(self)
	refresh_caption_color()

func _process(_delta: float) -> void:
	if disabled!=previous_disabled:
		if disabled_tween: disabled_tween.kill()
		disabled_tween=create_tween()
		disabled_tween.tween_method(func(amount: float): art_material.set_shader_parameter("disabled_amount",amount),float(art_material.get_shader_parameter("disabled_amount")),1.0 if disabled else 0.0,.18)
		previous_disabled=disabled
	if not text.is_empty() and caption.text!=text: caption.text=text
	if caption.text+str(size)+str(caption_size)!=fitted_for: fit_caption()

func keeps_caption_size() -> bool:
	var node: Node = self
	while node:
		if node.has_meta("keep_caption_size"): return true
		node = node.get_parent()
	return false

# Largest font size up to caption_size*CAPTION_SCALE at which the text fits the button.
func fit_caption() -> void:
	fitted_for = caption.text+str(size)+str(caption_size)
	if keeps_caption_size():
		caption.add_theme_font_size_override("font_size",caption_size); return
	var target = int(round(caption_size*CAPTION_SCALE))
	var icon_side=minf(size.y*.58,36.0) if content_icon else 0.0
	var available = Vector2(size.x*(.62 if left_aligned else .84)-6-icon_side-(10.0 if content_icon else 0.0),size.y*.9)
	if available.x <= 0 or available.y <= 0: return
	var font = caption.get_theme_font("font")
	var lines = caption.text.split(char(10))
	var fitted = target
	while fitted > 10:
		var widest = 0.0
		for line in lines: widest = maxf(widest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x)
		if widest <= available.x and font.get_height(fitted)*lines.size() <= available.y*.95: break
		fitted -= 1
	caption.add_theme_font_size_override("font_size",fitted)
	if content_icon:
		var text_width=0.0
		for line in lines: text_width=maxf(text_width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x)
		var group_width=icon_side+10.0+text_width
		var left=(size.x-group_width)*.5
		content_icon.position=Vector2(left,(size.y-icon_side)*.5)
		content_icon.size=Vector2(icon_side,icon_side)
		caption.anchor_left=0; caption.anchor_right=0
		caption.offset_left=left+icon_side+10; caption.offset_right=caption.offset_left+text_width
	caption.anchor_top=0; caption.anchor_bottom=1
	caption.offset_top=0; caption.offset_bottom=0

func set_content_icon(texture_value: Texture2D) -> void:
	if content_icon==null:
		content_icon=TextureRect.new(); add_child(content_icon)
		content_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		content_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content_icon.texture=texture_value
	fitted_for=""
	fit_caption()

func update_aspect() -> void:
	if art_material and size.y>0: art_material.set_shader_parameter("aspect",size.x/size.y)

func set_selected(value: bool) -> void:
	if selected==value: return
	selected=value
	if art_material:
		if selection_tween: selection_tween.kill()
		selection_tween=create_tween()
		selection_tween.tween_method(func(amount: float): art_material.set_shader_parameter("selected_amount",amount),float(art_material.get_shader_parameter("selected_amount")),1.0 if value else 0.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	refresh_caption_color()

func refresh_caption_color() -> void:
	# Filled-when-selected chips need brighter text to stay readable on the fill.
	if caption==null: return
	var filled=selected and float(VARIANTS.get(variant,{}).get("selected_fill",0.0))>0
	caption.add_theme_color_override("font_color",Color.WHITE if filled else caption_color)

func animate_hover(value: float) -> void:
	if hover_tween and hover_tween.is_running(): hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_method(func(amount: float): art_material.set_shader_parameter("hover_amount",amount),
		float(art_material.get_shader_parameter("hover_amount")),value,0.18)

# Hidden widgets stop their per-frame update (screens keep many of them alive offscreen).
func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED or what==NOTIFICATION_READY: set_process(is_visible_in_tree())
