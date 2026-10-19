extends Button
var amount=0.0

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

func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    amount=lerpf(amount,1.0 if button_pressed else 0.0,1-exp(-delta*16)); queue_redraw()
func _draw() -> void:
    var accent=Color("aaa1c9").lerp(Color("49e4ff"),amount)
    var track=Rect2(size.x*.12,size.y*.08,size.x*.76,size.y*.54)
    var style=StyleBoxFlat.new()
    style.bg_color=Color("211c36").lerp(Color("124c68"),amount)
    style.border_color=accent; style.set_border_width_all(2)
    style.set_corner_radius_all(int(track.size.y*.5))
    draw_style_box(style,track)
    var radius=track.size.y*.32
    var knob=Vector2(lerpf(track.position.x+track.size.y*.5,track.end.x-track.size.y*.5,amount),track.get_center().y)
    draw_circle(knob,radius,accent)
    var play_center=Vector2(lerpf(track.end.x-track.size.y*.5,track.position.x+track.size.y*.5,amount),track.get_center().y)
    draw_colored_polygon(PackedVector2Array([play_center+Vector2(-4,-6),play_center+Vector2(6,0),play_center+Vector2(-4,6)]),accent)
    var font=ThemeDB.fallback_font
    draw_string(font,Vector2(0,size.y*.92),"AUTO",HORIZONTAL_ALIGNMENT_CENTER,size.x,15,accent)
