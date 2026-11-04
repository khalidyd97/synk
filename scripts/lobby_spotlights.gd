extends Control
# Soft animated light shafts aligned to the lamps in concert_stage_clean.png.
const LAMPS = [
	Vector2(.087,.012), Vector2(.135,.032), Vector2(.266,.015),
	Vector2(.718,.018), Vector2(.861,.033), Vector2(.906,.012)
]
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	for i in LAMPS.size():
		var lamp: Vector2 = LAMPS[i]
		var origin := Vector2(lamp.x * size.x, lamp.y * size.y)
		var sway := sin(elapsed * (.23 + i * .017) + i * 1.8) * size.x * .008
		var reach := size.y * (.42 if i % 3 == 1 else .52)
		var tip := origin + Vector2(sway + (size.x * (.016 if i % 2 == 0 else -.016)), reach)
		var pulse := .8 + .2 * sin(elapsed * 1.2 + i * 1.4)
		# Nested translucent cones fade toward the stage and leave the center text readable.
		for layer in 4:
			var width := size.x * (.025 + layer * .016)
			var alpha := (.045 - layer * .008) * pulse
			var top_half := width * .16
			var corners := PackedVector2Array([
				origin + Vector2(-top_half, 0), origin + Vector2(top_half, 0),
				tip + Vector2(width, 0), tip + Vector2(-width, 0)
			])
			var warm := Color(1.0, .62, .25, alpha)
			draw_polygon(corners, PackedColorArray([warm, warm, Color(warm, 0), Color(warm, 0)]))
		var halo := .035 * pulse
		for ring in 3:
			draw_circle(origin, size.y * (.026 + ring * .012), Color(1.0, .62, .29, halo / (ring + 1)))
