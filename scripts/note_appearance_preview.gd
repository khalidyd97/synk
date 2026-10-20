extends Control
# Settings preview of the four note types, drawn with the highway's own artwork and colours.
var game: Control
const SHADER = preload("res://scripts/note_preview.gdshader")
const CIRCLE = preload("res://assets/neon/Circle_Note_Reference.png")
const PUCK = preload("res://assets/neon/Circle_Note_Puck.png")
const CAP_REGION = Vector4(.12,0,.88,1)
const PALETTES = [0,1,3,2]          # TAP, HOLD, SLIDE, FLICK -> highway palette
var heads: Array = []
var arrow: Control

func _ready() -> void:
    custom_minimum_size=Vector2(0,150)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    for i in 4:
        var head=TextureRect.new(); add_child(head)
        head.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; head.stretch_mode=TextureRect.STRETCH_SCALE
        head.mouse_filter=Control.MOUSE_FILTER_IGNORE
        var m=ShaderMaterial.new(); m.shader=SHADER; head.material=m
        heads.append(head)
    # The flick's chevron sits over its head, like on the highway.
    arrow=Control.new(); add_child(arrow); arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
    arrow.draw.connect(draw_arrow)

# Every preview note uses the same blue scheme (the circle art's own cyan-blue).
const BLUE = Color("38baff")
func note_color(_palette: int) -> Color:
    return BLUE

func _process(_delta: float) -> void:
    if not is_visible_in_tree() or game==null: return
    var baseline=size.y*.72; var k=game.note_size
    var puck=game.note_shape=="puck"
    for i in 4:
        var head: TextureRect=heads[i]; var palette=PALETTES[i]; var c=note_color(palette)
        var m: ShaderMaterial=head.material
        var dimensions: Vector2
        if game.round_notes():
            var art: Texture2D=PUCK if puck else CIRCLE
            head.texture=art
            dimensions=Vector2(64,64.0*art.get_height()/art.get_width())*k*(.72 if puck else 1.0)
            m.set_shader_parameter("round_art",true)
            m.set_shader_parameter("region",Vector4(0,0,1,1))
            m.set_shader_parameter("hue_shift",(.53-.76) if puck else 0.0)
            m.set_shader_parameter("saturation_scale",1.0); m.set_shader_parameter("value_scale",1.0)
        else:
            head.texture=preload("res://assets/neon/Tap_Note_Blue.png")
            dimensions=Vector2(76,30)*k
            # Shift the deeper blue tap art to the circle's cyan-blue.
            m.set_shader_parameter("round_art",true)
            m.set_shader_parameter("region",CAP_REGION)
            m.set_shader_parameter("hue_shift",-.035)
            m.set_shader_parameter("saturation_scale",.9)
            m.set_shader_parameter("value_scale",.9)
        head.size=dimensions; head.position=Vector2(size.x*(.125+.25*i),baseline)-dimensions*.5
    arrow.position=Vector2.ZERO; arrow.size=size; arrow.queue_redraw()
    queue_redraw()

func draw_arrow() -> void:
    if game==null: return
    var k=game.note_size
    var center=Vector2(size.x*.875,size.y*.72-30*k)
    var c=note_color(2)
    var points=PackedVector2Array([center+Vector2(-16,8)*k,center+Vector2(0,-8)*k,center+Vector2(16,8)*k])
    arrow.draw_polyline(points,Color(c,.45),9*k,true)
    arrow.draw_polyline(points,Color(1,.96,1),4*k,true)

func _draw() -> void:
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("141414"); plate.border_color=Color("292c43")
    plate.set_corner_radius_all(18); plate.set_border_width_all(1)
    draw_style_box(plate,Rect2(Vector2.ZERO,size))
    var baseline=size.y*.72
    var note_positions=[size.x*.125,size.x*.375,size.x*.625,size.x*.875]
    for x in note_positions: draw_line(Vector2(x,15),Vector2(x,size.y-28),Color(.3,.5,.8,.20),1,true)
    draw_line(Vector2(20,baseline),Vector2(size.x-20,baseline),Color("6d7dba"),1,true)
    var trail=14.0*game.hold_trail_width
    var hold_color=note_color(1); var slide_color=note_color(3)
    draw_rect(Rect2(Vector2(note_positions[1]-trail*.5,24),Vector2(trail,baseline-24)),Color(hold_color,.45))
    for side in ([] if game.trail_style=="solid" else [-1,1]): draw_line(Vector2(note_positions[1]+side*trail*.5,24),Vector2(note_positions[1]+side*trail*.5,baseline),hold_color.lightened(.4),1.5,true)
    var slide_points=PackedVector2Array([Vector2(note_positions[2]+30,24),Vector2(note_positions[2]-18,62),Vector2(note_positions[2],baseline)])
    draw_polyline(slide_points,Color(slide_color,.8 if game.trail_style=="solid" else .45),trail,true)
    if game.trail_style=="solid":
        for point in [Vector2(note_positions[1],24),slide_points[0],slide_points[1]]:
            draw_circle(point,trail*.85,slide_color); draw_circle(point,trail*.45,Color("f4eaff"))
    for i in 4:
        var font=ThemeDB.fallback_font; var caption=["TAP","HOLD","SLIDE","FLICK"][i]
        var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
        draw_string(font,Vector2(note_positions[i]-width*.5,size.y-8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c6d6ef"))
