extends Button
var caption=""
const FONT=preload("res://assets/fonts/FiraSans-Bold.ttf")
func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _draw() -> void:
	var highlighted=is_hovered() or has_focus()
	var tint=Color(.12,.40,.52) if highlighted else Color(.08,.12,.18)
	if is_pressed():tint=tint.lightened(.2)
	var cut=minf(size.x,size.y)*.10
	var polygon=PackedVector2Array([Vector2(cut,0),Vector2(size.x-cut,0),Vector2(size.x,cut),size,Vector2(0,size.y),Vector2(0,cut)])
	draw_colored_polygon(polygon,tint)
	polygon.append(polygon[0]);draw_polyline(polygon,Color(.3,.8,.95,.55 if highlighted else .2),1.0,true)

	var font_size=clampi(roundi(size.y*.16),16,26)
	var text_size=FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	draw_string(FONT,Vector2((size.x-text_size.x)*.5,size.y*.5+(FONT.get_ascent(font_size)-FONT.get_descent(font_size))*.5),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
