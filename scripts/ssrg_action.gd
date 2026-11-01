extends Button
var caption=""
var engagement=0.0
var press_amount=0.0
const FONT=preload("res://assets/fonts/FiraSans-Bold.ttf")
func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _process(delta:float) -> void:
	if not is_visible_in_tree():return
	engagement=lerpf(engagement,1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,1.0-exp(-delta*16.0))
	press_amount=lerpf(press_amount,1.0 if is_pressed() and not disabled else 0.0,1.0-exp(-delta*22.0))
	queue_redraw()
func _draw() -> void:
	var Soft=preload("res://scripts/soft_button.gd")
	var pressing=press_amount
	Soft.draw_plate(self,size,"surface",engagement,pressing)
	var font_size=clampi(roundi(size.y*.16),16,26)
	var text_size=FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	draw_string(FONT,Vector2((size.x-text_size.x)*.5,size.y*.5+(FONT.get_ascent(font_size)-FONT.get_descent(font_size))*.5-1+2*pressing),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Soft.text_color("surface"))
