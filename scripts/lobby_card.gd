extends Button
# A home screen choice (Play / Create charts) in the app's card style: dark rounded panel,
# gradient icon tile, cyan label, bold title, muted description and a gradient arrow.
# Hover and focus light the border in the card's accent; a press dips the card slightly.
const Sound = preload("res://scripts/ui_sound.gd")
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const MUTED = Color("b4b6d2")

var icon_kind = "play"          # "play" or "create"
var eyebrow = ""
var title = ""
var description = ""
var accent = Color("50daec")
var colors = [Color("38baff"), Color("753cf0")]
var sound = "click"
var hover_amount = 0.0
var press_amount = 0.0
var time = 0.0
# Frosted glass behind the icon tile, so it takes on the colours of the lobby video.
var glass: ColorRect
var glass_material: ShaderMaterial
const GLOW = Color("ff4a5c")

func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button_down.connect(func(): press_amount = 1.0; Sound.play(self, sound))
	set_meta("ui_sound", sound)
	glass = ColorRect.new(); glass.name = "FrostedTile"; glass.show_behind_parent = true
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(glass)
	glass_material = ShaderMaterial.new(); glass_material.shader = preload("res://scripts/frosted_glass.gdshader")
	glass_material.set_shader_parameter("blur", 4.5); glass_material.set_shader_parameter("tint", Color(.06, .02, .05, .35))
	glass.material = glass_material

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	hover_amount = lerpf(hover_amount, 1.0 if (is_hovered() or has_focus()) else 0.0, 1 - exp(-delta * 14))
	press_amount = move_toward(press_amount, 0.0, delta * 4)
	queue_redraw()

# Just the icon tile and its label, centred; hover lifts and brightens the icon.
func _draw() -> void:
	var side = minf(size.x * .55, size.y * .62)
	var lift = -8.0 * hover_amount * side / 230.0 + 5.0 * press_amount * side / 230.0
	var tile = Rect2(Vector2((size.x - side) * .5, size.y * .04 + lift), Vector2(side, side))
	var radius = side * .24
	# Glass pane follows the tile (including its hover lift).
	glass.position = tile.position; glass.size = tile.size
	glass_material.set_shader_parameter("rect_size", tile.size); glass_material.set_shader_parameter("radius", radius)
	var glow = StyleBoxFlat.new(); glow.set_corner_radius_all(roundi(radius)); glow.bg_color = Color(0, 0, 0, 0)
	glow.shadow_color = Color(GLOW, .18 + .30 * hover_amount); glow.shadow_size = roundi(side * (.08 + .10 * hover_amount))
	draw_style_box(glow, tile)
	# Light wash and a thin highlight edge, like a glass pane catching stage light.
	var pane = StyleBoxFlat.new(); pane.set_corner_radius_all(roundi(radius))
	pane.bg_color = Color(1, 1, 1, .07 + .07 * hover_amount)
	pane.border_color = Color(1, 1, 1, .28 + .3 * hover_amount); pane.set_border_width_all(maxi(1, roundi(side * .008)))
	draw_style_box(pane, tile)
	draw_icon(tile.get_center(), side * .27)
	var font_size = roundi(side * .2)
	var width = BOLD.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(BOLD, Vector2((size.x - width) * .5, tile.end.y + font_size * 1.45), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f5f3ff").lerp(Color.WHITE, hover_amount))

# Rounded tile with a smooth top-to-bottom gradient: every outline point is coloured by its
# height, so the triangle fan interpolates the gradient exactly.
func draw_gradient_tile(tile: Rect2, radius: float) -> void:
	var outline = PackedVector2Array()
	var corners = [[tile.position + Vector2(radius, radius), PI], [tile.position + Vector2(tile.size.x - radius, radius), PI * 1.5],
		[tile.end - Vector2(radius, radius), 0.0], [tile.position + Vector2(radius, tile.size.y - radius), PI * .5]]
	for corner in corners:
		for step in 9: outline.append(corner[0] + Vector2.from_angle(corner[1] + step * PI * .5 / 8) * radius)
	var points = PackedVector2Array([tile.get_center()]); var tints = PackedColorArray([colors[0].lerp(colors[1], .5)])
	for i in outline.size() + 1:
		var point = outline[i % outline.size()]
		points.append(point); tints.append(colors[0].lerp(colors[1], (point.y - tile.position.y) / tile.size.y))
	for i in range(1, points.size() - 1):
		draw_polygon(PackedVector2Array([points[0], points[i], points[i + 1]]), PackedColorArray([tints[0], tints[i], tints[i + 1]]))

func draw_icon(center: Vector2, r: float) -> void:
	if icon_kind == "play":
		var tri = PackedVector2Array([center + Vector2(-r * .7, -r), center + Vector2(r * 1.05, 0), center + Vector2(-r * .7, r)])
		draw_colored_polygon(tri, Color.WHITE)
	else:
		# Three sliders, as on a mixing desk.
		for i in 3:
			var x = center.x + (i - 1) * r * .85
			draw_line(Vector2(x, center.y - r * 1.05), Vector2(x, center.y + r * 1.05), Color(1, 1, 1, .55), r * .1, true)
			var y = center.y + [-.55, .35, -.1][i] * r
			var knob = StyleBoxFlat.new(); knob.bg_color = Color.WHITE; knob.set_corner_radius_all(roundi(r * .18))
			draw_style_box(knob, Rect2(Vector2(x - r * .32, y - r * .17), Vector2(r * .64, r * .34)))
