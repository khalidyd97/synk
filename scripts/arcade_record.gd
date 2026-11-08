extends Control
# The home screen's cover: the album sleeve with its record half pulled out behind it.
# The record turns slowly, its label in the cover's own colour.
const Arcade = preload("res://scripts/arcade_style.gd")
var cover: Texture2D:
	set(v): cover = v; queue_redraw()
var label_color := Color("ff8a5b")
var spin := 0.0
var slide := 1.0   # 0 = record hidden in the sleeve, 1 = pulled out

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	spin += delta * .9; queue_redraw()

# Slides the record out of the sleeve (home entrance).
func pull_out(delay: float = .2) -> void:
	slide = 0.0
	var t = create_tween(); t.tween_interval(delay)
	t.tween_property(self, "slide", 1.0, .9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var side = minf(size.y * .92, size.x * .68)
	var sleeve = Rect2(Vector2(0, (size.y - side) * .5), Vector2(side, side))
	var r = side * .48
	var centre = Vector2(sleeve.end.x - side * .5 + side * .42 * slide, size.y * .5)
	# Record: dark vinyl with fine grooves and a light sheen that turns with it.
	draw_circle(centre + Vector2(0, 14), r, Color(0, 0, 0, .35))
	draw_circle(centre, r, Color("111112"), true, -1.0, true)
	for i in 18:
		draw_arc(centre, r * (.36 + i * .034), 0, TAU, 96, Color(1, 1, 1, .06 if i % 3 == 0 else .035), 1.0, true)
	for k in 2:
		var a = spin + k * PI
		draw_arc(centre, r * .68, a - .3, a + .3, 24, Color(1, 1, 1, .07), r * .55, true)
	draw_circle(centre, r * .32, label_color, true, -1.0, true)
	draw_arc(centre, r * .22, spin, spin + 1.2, 16, Color(1, 1, 1, .35), 2.0, true)
	draw_circle(centre, r * .03, Color("111112"))
	# Sleeve: the cover, with a soft shadow and a thin lit top edge.
	var shadow = StyleBoxFlat.new(); shadow.bg_color = Color(0, 0, 0, 0); shadow.set_corner_radius_all(6)
	shadow.shadow_color = Color(0, 0, 0, .55); shadow.shadow_size = 40; shadow.shadow_offset = Vector2(0, 24)
	draw_style_box(shadow, sleeve)
	if cover: draw_texture_rect(cover, sleeve, false)
	else: draw_rect(sleeve, Color("2a2622"))
	draw_line(sleeve.position + Vector2(2, 1), sleeve.position + Vector2(side - 2, 1), Color(1, 1, 1, .25), 1.0)
