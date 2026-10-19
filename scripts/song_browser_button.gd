extends Button
const Sound=preload("res://scripts/ui_sound.gd")
var selected=false
var amount=0.0
var primary=false
var tab=false
var subtitle=""
var caption_size=16
var accent=Color("4bdaed")
var hover_amount=0.0
var press_amount=0.0
var menu_motion=false
var motion: RefCounted
func _ready() -> void:
    if menu_motion: motion=preload("res://scripts/menu_button_motion.gd").new()
    mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    add_theme_color_override("font_color",Color(1,1,1,0))
    add_theme_color_override("font_hover_color",Color(1,1,1,0))
    add_theme_color_override("font_pressed_color",Color(1,1,1,0))
    add_theme_color_override("font_disabled_color",Color(1,1,1,0))
    if primary:
        var mat=ShaderMaterial.new(); mat.shader=preload("res://scripts/song_play_gradient.gdshader"); material=mat
        resized.connect(func(): material.set_shader_parameter("plate_size",size))
        mat.set_shader_parameter("plate_size",size)
    button_down.connect(func(): press_amount=1.0; Sound.play(self,"play" if primary else "click"))
    if motion: button_down.connect(func(): if not disabled: motion.press=1.0)
func set_selected(value: bool) -> void: selected=value
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    amount=lerpf(amount,1.0 if selected else 0.0,1-exp(-delta*16))
    hover_amount=lerpf(hover_amount,1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,1-exp(-delta*14))
    press_amount=move_toward(press_amount,0,delta*5)
    if motion: motion.advance(delta,not disabled)
    queue_redraw()
func _draw() -> void:
    var font=get_theme_font("font"); var font_size=caption_size if not primary else maxi(23,caption_size)
    var tint=Color("f3f2ff") if not disabled else Color("69677e")
    if tab:
        if amount>.005:
            var inset=size.x*.5*(1-amount) if menu_motion else 0.0
            draw_line(Vector2(inset,size.y-1),Vector2(size.x-inset,size.y-1),Color(accent,amount),2,true)
        tint=Color("b7b2cd").lerp(Color.WHITE,maxf(amount,hover_amount*.7))
    else:
        var style=StyleBoxFlat.new(); style.set_corner_radius_all(16 if primary else 15)
        style.bg_color=Color("0c0c20").lerp(Color("123142"),amount*.8)
        style.bg_color=style.bg_color.lightened(hover_amount*.065+press_amount*.04)
        style.border_color=Color("2c293e").lerp(accent,maxf(amount,hover_amount*.65))
        style.set_border_width_all(1)
        if primary:
            # Native gradient plate, clipped with the same rounded silhouette as the reference.
            style.bg_color=Color("753cf0") if not disabled else Color("222236")
            style.shadow_color=Color(.7,.1,.75,.24+hover_amount*.1+press_amount*.08); style.shadow_size=15
        elif amount>.02:
            style.shadow_color=Color(accent,amount*.15); style.shadow_size=8
        draw_style_box(style,Rect2(Vector2.ZERO,size))
        if press_amount>.01:
            var feedback=StyleBoxFlat.new(); feedback.set_corner_radius_all(16 if primary else 15)
            feedback.bg_color=Color(0,0,0,0); feedback.border_color=Color(accent,press_amount*.6); feedback.set_border_width_all(2)
            draw_style_box(feedback,Rect2(Vector2.ONE,size-Vector2.ONE*2))
        if motion:
            motion.paint(self,accent,0.0 if disabled else maxf(.45 if primary else amount*.6,hover_amount),16 if primary else 15)
    if motion:
        # Compress only the drawn content; the actual control never moves or scales.
        var compression=1.0-motion.press*.025
        draw_set_transform(size*(1-compression)*.5,0,Vector2.ONE*compression)
    var caption=text
    var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
    var y=size.y*.5+font.get_ascent(font_size)*.5-font.get_descent(font_size)*.5
    if not subtitle.is_empty(): y=size.y*.39+5
    draw_string(font,Vector2((size.x-width)*.5,y),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
    if not subtitle.is_empty():
        var small=font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
        draw_string(font,Vector2((size.x-small)*.5,size.y*.74),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b7b2cd") if not disabled else Color("57546a"))
    if motion: draw_set_transform(Vector2.ZERO)
