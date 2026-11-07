extends Control
# A light sweep that crosses a main button every few seconds, plus a soft breathing sheen,
# so the screen's main action always feels alive. Purely visual: ignores input and layout.
var phase := randf() * 3.0
const PERIOD := 3.2

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE; focus_mode = FOCUS_NONE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	clip_contents = true
	set_meta("interface_life_decoration", true)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))

func _process(delta: float) -> void:
	phase += delta
	queue_redraw()

func _draw() -> void:
	var parent := get_parent() as Control
	if parent == null or size.x < 20 or size.y < 12: return
	if parent is BaseButton and parent.disabled: return
	var inset := Rect2(Vector2(5, 5), size - Vector2(10, 12))
	# The sweep: a slanted bright band travelling left to right.
	var t := fposmod(phase, PERIOD) / .9
	if t > 1.0: return
	var w := clampf(size.x * .16, 26.0, 70.0)
	var x := lerpf(-w * 2.0, size.x + w, ease(t, -1.6))
	# Stay clear of the rounded ends so the light never pokes outside the pill.
	if x < size.y * .5 or x + w + size.y * .45 > size.x - size.y * .5: return
	var lean := size.y * .45
	var band := PackedVector2Array([Vector2(x + lean, 0), Vector2(x + lean + w, 0), Vector2(x + w, size.y), Vector2(x, size.y)])
	var core := PackedVector2Array([Vector2(x + lean + w * .35, 0), Vector2(x + lean + w * .6, 0), Vector2(x + w * .6, size.y), Vector2(x + w * .35, size.y)])
	draw_colored_polygon(band, Color(1, 1, 1, .10))
	draw_colored_polygon(core, Color(1, 1, 1, .22))
