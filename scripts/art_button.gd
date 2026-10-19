extends Button

# Native rounded shapes match the song browser/results panels. Decorative layers
# animate independently; captions, scale and the touch rectangle stay stable.
const UiSound=preload("res://scripts/ui_sound.gd")
var art: Texture2D
var sound="confirm"
var motion_kind=""
var art_rect: TextureRect
var details: Control
var hover=0.0
var press=0.0
var idle_phase=0.0
var gear_angle=0.0
var entrance=1.0
var entrance_tween: Tween
var rim=PackedVector2Array()
var perimeter=0.0
var accent=Color("50daec")
var bars: Array=[]
var headline: Font
const PLATE=Rect2(20,64,660,266)
const CORNER=28.0

func _ready() -> void:
    text=""; focus_mode=Control.FOCUS_ALL
    mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    # Keep the existing art-button interface; no baked-in chassis or captions.
    art_rect=TextureRect.new(); add_child(art_rect); art_rect.visible=false
    art_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
    details=Control.new(); add_child(details); details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    details.mouse_filter=Control.MOUSE_FILTER_IGNORE; details.draw.connect(draw_details)
    var bold=FontVariation.new(); bold.base_font=ThemeDB.fallback_font; bold.variation_embolden=.65; headline=bold
    if motion_kind=="create": accent=Color("b478ff"); idle_phase=.65
    if motion_kind=="settings": accent=Color("ba9df4")
    if motion_kind!="settings":
        rounded_rim(PLATE,CORNER)
        var count=37 if motion_kind=="play" else 43
        for i in count: bars.append({"x":190+i*440.0/(count-1),"width":5.0,"height":12.0+float(posmod(i*17,22))})
    button_down.connect(func():
        if disabled: return
        press=1.0; UiSound.play(self,sound))
    visibility_changed.connect(func():
        if is_visible_in_tree(): play_entrance()
        else: hover=0; press=0)
    play_entrance()

func rounded_rim(rect: Rect2,radius: float) -> void:
    var centers=[Vector2(rect.end.x-radius,rect.position.y+radius),rect.end-Vector2.ONE*radius,Vector2(rect.position.x+radius,rect.end.y-radius),rect.position+Vector2.ONE*radius]
    for corner in 4:
        for step in 13:
            var angle=-PI*.5+corner*PI*.5+step*PI/24.0
            rim.append(centers[corner]+Vector2(cos(angle),sin(angle))*radius)
    rim.append(rim[0])
    for i in range(1,rim.size()): perimeter+=rim[i-1].distance_to(rim[i])

