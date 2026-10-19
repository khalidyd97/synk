extends Node3D

var world: Node3D
var clock=0.0
var energy_nodes: Array=[]
var glow_nodes: Array=[]
var energy_materials: Array=[]
var glow_materials: Array=[]
var last_strengths=Vector2(-1,-1)
var last_colors: Array=[]

func _ready() -> void:
    for side in [-1,1]:
        var anchor=world.FRAME_HALF_WIDTH+.12
        var energy=make_plane(1.8,62,preload("res://scripts/stage_edge_energy.gdshader"))
        energy.position=Vector3(side*(anchor+.9),.68,-29)
        energy.material_override.set_shader_parameter("phase_offset",0.0 if side==-1 else 5.0)
        energy_nodes.append(energy); energy_materials.append(energy.material_override)
        var glow=make_plane(6.0,62,preload("res://scripts/stage_soft_glow.gdshader"))
        glow.position=Vector3(side*(anchor+3.0),.08,-29)
        glow.material_override.set_shader_parameter("rail_x",anchor)
        glow.material_override.set_shader_parameter("phase_offset",0.0 if side==-1 else 2.0)
        glow_nodes.append(glow); glow_materials.append(glow.material_override)
    visible=false

func make_plane(width: float,length_value: float,shader: Shader) -> MeshInstance3D:
    var node=MeshInstance3D.new(); var mesh=PlaneMesh.new(); mesh.size=Vector2(width,length_value)
    node.mesh=mesh; var material=ShaderMaterial.new(); material.shader=shader; node.material_override=material
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node); return node

func update(delta: float) -> void:
    var game=world.game
    var strengths=Vector2(game.features.effect("Flowing edge energy"),game.features.effect("Soft fading glow"))
    var stage=game.mode in ["play","record"] or (game.mode=="paused" and game.paused_mode in ["play","record"])
    visible=stage and (strengths.x>0 or strengths.y>0)
    if not visible: return
    if game.mode in ["play","record"]: clock+=delta
    if strengths!=last_strengths:
        for i in 2:
            energy_nodes[i].visible=strengths.x>0; glow_nodes[i].visible=strengths.y>0
            energy_materials[i].set_shader_parameter("strength",strengths.x)
            glow_materials[i].set_shader_parameter("strength",strengths.y)
        last_strengths=strengths
    var custom=world.custom_color("rail_color")
    var colors=[custom if custom!=null else (world.colors[0] if world.cover_palette_active else Color("39d9ff")),custom if custom!=null else (world.colors[1] if world.cover_palette_active else Color("ed45f5"))]
    var glow_colors=world.rail_glow_colors()
    if colors+glow_colors!=last_colors:
        for i in 2:
            energy_materials[i].set_shader_parameter("tint",colors[i])
            glow_materials[i].set_shader_parameter("tint",glow_colors[i])
        last_colors=(colors+glow_colors).duplicate()
    for i in 2:
        if strengths.x>0: energy_materials[i].set_shader_parameter("clock",clock)
        if strengths.y>0: glow_materials[i].set_shader_parameter("clock",clock)
