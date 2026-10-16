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

func _draw() -> void:
	var center = size * .5
	var radius = minf(size.x, size.y) * .40
	var color = accent.lerp(Color.WHITE, hover_amount * .6)
	var glow = Color(Color("9b5cff"), .22 + hover_amount * .25)
	draw_circle(center, radius * 1.15, glow)
	var outline = gear_outline(center, radius, radius * .76)
	outline.append(outline[0])
	draw_polyline(outline, color, maxf(2.0, radius * .13), true)
	draw_arc(center, radius * .30, 0, TAU, 32, color, maxf(2.0, radius * .13), true)
