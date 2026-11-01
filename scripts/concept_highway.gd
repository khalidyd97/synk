extends Node3D
# Visual skins only: all timing, projection, channels and input remain the shared SSRG mechanism.
const STYLES=["aurora","solar"]
const LABELS={"aurora":"Aurora Glass","solar":"Solar Ceramic"}
const STAGES={"aurora":preload("res://assets/highways/aurora_glass_stage.png"),"solar":preload("res://assets/highways/solar_ceramic_stage.png")}
var world:Node3D
var road_material:ShaderMaterial
const RAIL_FRAME_WIDTH=.80
const ROAD_IMAGES={"aurora":preload("res://assets/highways/aurora_glass_highway.png"),"solar":preload("res://assets/highways/solar_ceramic_highway.png")}
var road_sprite:MeshInstance3D
var marker_material:ShaderMaterial
var active=false

static func palette(style:String) -> Dictionary:
	return {"notes":[Color("fff0d6"),Color("ff8b86"),Color("ffc957")],"stage":Color("1c0e08"),"from_cover":false} if style=="solar" else {"notes":[Color("74e5ff"),Color("c59cff"),Color("a1ffe4")],"stage":Color("07192c"),"from_cover":false}

func _ready() -> void:
	name="ConceptHighway"
	# A flat bitmap sprite, like the original SSRG stage. The artwork contains the
	# road, full beveled frames, reflections and highlights; there are no modeled rails.
	road_material=ShaderMaterial.new();road_material.shader=preload("res://scripts/concept_road.gdshader");road_material.render_priority=-10
	var sprite=QuadMesh.new();sprite.size=Vector2((world.FRAME_HALF_WIDTH+RAIL_FRAME_WIDTH)*2,64)
	road_sprite=world.mesh_node(sprite,self,road_material);road_sprite.name="PaintedHighway"
	road_sprite.position=Vector3(0,.008,-28);road_sprite.rotation_degrees.x=-90
	road_material.set_shader_parameter("rail_fraction",RAIL_FRAME_WIDTH/sprite.size.x)
	road_material.set_shader_parameter("image_half_width",sprite.size.x*.5)
	marker_material=ShaderMaterial.new();marker_material.shader=preload("res://scripts/ssrg_press.gdshader");marker_material.render_priority=-5
	marker_material.set_shader_parameter("artwork",preload("res://assets/ssrg/imported/judgment_Main_black_BG3.png"))
	for lane in SynkChart.LANES:
		var tick=QuadMesh.new();tick.size=Vector2(.035,.16)
		var mark=world.mesh_node(tick,self,marker_material);mark.position=Vector3(world.lane_x(lane),.04,.18);mark.rotation_degrees.x=-90
	refresh()

func refresh() -> void:
	active=world.game.highway_style in STYLES and not world.game.uses_ssrg_gameplay() and not world.game.uses_recorder_colors()
	visible=active
	if not world.cover_material:return
	world.cover_material.set_shader_parameter("concept_style",(2 if world.game.highway_style=="solar" else 1) if active else 0)
	if not active:return
	var solar=world.game.highway_style=="solar"
	var texture:Texture2D=STAGES[world.game.highway_style]
	world.cover_material.set_shader_parameter("concept_background",texture)
	world.cover_material.set_shader_parameter("concept_aspect",float(texture.get_width())/texture.get_height())
	# Own frame and road materials; no inherited additive glare or opaque plates over notes.
	var rail:Color=Color("f5c482") if solar else Color("b2f4ff")
	var custom=world.custom_color("rail_color")
	if custom!=null:rail=custom
	road_material.set_shader_parameter("artwork",ROAD_IMAGES[world.game.highway_style])
	road_material.set_shader_parameter("source_rail_fraction",.11 if solar else .085)
	road_material.set_shader_parameter("recolor_rails",custom!=null)
	road_material.set_shader_parameter("tint",rail)
	marker_material.set_shader_parameter("base_color",Color(rail,.6))
	# Reuse the source's painted judgment sprite as a thin timing ribbon.
	world.judgment_material.shader=preload("res://scripts/ssrg_press.gdshader")
	world.judgment_material.set_shader_parameter("artwork",preload("res://assets/ssrg/imported/judgment_Main_black_BG3.png"))
	world.get_node("JudgmentPads").scale.y=.025
	var band:Color=Color("ffd3a0") if solar else Color("a2efff")
	custom=world.custom_color("band_color")
	if custom!=null:band=custom
	world.judgment_material.set_shader_parameter("base_color",Color(band,.92))
	for border in world.judgment_borders:border.set_shader_parameter("color",Color.TRANSPARENT)
