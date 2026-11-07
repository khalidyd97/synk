extends Node
# A local clock keeps ambient motion continuous while visible and stops it offscreen.
# Album Takeover: every menu backdrop also eases toward the current song's cover colours,
# so choosing a song slowly re-lights the whole screen.
var elapsed=0.0
static var palette_a=Color(.85,.55,.35)
static var palette_b=Color(.25,.55,.50)
var shown_a=Color(-1,0,0)
var shown_b=Color(-1,0,0)
static func attach(target: CanvasItem,shader: Shader) -> ShaderMaterial:
    var mat=ShaderMaterial.new(); mat.shader=shader; target.material=mat
    mat.set_shader_parameter("clock",0.0)
    mat.set_shader_parameter("color_a",palette_a); mat.set_shader_parameter("color_b",palette_b)
    var driver=Node.new(); driver.set_script(load("res://scripts/background_motion.gd"))
    driver.name="BackgroundMotion"; target.add_child(driver)
    return mat
# Two colours that stand for a cover: its overall tone and its most vivid patch.
static func set_palette_from(texture: Texture2D) -> void:
    if texture==null: return
    var image: Image=texture.get_image()
    if image==null or image.is_empty(): return
    image=image.duplicate()
    if image.is_compressed(): image.decompress()
    image.convert(Image.FORMAT_RGB8); image.resize(6,6,Image.INTERPOLATE_BILINEAR)
    var sum=Color(0,0,0); var vivid=Color(0,0,0); var best=-1.0
    for y in 6:
        for x in 6:
            var c=image.get_pixel(x,y); sum+=c
            var score=c.s*c.v
            if score>best: best=score; vivid=c
    var average=Color(sum.r/36.0,sum.g/36.0,sum.b/36.0)
    # Black-and-white covers get SYNK's own warm light instead of a grey one.
    if average.s*average.v<.06 and best<.3:
        palette_a=Color(.85,.5,.33); palette_b=Color(.36,.3,.42); return
    # Lift dark or grey covers so they still give the screen some colour.
    average=Color.from_hsv(average.h,clampf(average.s*1.2,.25,.85),clampf(average.v*1.4,.45,.9))
    vivid=Color.from_hsv(vivid.h,clampf(vivid.s*1.1,.3,.95),clampf(vivid.v*1.2,.5,1.0))
    palette_a=vivid; palette_b=average
func _process(delta: float) -> void:
    var target=get_parent() as CanvasItem
    if not target or not target.is_visible_in_tree(): return
    elapsed+=delta
    if target.material is ShaderMaterial:
        var mat: ShaderMaterial=target.material
        mat.set_shader_parameter("clock",elapsed)
        if shown_a.r<0: shown_a=palette_a; shown_b=palette_b
        var k=1.0-exp(-delta*2.5)
        shown_a=shown_a.lerp(palette_a,k); shown_b=shown_b.lerp(palette_b,k)
        mat.set_shader_parameter("color_a",shown_a); mat.set_shader_parameter("color_b",shown_b)
