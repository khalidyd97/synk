extends Control
# Settings preview of the four note types in SYNK mode's own artwork, in the chosen note
# shape and size.
var game: Control
const SHADER = preload("res://scripts/synk_note_preview.gdshader")
const TAP = preload("res://assets/synk_mode/tap1.png")
const HOLD = preload("res://assets/synk_mode/hold1.png")
const FLICK = preload("res://assets/synk_mode/flick4.png")
# Where the round note sits in each sprite (see highway_3d.gd).
const NOTE_BOX = Vector4(105.0/212.0, 59.5/116.0, 103.0/212.0, 49.5/116.0)
const FLICK_BOX = Vector4(383.0/768.0, 559.0/768.0, 312.0/768.0, 150.0/768.0)
const TRAIL = Color("ff7a2e")
const NOTE_WIDTH = 96.0
var heads: Array = []

func _ready() -> void:
    custom_minimum_size=Vector2(0,170)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    for i in 4:
        var head=TextureRect.new(); add_child(head)
        head.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; head.stretch_mode=TextureRect.STRETCH_SCALE
        head.mouse_filter=Control.MOUSE_FILTER_IGNORE
        var m=ShaderMaterial.new(); m.shader=SHADER; head.material=m
        var flick=i==3
        head.texture=FLICK if flick else (TAP if i==0 else HOLD)
        m.set_shader_parameter("shape_box",FLICK_BOX if flick else NOTE_BOX)
        m.set_shader_parameter("shape_keep_above",1.0 if flick else 0.0)
        heads.append(head)

func baseline() -> float: return size.y*.66

func _process(_delta: float) -> void:
    if not is_visible_in_tree() or game==null: return
    var k=game.note_size
    for i in 4:
        var head: TextureRect=heads[i]
        (head.material as ShaderMaterial).set_shader_parameter("note_shape",game.synk_note_shape_index())
        var centre=Vector2(size.x*(.125+.25*i),baseline())
        if i==3:
            # The flick's frame is square; its disc is 624 px of the 768 px frame, centred at y 559.
            var side=NOTE_WIDTH*k*768.0/624.0
            head.size=Vector2(side,side); head.position=centre-Vector2(side*.5,side*559.0/768.0)
        else:
            var dimensions=Vector2(NOTE_WIDTH,NOTE_WIDTH*116.0/212.0)*k*212.0/206.0
            head.size=dimensions; head.position=centre-Vector2(dimensions.x*.5,dimensions.y*59.5/116.0)
    queue_redraw()

func _draw() -> void:
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("141414"); plate.border_color=Color("292c43")
    plate.set_corner_radius_all(18); plate.set_border_width_all(1)
    draw_style_box(plate,Rect2(Vector2.ZERO,size))
    var line=baseline()
    var note_positions=[size.x*.125,size.x*.375,size.x*.625,size.x*.875]
    for x in note_positions: draw_line(Vector2(x,15),Vector2(x,size.y-28),Color(1,.75,.45,.12),1,true)
    draw_line(Vector2(20,line),Vector2(size.x-20,line),Color(1,.86,.62,.55),1,true)
    var trail=14.0
    var solid=game!=null and game.trail_style=="solid"
    draw_rect(Rect2(Vector2(note_positions[1]-trail*.5,20),Vector2(trail,line-20)),Color(TRAIL,.8 if solid else .45))
    for side in ([] if solid else [-1,1]): draw_line(Vector2(note_positions[1]+side*trail*.5,20),Vector2(note_positions[1]+side*trail*.5,line),TRAIL.lightened(.4),1.5,true)
    var slide_points=PackedVector2Array([Vector2(note_positions[2]+30,20),Vector2(note_positions[2]-18,58),Vector2(note_positions[2],line)])
    draw_polyline(slide_points,Color(TRAIL,.8 if solid else .45),trail,true)
    for i in 4:
        var font=preload("res://scripts/soft_button.gd").font_for(self); var caption=["Tap","Hold","Slide","Flick"][i]
        var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
        draw_string(font,Vector2(note_positions[i]-width*.5,size.y-8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e8d9c2"))
