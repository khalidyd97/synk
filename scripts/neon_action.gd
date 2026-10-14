extends Button

const UiMotion = preload("res://scripts/ui_motion.gd")
const ART_SHADER = preload("res://scripts/neon_action.gdshader")

var caption_text = ""
var accent_color = Color("b35cff")
var caption_size = 20
var left_aligned = false
var compact = false
var selected = false
var backdrop: ColorRect
var caption: Label
var art_material: ShaderMaterial
var hover_tween: Tween
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
	art_material.set_shader_parameter("accent",accent_color)
	art_material.set_shader_parameter("hover_amount",0.0)
	art_material.set_shader_parameter("press_amount",0.0)
	art_material.set_shader_parameter("disabled_amount",0.0)
	art_material.set_shader_parameter("selected_amount",1.0 if selected else 0.0)
	art_material.set_shader_parameter("ring_strength",0.22 if compact else 1.0)
	backdrop.material = art_material
	caption = Label.new(); add_child(caption)
	caption.anchor_left = 0.30 if left_aligned else (0.10 if compact else 0.23)
	caption.anchor_right = 0.92 if compact else 0.94
	caption.anchor_top = 0.05; caption.anchor_bottom = 0.95
	caption.text = caption_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left_aligned else HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",caption_size)
	caption.add_theme_color_override("font_color",Color("f8eeff"))
	caption.add_theme_color_override("font_outline_color",Color(accent_color,.67))
	caption.add_theme_constant_override("outline_size",4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(update_aspect)
	update_aspect()
	mouse_entered.connect(func(): animate_hover(1.0))
	mouse_exited.connect(func(): animate_hover(0.0))
	button_down.connect(func(): art_material.set_shader_parameter("press_amount",1.0))
	button_up.connect(func(): art_material.set_shader_parameter("press_amount",0.0))
	UiMotion.bind_button(self)

func _process(_delta: float) -> void:
	if disabled!=previous_disabled:
		art_material.set_shader_parameter("disabled_amount",1.0 if disabled else 0.0)
		previous_disabled=disabled
	if not text.is_empty() and caption.text!=text: caption.text=text

func update_aspect() -> void:
	if art_material and size.y>0: art_material.set_shader_parameter("aspect",size.x/size.y)

func set_selected(value: bool) -> void:
	selected=value
	if art_material: art_material.set_shader_parameter("selected_amount",1.0 if value else 0.0)

func animate_hover(value: float) -> void:
	if hover_tween and hover_tween.is_running(): hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_method(func(amount: float): art_material.set_shader_parameter("hover_amount",amount),
		float(art_material.get_shader_parameter("hover_amount")),value,0.18)
