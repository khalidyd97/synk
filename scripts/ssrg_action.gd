extends Button
var caption=""
const FONT=preload("res://assets/fonts/FiraSans-Bold.ttf")
func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _process(_delta:float) -> void:
	if is_visible_in_tree():queue_redraw()
func _draw() -> void:
	var Soft=preload("res://scripts/soft_button.gd")
	var pressing=1.0 if is_pressed() else 0.0
	Soft.draw_plate(self,size,"surface",1.0 if is_hovered() or has_focus() else 0.0,pressing)
	var font_size=clampi(roundi(size.y*.16),16,26)
	var text_size=FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	draw_string(FONT,Vector2((size.x-text_size.x)*.5,size.y*.5+(FONT.get_ascent(font_size)-FONT.get_descent(font_size))*.5-1+2*pressing),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Soft.text_color("surface"))
