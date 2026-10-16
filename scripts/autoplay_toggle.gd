extends Button

func _ready() -> void:
	toggle_mode=true
	text=""
	tooltip_text="Auto Play: off"
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	toggled.connect(func(enabled): tooltip_text="Auto Play: on" if enabled else "Auto Play: off"; queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var accent=Color("49e4ff") if button_pressed else Color("aaa1c9")
	var track=Rect2(size.x*.12,size.y*.08,size.x*.76,size.y*.54)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("124c68") if button_pressed else Color("211c36")
	style.border_color=accent; style.set_border_width_all(2)
	style.set_corner_radius_all(int(track.size.y*.5))
	draw_style_box(style,track)
	var radius=track.size.y*.32
	var knob=Vector2(track.end.x-track.size.y*.5 if button_pressed else track.position.x+track.size.y*.5,track.get_center().y)
	draw_circle(knob,radius,accent)
	var play_center=Vector2(track.position.x+track.size.y*.5 if button_pressed else track.end.x-track.size.y*.5,track.get_center().y)
	draw_colored_polygon(PackedVector2Array([play_center+Vector2(-4,-6),play_center+Vector2(6,0),play_center+Vector2(-4,6)]),accent)
	var font=ThemeDB.fallback_font
	draw_string(font,Vector2(0,size.y*.92),"AUTO",HORIZONTAL_ALIGNMENT_CENTER,size.x,13,accent)
