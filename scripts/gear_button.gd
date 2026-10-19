extends Button

# Icon-only settings button: a neon gear drawn in code, so it needs no font glyph or texture.
const UiMotion = preload("res://scripts/ui_motion.gd")
const TEETH = 8

var accent = Color("cbbcff")
var hover_amount = 0.0
var hover_tween: Tween

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Settings"
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): animate_hover(1.0))
	mouse_exited.connect(func(): animate_hover(0.0))
	UiMotion.bind_button(self)

func animate_hover(value: float) -> void:
	if hover_tween and hover_tween.is_running(): hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_method(func(amount: float): hover_amount = amount; queue_redraw(), hover_amount, value, 0.18)

func gear_outline(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var step = TAU / TEETH
	for tooth in TEETH:
		var base = tooth * step
		# Each tooth: flat top on the outer radius, then down to the inner radius between teeth.
		for corner in [[-.30, inner], [-.20, outer], [.20, outer], [.30, inner]]:
			var angle = base + corner[0] * step
			points.append(center + Vector2(cos(angle), sin(angle)) * corner[1])
	return points

# A rounded square button like the other screens' back buttons: dark card, light border that
# turns cyan on hover, and a solid gear icon with a punched-out centre.
func _draw() -> void:
	var side = minf(size.x, size.y)
	var rect = Rect2((size - Vector2(side, side)) * .5, Vector2(side, side)).grow(-side * .04)
	var box = StyleBoxFlat.new(); box.set_corner_radius_all(roundi(side * .22)); box.set_border_width_all(1)
	box.bg_color = Color(0.041,0.041,0.041,.86).lerp(Color("143443"), hover_amount * .45)
	box.border_color = Color("302a42").lerp(Color("50daec"), hover_amount * .8)
	box.shadow_color = Color(Color("50daec"), hover_amount * .14); box.shadow_size = roundi(side * .08)
	draw_style_box(box, rect)
	var center = rect.get_center()
	var radius = side * .25
	var color = Color("e8e6f6").lerp(Color.WHITE, hover_amount)
	draw_colored_polygon(gear_outline(center, radius, radius * .78), color)
	draw_circle(center, radius * .78, color)
	draw_circle(center, radius * .36, box.bg_color.lerp(Color("0f0f0f"), .3))
