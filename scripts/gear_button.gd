extends Button

# Icon-only settings button: a neon gear drawn in code, so it needs no font glyph or texture.
const UiMotion = preload("res://scripts/ui_motion.gd")
const TEETH = 8

var accent = Color("f4f1ea")
var hover_amount = 0.0
var hover_tween: Tween

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Settings"
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): if preload("res://scripts/ui_motion.gd").hover_allowed(): animate_hover(1.0))
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

# Album Takeover: a round frosted button, like the back buttons, with a paper-white gear.
# Hover lifts the glass a little; nothing glows.
func _draw() -> void:
	var side = minf(size.x, size.y)
	var center = size * .5
	var radius = side * .48
	draw_circle(center, radius, Color(1, 1, 1, .08 + .06 * hover_amount))
	var gear = side * .22
	var color = Color("f4f1ea").lerp(Color.WHITE, hover_amount)
	draw_colored_polygon(gear_outline(center, gear, gear * .78), color)
	draw_circle(center, gear * .78, color)
	# The punched-out centre shows the glass behind it.
	draw_circle(center, gear * .34, Color("1d1c20"))
