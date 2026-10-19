extends "res://scripts/neon_action.gd"
# Pause menu button in the app's card style: a rounded tile with a drawn icon above its label.
# The icon follows the label, so recorder pauses (RESUME REC / RETRY TAKE / REVIEW TAKE) and
# practice (‹ EDITOR) get matching symbols without extra wiring.
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const CYAN = Color("50daec")
var hover_amount = 0.0
var press_amount = 0.0

func _ready() -> void:
	super._ready()
	backdrop.visible = false
	caption.anchor_top = .60; caption.anchor_bottom = .92
	caption.add_theme_constant_override("outline_size", 0)
	caption.add_theme_font_override("font", BOLD)
	button_down.connect(func(): press_amount = 1.0)

func keeps_caption_size() -> bool: return true

func _process(delta: float) -> void:
	super._process(delta)
	if not is_visible_in_tree(): return
	hover_amount = lerpf(hover_amount, 1.0 if is_hovered() else 0.0, 1 - exp(-delta * 14))
	press_amount = move_toward(press_amount, 0.0, delta * 4)
	queue_redraw()

func icon_kind() -> String:
	var label = caption.text if caption else text
	if "REC" in label: return "record"
	if "RESUME" in label or "PLAY" in label: return "play"
	if "RESTART" in label or "RETRY" in label: return "restart"
	if "REVIEW" in label: return "review"
	if "EDITOR" in label: return "editor"
	return "home"

func _draw() -> void:
	var primary_action = variant == "primary"
	var rect = Rect2(Vector2.ZERO, size).grow(-2)
	var radius = roundi(minf(size.x, size.y) * .2)
	var box = StyleBoxFlat.new(); box.set_corner_radius_all(radius)
	box.bg_color = Color(1, 1, 1, .06 + .06 * hover_amount + .05 * press_amount)
	if primary_action:
		box.bg_color = Color(0, 0, 0, 0); box.shadow_color = Color(Color("8a5cff"), .22 + .2 * hover_amount)
		draw_style_box(box, rect)
		draw_rounded_gradient(rect, radius, Color("38baff").lerp(Color.WHITE, .08 * hover_amount), Color("8a4dff").lerp(Color.WHITE, .08 * hover_amount))
	else: draw_style_box(box, rect)
	var center = Vector2(size.x * .5, size.y * .36)
	var r = minf(size.x * .14, size.y * .17) * (1.0 + .06 * hover_amount - .06 * press_amount)
	draw_icon(icon_kind(), center, r, Color.WHITE)

# Rounded rectangle with a smooth left-to-right gradient (each outline point coloured by x).
func draw_rounded_gradient(rect: Rect2, radius: float, left: Color, right: Color) -> void:
	radius = minf(radius, minf(rect.size.x, rect.size.y) * .5)
	var outline = PackedVector2Array()
	var corners = [[rect.position + Vector2(radius, radius), PI], [rect.position + Vector2(rect.size.x - radius, radius), PI * 1.5],
		[rect.end - Vector2(radius, radius), 0.0], [rect.position + Vector2(radius, rect.size.y - radius), PI * .5]]
	for corner in corners:
		for step in 9: outline.append(corner[0] + Vector2.from_angle(corner[1] + step * PI * .5 / 8) * radius)
	var center = rect.get_center(); var mid = left.lerp(right, .5)
	for i in outline.size():
		var a = outline[i]; var b = outline[(i + 1) % outline.size()]
		draw_polygon(PackedVector2Array([center, a, b]), PackedColorArray([mid, left.lerp(right, (a.x - rect.position.x) / rect.size.x), left.lerp(right, (b.x - rect.position.x) / rect.size.x)]))

func draw_icon(kind: String, c: Vector2, r: float, color: Color) -> void:
	var w = maxf(2.0, r * .2)
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * .55, -r * .8), c + Vector2(r * .85, 0), c + Vector2(-r * .55, r * .8)]), color)
		"record":
			draw_circle(c, r * .62, Color("ff5f7e")); draw_arc(c, r * .9, 0, TAU, 40, color, w * .7, true)
		"restart":
			draw_arc(c, r * .72, -PI * .15, PI * 1.55, 40, color, w, true)
			var tip = c + Vector2.from_angle(-PI * .15) * r * .72
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * .05, -r * .42), tip + Vector2(r * .38, r * .08), tip + Vector2(-r * .32, r * .22)]), color)
		"home":
			var roof = PackedVector2Array([c + Vector2(-r * .95, -r * .05), c + Vector2(0, -r * .9), c + Vector2(r * .95, -r * .05)])
			draw_polyline(roof, color, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-r * .65, -r * .25), c + Vector2(-r * .65, r * .8), c + Vector2(r * .65, r * .8), c + Vector2(r * .65, -r * .25)]), color, w, true)
			var door = StyleBoxFlat.new(); door.bg_color = color; door.set_corner_radius_all(roundi(r * .1))
			draw_style_box(door, Rect2(c + Vector2(-r * .2, r * .25), Vector2(r * .4, r * .55)))
		"review":
			for i in 3:
				var y = c.y + (i - 1) * r * .6
				draw_circle(Vector2(c.x - r * .7, y), w * .7, color)
				draw_line(Vector2(c.x - r * .35, y), Vector2(c.x + r * .85, y), color, w, true)
		"editor":
			for i in 3:
				var x = c.x + (i - 1) * r * .65
				draw_line(Vector2(x, c.y - r * .85), Vector2(x, c.y + r * .85), Color(color, .6), w * .6, true)
				var knob = StyleBoxFlat.new(); knob.bg_color = color; knob.set_corner_radius_all(roundi(r * .12))
				draw_style_box(knob, Rect2(Vector2(x - r * .25, c.y + [-.45, .3, -.05][i] * r - r * .13), Vector2(r * .5, r * .26)))
