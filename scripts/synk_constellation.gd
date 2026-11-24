extends Node2D
# Paints the "Stars" SYNK stage's constellation into its SubViewport: one star per note hit,
# joined to the star before it unless a miss came between them.
const CREAM = Color("fff1dc")
var stars: Array = []   # {"at": Vector2 (0..1 of the view), "color": Color, "gap": bool}

func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	for i in range(1, stars.size()):
		if stars[i].gap: continue
		var colour: Color = stars[i].color.lerp(CREAM, .45)
		draw_line(stars[i - 1].at * view, stars[i].at * view, Color(colour, .7), 2.2, true)
	for star in stars:
		var at: Vector2 = star.at * view
		var colour: Color = star.color
		draw_circle(at, 22.0, Color(colour, .08))
		draw_circle(at, 12.0, Color(colour, .2))
		# A four-point star, like the sparkle on SYNK's notes.
		var long = 15.0; var short = 3.0
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -long), at + Vector2(short, -short), at + Vector2(long, 0), at + Vector2(short, short),
			at + Vector2(0, long), at + Vector2(-short, short), at + Vector2(-long, 0), at + Vector2(-short, -short)]), colour.lerp(CREAM, .6))
		draw_circle(at, 3.4, Color.WHITE)
