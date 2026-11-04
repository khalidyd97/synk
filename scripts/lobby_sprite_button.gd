extends Button
const SPRITE = preload("res://assets/lobby/ui/games_button_sprite.png")
var engagement := 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	engagement = lerpf(engagement, 1.0 if is_hovered() or has_focus() else 0.0, 1.0 - exp(-delta * 12.0))
	queue_redraw()

func _draw() -> void:
	var source = Rect2(270, 225, 1540, 315)
	var factor = minf(size.x/source.size.x,size.y/source.size.y)
	var fitted = source.size*factor
	draw_texture_rect_region(SPRITE, Rect2((size-fitted)*.5, fitted), source, Color(1.12,1.08,1.03) if engagement > .5 else Color.WHITE)
