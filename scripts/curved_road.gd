extends Node3D
# Curved highway (test). Settings > Highway > "Curved highway (test)". The road's edges rise
# almost straight up far away and flare out toward the player (highway_3d.gd width_at), and
# this node draws that road: a purple floor, glowing edges and a glowing judgment bar with
# rounded corners. It stands in for the stage's own rails, floor and bar while it is on.
var world: Node3D
var road: MeshInstance3D
var showing = false

func _ready() -> void:
	var mesh=PlaneMesh.new(); mesh.size=Vector2((9.75+3.0)*2.0,63.0); mesh.subdivide_depth=200; mesh.subdivide_width=4
	road=MeshInstance3D.new(); road.mesh=mesh
	var material=ShaderMaterial.new(); material.shader=preload("res://scripts/curved_road.gdshader"); material.render_priority=-8
	road.material_override=material; road.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road.extra_cull_margin=500.0; road.position=Vector3(0,.09,-28.5); road.visible=false
	add_child(road)

# The stage pieces this road replaces.
func stock_pieces() -> Array:
	var stage=world.ssrg_theme.original_stage if world.ssrg_theme else null
	if stage == null: return []
	return stage.rails+stage.rail_overlays+[stage.press,stage.press_glow,stage.entrance_shadow]

func draw() -> void:
	var on: bool=world.curved_road_on()
	if on!=showing:
		showing=on; road.visible=on
		# Back to the normal road: the stage shows its own pieces again.
		if not on and world.ssrg_theme: world.ssrg_theme.refresh()
	if not on: return
	for piece in stock_pieces(): piece.visible=false
	var material: ShaderMaterial=road.material_override
	material.set_shader_parameter("pixel",maxf(.25,get_viewport().get_visible_rect().size.y/720.0))
