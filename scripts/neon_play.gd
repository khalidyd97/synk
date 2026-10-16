extends Button

const UiMotion = preload("res://scripts/ui_motion.gd")
const REFERENCE = preload("res://assets/lobby/play_button_reference.png")
const ART_SHADER = preload("res://scripts/neon_play.gdshader")

var art: TextureRect
var art_material: ShaderMaterial
var hover_tween: Tween

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	art = TextureRect.new()
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = REFERENCE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_material = ShaderMaterial.new(); art_material.shader = ART_SHADER
	art_material.set_shader_parameter("hover_amount",0.0)
	art_material.set_shader_parameter("press_amount",0.0)
	art_material.set_shader_parameter("disabled_amount",0.0)
	art.material = art_material
	mouse_entered.connect(func(): animate_hover(1.0))
	mouse_exited.connect(func(): animate_hover(0.0))
	button_down.connect(func(): art_material.set_shader_parameter("press_amount", 1.0))
	button_up.connect(func(): art_material.set_shader_parameter("press_amount", 0.0))
	set_meta("ui_sound","play")
	UiMotion.bind_button(self)

func _process(_delta: float) -> void:
	art_material.set_shader_parameter("disabled_amount", 1.0 if disabled else 0.0)

func animate_hover(value: float) -> void:
	if hover_tween and hover_tween.is_running(): hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_method(func(amount: float): art_material.set_shader_parameter("hover_amount", amount),
		float(art_material.get_shader_parameter("hover_amount")), value, 0.18)
