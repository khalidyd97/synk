extends Control
# Settings preview of the highway: the game's own highway, rendered live while settings are
# open, so style, rail and band colors, darkness, angle, lasers and background all match play.
var game: Control
var view: TextureRect
var frame: Panel

func _ready() -> void:
    custom_minimum_size=Vector2(0,300)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    clip_contents=true
    view=TextureRect.new(); add_child(view)
    view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; view.stretch_mode=TextureRect.STRETCH_SCALE
    view.mouse_filter=Control.MOUSE_FILTER_IGNORE
    # A rounded frame over the picture, matching the settings rows.
    frame=Panel.new(); add_child(frame); frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var edge=StyleBoxFlat.new(); edge.draw_center=false; edge.set_corner_radius_all(18)
    edge.set_border_width_all(2); edge.border_color=Color("292c43"); edge.corner_detail=8
    frame.add_theme_stylebox_override("panel",edge)

func _process(_delta: float) -> void:
    var showing=is_visible_in_tree() and game!=null and game.field!=null
    if game: game.set_highway_preview(showing,self)
    if not showing: return
    var field=game.field
    view.texture=field.viewport.get_texture(); view.material=field.screen.material
    # Fit the full game view to this width and keep its lower part: the highway and the bar.
    var source=Vector2(field.viewport.size)
    if source.x<=0 or source.y<=0: return
    var fit=Vector2(size.x,size.x*source.y/source.x)
    if fit.y<size.y: fit=Vector2(size.y*source.x/source.y,size.y)
    view.size=fit; view.position=Vector2((size.x-fit.x)*.5,size.y-fit.y)

func _exit_tree() -> void:
    if game: game.set_highway_preview(false,self)
