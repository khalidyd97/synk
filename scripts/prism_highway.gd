extends Node3D
# Project the supplied artwork onto the real track, undoing its baked perspective.
var world: Node3D
var floor_material: ShaderMaterial
func _ready() -> void:
    floor_material=ShaderMaterial.new(); floor_material.shader=preload("res://scripts/prism_track.gdshader")
    floor_material.render_priority=-7
    floor_material.set_shader_parameter("artwork",preload("res://assets/neon/Prism_Stage.png"))
    floor_material.set_shader_parameter("half_width",world.FRAME_HALF_WIDTH)
    var mesh=PlaneMesh.new(); mesh.size=Vector2(world.FRAME_HALF_WIDTH*2.8,110)
    var node=MeshInstance3D.new(); node.mesh=mesh; node.material_override=floor_material
    node.position=Vector3(0,.028,-51); node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node); refresh()
func refresh() -> void:
    visible=world.game.highway_style=="prism" and not world.game.uses_recorder_colors()
    if not floor_material: return
    var adaptive=world.game.highway_colors=="adaptive" and world.cover_palette_active
    var left: Color=world.colors[0] if adaptive else Color("05cfff")
    var right: Color=world.colors[1] if adaptive else Color("f02bff")
    var custom=world.custom_color("rail_color")
    if custom!=null: left=custom; right=custom.lerp(Color.WHITE,.35)
    floor_material.set_shader_parameter("color_a",left)
    floor_material.set_shader_parameter("color_b",right)
    floor_material.set_shader_parameter("darkness",world.game.highway_opacity)
