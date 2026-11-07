extends "res://scripts/song_browser_button.gd"
# The song's main action (Album Takeover): a big pill filled with the song's own cover
# colour, a play disc at its left end, and a light sweep that crosses it now and then.
var time = 0.0
var fill_color := Color("f4f1ea")
var shown_fill := Color("f4f1ea")

func _ready() -> void:
    primary=false
    super._ready()
    primary=true

func _process(delta: float) -> void:
    super._process(delta)
    time+=delta
    shown_fill=shown_fill.lerp(fill_color,1.0-exp(-delta*6.0))
    if is_visible_in_tree(): queue_redraw()

# Kept for callers from the previous look.
func plate(rect: Rect2, edge: Color, light: Color, radius: float) -> void:
    pass

func _draw() -> void:
    var Soft=preload("res://scripts/soft_button.gd")
    var Arcade=preload("res://scripts/arcade_style.gd")
    var sink=2.0*press_amount
    var rect=Rect2(Vector2(3,3+sink),size-Vector2(6,8))
    var r=rect.size.y*.5
    var fill=shown_fill.lightened(.08*hover_amount) if not disabled else Color(1,1,1,.06)
    var under=StyleBoxFlat.new(); under.bg_color=Color(0,0,0,0); under.set_corner_radius_all(roundi(r))
    under.shadow_color=Color(shown_fill,.35*(1.0-press_amount)) if not disabled else Color(0,0,0,0); under.shadow_size=22; under.shadow_offset=Vector2(0,8)
    draw_style_box(under,rect)
    var pill=StyleBoxFlat.new(); pill.bg_color=fill; pill.set_corner_radius_all(roundi(r)); pill.anti_aliasing=true; pill.corner_detail=12
    draw_style_box(pill,rect)
    # Light sweep, every few seconds.
    if not disabled:
        var t=fmod(time,3.4)/.8
        if t<1.0:
            var x=lerpf(rect.position.x-80,rect.end.x+40,ease(t,-1.6)); var lean=rect.size.y*.4
            var band=PackedVector2Array([Vector2(x+lean,rect.position.y+3),Vector2(x+lean+46,rect.position.y+3),Vector2(x+46,rect.end.y-3),Vector2(x,rect.end.y-3)])
            if x>rect.position.x+r*.6 and x+46<rect.end.x-r*.6: draw_colored_polygon(band,Color(1,1,1,.18))
    # Play disc.
    var ink=Arcade.INK if fill.get_luminance()>.45 else Color.WHITE
    if disabled: ink=Color(1,1,1,.35)
    var d=rect.size.y-16; var c=Vector2(rect.position.x+8+d*.5,rect.get_center().y)
    draw_circle(c,d*.5,Color(ink,.92),true,-1.0,true)
    var k=d*.17
    draw_colored_polygon(PackedVector2Array([c+Vector2(-k*.7,-k),c+Vector2(k*1.05,0),c+Vector2(-k*.7,k)]),fill)
    var caption=text.replace("▶","").strip_edges()
    var font=Arcade.HEAD
    var fs=int(caption_size*1.35)
    var room=rect.size.x-d-40
    while fs>16 and font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>room: fs-=2
    draw_string(font,Vector2(c.x+d*.5+22,rect.get_center().y+fs*.3),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,ink)
