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
# Album Takeover: the same switch as in Settings. A grey track that turns paper white when on,
# its knob sliding across, and a small sentence-case caption underneath.
func _draw() -> void:
    var Soft=preload("res://scripts/soft_button.gd")
    var track=Rect2(size.x*.5-34,size.y*.08,68,size.y*.5)
    var pill=StyleBoxFlat.new(); pill.set_corner_radius_all(int(track.size.y*.5)); pill.anti_aliasing=true
    pill.bg_color=Color("3a3840").lerp(Soft.CREAM,amount)
    draw_style_box(pill,track)
    var knob_radius=track.size.y*.34
    var knob=Vector2(lerpf(track.position.x+track.size.y*.5,track.end.x-track.size.y*.5,amount),track.get_center().y)
    draw_circle(knob,knob_radius,Color("cfcbd2").lerp(Soft.INK,amount))
    var caption="Auto play"; var caption_font=Soft.font_for(self)
    var caption_width=caption_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
    draw_string(caption_font,Vector2((size.x-caption_width)*.5,size.y*.95),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8f8b94").lerp(Soft.TEXT,amount))