func play_entrance() -> void:
    if entrance_tween: entrance_tween.kill()
    entrance=0
    entrance_tween=create_tween()
    entrance_tween.tween_interval(.12 if motion_kind=="create" else .03)
    entrance_tween.tween_property(self,"entrance",1.0,.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func art_fit() -> Rect2:
    var design=Vector2(120,120) if motion_kind=="settings" else Vector2(700,380)
    var factor=minf(size.x/design.x,size.y/design.y)
    return Rect2((size-design*factor)*.5,design*factor)

func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    hover=move_toward(hover,1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,delta*5.0)
    press=move_toward(press,0.0,delta*3.5)
    idle_phase+=delta
    gear_angle+=delta*(.07+hover*.7)
    details.position.y=-hover*size.y*.012+(1.0-entrance)*size.y*.025
    details.modulate.a=entrance*(.45 if disabled else 1.0)
    details.queue_redraw()

func envelope(index: int) -> float:
    var t=idle_phase*(2.7+hover*1.0)
    return clampf(.53+.24*sin(t+index*.63)+.16*sin(t*1.73-index*.47)+hover*.12,.14,1.0)

func plate(rect: Rect2,radius: int,fill: Color,edge: Color,glow: float=0.0) -> void:
    var style=StyleBoxFlat.new(); style.set_corner_radius_all(radius)
    style.bg_color=fill; style.border_color=edge; style.set_border_width_all(1)
    style.shadow_color=Color(accent,glow); style.shadow_size=16
    details.draw_style_box(style,rect)

func caption(value: String,at: Vector2,font_size: int,tint: Color=Color("f3f1ff"),bold: bool=false) -> void:
    details.draw_string(headline if bold else ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func draw_details() -> void:
    var fit=art_fit()
    if fit.size.x<=0: return
    var factor=fit.size.x/(120.0 if motion_kind=="settings" else 700.0)
    details.draw_set_transform(fit.position,0,Vector2.ONE*factor)
    if motion_kind=="settings":
        draw_settings(); details.draw_set_transform(Vector2.ZERO); return
    var edge=Color(accent,.55+hover*.35+press*.1)
    plate(PLATE,28,Color("0b0d22").lerp(Color("141934"),hover*.65+press*.3),edge,.12+hover*.12)
    plate(PLATE.grow(-7),22,Color(0,0,0,0),Color(accent,.07+hover*.08))
    # A restrained gradient seam replaces the old stacked metal frame.
    for i in 40:
        var x=54+i*14.8
        var tint=accent.lerp(Color("7066f5") if motion_kind=="play" else Color("e750d9"),float(i)/39)
        details.draw_line(Vector2(x,65),Vector2(x+14.8,65),Color(tint,.65),1.5,true)
    var tile=Rect2(52,110,132,132)
    plate(tile,25,Color(accent,.075+hover*.025),Color(accent,.45),.07)
    if motion_kind=="play": draw_play_icon()
    else: draw_create_icon()
    caption("01 / EXPERIENCE" if motion_kind=="play" else "02 / CREATION",Vector2(216,120),16,Color(accent,.9))
    if motion_kind=="play": caption("PLAY",Vector2(210,205),76,Color("f7f5ff"),true)
    else:
        caption("CREATE",Vector2(212,174),46,Color("f7f5ff"),true)
        caption("CHARTS",Vector2(212,226),46,Color("f7f5ff"),true)
    details.draw_line(Vector2(52,261),Vector2(648,261),Color("2d3048"),1,true)
    caption("Find your track. Chase your best." if motion_kind=="play" else "Build the rhythm. Make it yours.",Vector2(52,298),20,Color("b8bbd4"))
    for i in bars.size():
        var bar: Dictionary=bars[i]
        var h=float(bar.height)*(.3+envelope(i)*.7)
        var x=float(bar.x)
        var tint=accent.lerp(Color("7167f4") if motion_kind=="play" else Color("e750d9"),float(i)/maxi(1,bars.size()-1))
        details.draw_rect(Rect2(x,61-h,float(bar.width),h),Color(tint,.38+hover*.25))
        details.draw_rect(Rect2(x,334,float(bar.width),h*.55),Color(tint,.22+hover*.16))
    for offset in [0.0,.5]:
        var head=fmod(idle_phase*(95.0+hover*75.0)+offset*perimeter,perimeter)
        trace(head,72.0+hover*35,.65+hover*.35)
    if press>0: details.draw_polyline(rim,Color(accent,press*.6),3,true)
    draw_chevrons()
    details.draw_set_transform(Vector2.ZERO)

func draw_play_icon() -> void:
    var offset=Vector2(hover*3,0)
    var points=PackedVector2Array([Vector2(101,143)+offset,Vector2(101,209)+offset,Vector2(151,176)+offset])
    details.draw_polygon(points,PackedColorArray([Color("70e5f1"),Color("4185ed"),Color("aff8ff")]))
    var outline=points.duplicate(); outline.append(points[0])
    details.draw_polyline(outline,Color(accent,.32),9,true)
    details.draw_polyline(outline,Color("b8f8ff"),2,true)
    # A small glint follows the triangle, without crossing the caption.
    var phase=fposmod(idle_phase*.38,1.0)*3
    var i=int(phase); var point=points[i].lerp(points[(i+1)%3],fmod(phase,1.0))
    details.draw_circle(point,3,Color("ecfcff"))

func draw_create_icon() -> void:
    for i in 3:
        var x=86+i*32
        details.draw_line(Vector2(x,137),Vector2(x,215),Color(accent,.32),2,true)
        var y=155+i*17+sin(idle_phase*(1.25+i*.23)+i*2)*(12+hover*5)
        plate(Rect2(x-10,y-5,20,10),3,accent.lightened(.3),Color("efdcff"),.06)

func draw_chevrons() -> void:
    for i in 3:
        var chase=pow(maxf(0,sin(idle_phase*TAU*.85-i*.72)),2)
        var x=584+i*20+hover*4
        var points=PackedVector2Array([Vector2(x,280),Vector2(x+10,291),Vector2(x,302)])
        details.draw_polyline(points,Color(accent,.22+chase*.65+hover*.1),3.2,true)

func draw_settings() -> void:
    plate(Rect2(12,12,96,96),26,Color("0c0d23"),Color(accent,.5+hover*.4),.14+hover*.1)
    var points=PackedVector2Array()
    for i in 64:
        var angle=gear_angle+TAU*i/64.0
        var radius=29.0 if i%8 in [0,1,6,7] else 35.0
        points.append(Vector2(60,60)+Vector2(cos(angle),sin(angle))*radius)
    points.append(points[0]); details.draw_polyline(points,Color("e0d7fa"),3.5,true)
    details.draw_arc(Vector2(60,60),13,0,TAU,48,Color("e0d7fa"),3.5,true)
    details.draw_arc(Vector2(60,60),44,gear_angle*.8,gear_angle*.8+.75,24,Color(accent,.7),1.5,true)

func trace(head: float,length_value: float,alpha: float) -> void:
    for segment in 12:
        var from=fposmod(head-length_value+segment*length_value/12.0,perimeter)
        var to=fposmod(head-length_value+(segment+1)*length_value/12.0,perimeter)
        if to<from: continue
        var a=point_on_rim(from); var b=point_on_rim(to)
        if a.distance_to(b)>length_value*.22: continue
        var strength=alpha*float(segment+1)/12.0
        details.draw_line(a,b,Color(accent,strength*.08),9,true)
        details.draw_line(a,b,Color(accent,strength*.3),4,true)
        details.draw_line(a,b,Color(accent.lightened(.6),strength),1.3,true)

func point_on_rim(distance_value: float) -> Vector2:
    for i in range(1,rim.size()):
        var length_value=rim[i-1].distance_to(rim[i])
        if distance_value<=length_value: return rim[i-1].lerp(rim[i],distance_value/maxf(.001,length_value))
        distance_value-=length_value
    return rim[0]
