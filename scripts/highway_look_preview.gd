extends Control
# Settings preview of the highway look: style, rail and band colors, and surface darkness.
var game: Control
const GOLD_BAND = Color(1.0,.86,.34)
const NEON_BAND = Color(.60,.36,1.0)
const CREAM = Color(1.0,.96,.88)
const NEON_RAILS = [Color("38baff"),Color("b35cff")]

func _ready() -> void:
    custom_minimum_size=Vector2(0,230)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
    if is_visible_in_tree(): queue_redraw()

func custom(key: String) -> Variant:
    var value=str(game.get(key))
    return Color.from_string(value,Color.BLACK) if value!="" else null

# Point on the highway: across in -1..1 from rail to rail, depth 0 at the bar end, 1 far away.
func at(across: float,depth: float) -> Vector2:
    var y=lerpf(size.y*.92,size.y*.10,depth)
    var half=lerpf(size.x*.40,size.x*.08,depth)
    return Vector2(size.x*.5+across*half,y)

func strip(a: float,b: float,d0: float,d1: float,color: Color) -> void:
    draw_colored_polygon(PackedVector2Array([at(a,d0),at(b,d0),at(b,d1),at(a,d1)]),color)

func _draw() -> void:
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("101124"); plate.border_color=Color("292c43")
    plate.set_corner_radius_all(18); plate.set_border_width_all(1)
    draw_style_box(plate,Rect2(Vector2.ZERO,size))
    if game.highway_style=="prism":
        draw_texture_rect(preload("res://assets/neon/Prism_Stage.png"),Rect2(Vector2(12,12),size-Vector2(24,24)),false)
        return
    # A stand-in stage glow behind the see-through highway.
    var glow=PackedColorArray([Color("3a1d6e"),Color("3a1d6e"),Color("0d0a1e"),Color("0d0a1e")])
    draw_polygon(PackedVector2Array([Vector2(12,12),Vector2(size.x-12,12),Vector2(size.x-12,size.y-12),Vector2(12,size.y-12)]),glow)
    var gold=str(game.highway_style)=="gold"
    var prism=str(game.highway_style)=="prism"
    var darkness=float(game.highway_opacity)
    var surface=Color("050409") if gold else Color("0b1030")
    strip(-1,1,0,1,Color(surface,minf(.95,(.62 if gold else .55)*darkness)))
    # Notes resting in two lanes and one on its way down.
    var t=Time.get_ticks_msec()/1000.0
    if prism:
        for lane in range(1,10):
            var x=-1.0+float(lane)*.2
            var tint=Color("05cfff").lerp(Color("f02bff"),.5+.5*sin(t*.55+lane*.6))
            draw_line(at(x,0),at(x,1),Color(tint,.7),1.5,true)
    for item in [[-.55,.42],[.35,.62],[.05,fmod(t*.35,1.0)]]:
        var lane=float(item[0]); var depth=1.0-float(item[1])
        strip(lane-.12,lane+.12,depth-.02,depth+.02,Color("b58aff"))
    var band=custom("band_color")
    var band_color: Color=band if band!=null else (GOLD_BAND if gold else NEON_BAND)
    strip(-1,1,.07,.17,Color(band_color,.86 if gold else .72))
    for d in [.07,.17]: strip(-1,1,d-.004,d+.004,Color(Color("fff1cf") if gold else Color("ead6ff"),.85))
    var rail=custom("rail_color")
    for side in [-1,1]:
        var near=at(side*1.0,0); var far=at(side*1.0,1)
        if gold:
            var tint: Color=CREAM*(rail if rail!=null else Color.WHITE)
            if rail!=null: tint=rail.lerp(Color.WHITE,.15)
            var outward=Vector2(side,0)
            draw_colored_polygon(PackedVector2Array([near,near+outward*14,far+outward*4,far]),tint.darkened(.35))
            draw_colored_polygon(PackedVector2Array([near+outward*2,near+outward*10,far+outward*3,far+outward*1]),tint)
            draw_line(near+outward*5,far+outward*1.6,tint.lerp(Color.WHITE,.7),2,true)
        else:
            var tint: Color=rail if rail!=null else NEON_RAILS[0 if side<0 else 1]
            draw_line(near+Vector2(side*3,0),far+Vector2(side*1,0),Color(tint,.25),12,true)
            draw_line(near+Vector2(side*3,0),far+Vector2(side*1,0),tint.lerp(Color.WHITE,.35),3,true)
            if prism:
                var dynamic=Color("05cfff").lerp(Color("f02bff"),.5+.5*sin(t*.7+side))
                draw_line(near+Vector2(side*9,0),far+Vector2(side*3,0),dynamic.darkened(.5),12,true)
                draw_line(near+Vector2(side*7,0),far+Vector2(side*2,0),dynamic,3,true)
