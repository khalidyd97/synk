extends Button

# Icon-only settings button: a neon gear drawn in code, so it needs no font glyph or texture.
const UiMotion = preload("res://scripts/ui_motion.gd")
const TEETH = 8

var accent = Color("cbbcff")
var hover_amount = 0.0
var press_amount = 0.0
var hover_tween: Tween

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Settings"
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
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

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var next = move_toward(press_amount, 1.0 if button_pressed else 0.0, delta * 10.0)
	if not is_equal_approx(next, press_amount):
		press_amount = next
		queue_redraw()

func plate(rect: Rect2, color: Color, border: Color, radius: int) -> void:
	var box = StyleBoxFlat.new()
	box.set_corner_radius_all(radius); box.set_border_width_all(1)
	box.bg_color = color; box.border_color = border
	draw_style_box(box, rect)

func gear_face(center: Vector2, radius: float) -> void:
	var points = gear_outline(center, radius, radius * .78)
	var colors = PackedColorArray()
	for point in points:
		var light = clampf(.52 - (point - center).dot(Vector2(.6,.8)) / (radius * 2.0), 0.0, 1.0)
		colors.append(Color("79738e").lerp(Color("fffaff"), light).lightened(hover_amount * .08))
	draw_polygon(points, colors)
	points.append(points[0])
	draw_polyline(points, Color(accent, .7), 1.0, true)
	# Bright upper edges and dark lower edges make each tooth read as beveled metal.
	for i in range(points.size() - 1):
		var middle = (points[i] + points[i + 1]) * .5 - center
		var upper = middle.dot(Vector2(.6,.8)) < 0
		draw_line(points[i], points[i + 1], Color(1,.97,1,.85) if upper else Color(.2,.15,.3,.8), maxf(1.0,radius*.045), true)

func _draw() -> void:
	var side = minf(size.x, size.y)
	var rect = Rect2((size - Vector2.ONE * side) * .5, Vector2.ONE * side).grow(-side * .055)
	var corner = roundi(side * .22)
	# A recessed base supports the raised graphite housing.
	var shadow = StyleBoxFlat.new()
	shadow.set_corner_radius_all(corner)
	shadow.bg_color = Color(0,0,0,.4); shadow.shadow_color = Color(0,0,0,.4)
	shadow.shadow_size = roundi(side * .08)
	draw_style_box(shadow, Rect2(rect.position + Vector2(0,side*.065), rect.size))
	plate(Rect2(rect.position + Vector2(0,side*.04),rect.size), Color("100c19"),Color("393043"),corner)
	var lift = Vector2(0,-side*.025*(1.0-press_amount))
	var face = Rect2(rect.position + lift,rect.size)
	plate(face, Color("302b3c").lerp(Color("484054"),hover_amount*.5),Color("71637e"),corner)
	plate(face.grow(-side*.035),Color("18151f"),Color("40364e"),maxi(1,corner-3))
	draw_line(face.position+Vector2(side*.2,side*.015),face.position+Vector2(face.size.x-side*.2,side*.015),Color(1,.88,1,.45),1.2,true)
	var center = face.get_center() + Vector2(0,-side*.035*(1.0-press_amount))
	var radius = side * .255
	var depth = side * .055 * (1.0-press_amount*.7)
	# Stacked side faces expose the gear's thickness under its silver front.
	for layer in range(5,0,-1):
		var offset = Vector2(0,depth*float(layer)/5.0)
		draw_colored_polygon(gear_outline(center+offset,radius,radius*.78),Color("40344f").lerp(Color("837092"),1.0-float(layer)/5.0))
	gear_face(center,radius)
	# A machined lip surrounds a dark, recessed hub.
	draw_circle(center,radius*.43,Color("4f425e"))
	draw_circle(center+Vector2(0,side*.012),radius*.35,Color("09080e"))
	draw_arc(center,radius*.415,0,PI,32,Color("e7d7f4"),maxf(1.0,side*.013),true)
	draw_arc(center,radius*.35,PI,TAU,32,Color("34273f"),maxf(1.0,side*.015),true)
