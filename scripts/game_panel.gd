extends Control
# Decorative stage chassis: clipped corners, edge rails, and registration marks.
var accent=Color("7acfff")
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var w=size.x; var h=size.y; var cut=minf(22,minf(w,h)*.12)
	var points=PackedVector2Array([Vector2(cut,0),Vector2(w,0),Vector2(w,h-cut),Vector2(w-cut,h),Vector2(0,h),Vector2(0,cut)])
	draw_colored_polygon(points,Color("101010"))
	var outline=points.duplicate(); outline.append(points[0])
	draw_polyline(outline,Color(accent,.4),1.5,true)
	draw_line(Vector2(cut+12,1),Vector2(minf(w*.38,cut+150),1),accent,3,true)
	draw_line(Vector2(w-cut-12,h-1),Vector2(maxf(w*.65,w-cut-100),h-1),Color("e478ff"),3,true)
	for i in 3:
		var x=w-cut-16-i*9
		draw_line(Vector2(x,9),Vector2(x-4,15),Color(accent,.55),2,true)
