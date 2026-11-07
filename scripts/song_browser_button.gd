extends Button
const Sound=preload("res://scripts/ui_sound.gd")
var selected=false
var amount=0.0
var primary=false
# soft_button.gd role; empty follows primary (cream) or surface.
var soft_role=""
var tab=false
var subtitle=""
var caption_size=16
var accent=Color("f3ece1")
var hover_amount=0.0
var press_amount=0.0
var menu_motion=false
var pulse=false   # primary buttons only: breathing glow plus a ring that ripples outward
var motion: RefCounted
func _ready() -> void:
    if menu_motion: motion=preload("res://scripts/menu_button_motion.gd").new()
    mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    add_theme_color_override("font_color",Color(1,1,1,0))
    add_theme_color_override("font_hover_color",Color(1,1,1,0))
    add_theme_color_override("font_pressed_color",Color(1,1,1,0))
    add_theme_color_override("font_disabled_color",Color(1,1,1,0))
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
    var tint=Color("f4f1ea") if not disabled else Color("69677e")
    if tab:
        # Album Takeover tabs: plain words; the chosen one becomes a paper-white pill.
        var SoftTab=preload("res://scripts/soft_button.gd")
        SoftTab.draw_plate(self,size,"quiet",hover_amount,press_amount,amount,disabled)
        tint=SoftTab.text_color("quiet",amount,disabled,self)
        font=SoftTab.font_for(self)
    else:
        var Soft=preload("res://scripts/soft_button.gd")
        var role=soft_role if soft_role!="" else ("primary" if primary else "surface")
        Soft.draw_plate(self,size,role,hover_amount,press_amount,amount,disabled)
        tint=Soft.text_color(role,amount,disabled)
        font=Soft.font_for(self)
    if motion:
        # Compress only the drawn content; the actual control never moves or scales.
        var compression=1.0-motion.press*.025
        draw_set_transform(size*(1-compression)*.5,0,Vector2.ONE*compression)
    # Leading symbols become drawn icons (ui_icons.gd); with a subtitle the caption sits higher.
    var line=Rect2(0,0,size.x,size.y) if subtitle.is_empty() else Rect2(0,size.y*.12,size.x,size.y*.5)
    preload("res://scripts/ui_icons.gd").draw_caption(self,line,text,font,font_size,tint)
    if not subtitle.is_empty():
        var small=font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
        draw_string(font,Vector2((size.x-small)*.5,size.y*.76),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(tint,.72))
    if motion: draw_set_transform(Vector2.ZERO)

# Hidden widgets stop their per-frame update (screens keep many of them alive offscreen).
func _notification(what: int) -> void:
    if what==NOTIFICATION_VISIBILITY_CHANGED or what==NOTIFICATION_READY: set_process(is_visible_in_tree())
