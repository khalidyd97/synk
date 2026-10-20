extends Node3D

# All note positions are in world units. Camera perspective supplies the depth.
const CENTER_LANE = (SynkChart.LANES-1)*.5
# Original highway proportions, artwork size and lane spacing.
const HIGHWAY_HALF_WIDTH = 9.75
const EDGE_MARGIN = .2
const NOTE_SCALE = 1.3
const NOTE_WIDTH = 3.1*NOTE_SCALE
const FIT = 1.0
# Every lane, the outer two included, gets the same share of the highway.
const LANE_WIDTH = HIGHWAY_HALF_WIDTH*2.0/SynkChart.LANES
const PAD_HALF_WIDTH = HIGHWAY_HALF_WIDTH
const FRAME_HALF_WIDTH = HIGHWAY_HALF_WIDTH
const TRAIL_HALF = .8*NOTE_SCALE
const TAIL_CAP_SIZE = .65
# How far below the hit flash art its mirrored glow extends, as a fraction of the art height.
const HIT_MIRROR = .35
# The glowing band of Hold_Note_Pink.png spans u .225 to .68; using exactly that slice keeps
# the trail centered on its notes with its bright edges on the trail's outline.
const TRAIL_REGION = Vector4(.225,.27,.455,.43)
# The tap note art fades in on its left but is cut off at its right edge; trimming the left
# glow centers the note body on its lane.
const CAP_REGION = Vector4(.12,0,.88,1)
const BEAM_MAX_X = HIGHWAY_HALF_WIDTH-NOTE_WIDTH*.5
# Rail thickness for the optional raised style.
const RAIL_WIDTH = .6
# Smoky highway and golden judgment band.
const TRACK_COLOR = Color("050409")
const JUDGMENT_GOLD = Color(1.0,.86,.34)
# Depth of the judgment bar along the highway, in world units.
const JUDGMENT_DEPTH = 2.0
const TRACK_LENGTH = 60.0
# Palette indices represent note types: tap, sustained (hold/slide), flick.
const COLORS = SynkCoverPalette.DEFAULT
# The live palette; each song swaps in colors taken from its cover art.
var colors: Array = COLORS.duplicate()
var stage_color = Color("0b1030")
var cover_palette_active = false
var game: Control
var camera: Camera3D
var notes: Dictionary = {}
var note_meshes: Array = []
var materials: Array = []
var effects: Node3D
var recorder_guides: Node3D
var active_beams: Array = []
# Light columns that follow each finger touching the highway.
var finger_beams: Array = []
var finger_beam_material: ShaderMaterial
var animation_time = 0.0
var animated_materials: Array = []
var bursts: Array = []
var hit_pool: Array = []
var play_render_cursor = 0
var play_visibility: RefCounted
var reference_note_meshes: Dictionary = {}
var spark_mesh: SphereMesh
var miss_shake_remaining = 0.0
var cover_backdrop: MeshInstance3D
var ambient_motes: CPUParticles3D
var ambient_streaks: Array = []
var rail_atmosphere: Node3D
var ambient_side_motes: Array = []
var ambient_mote_material: StandardMaterial3D
var cover_material: ShaderMaterial
var ambient_palette: Gradient
var rail_edge_materials: Array = []
# Highway looks: the glossy "gold" rails and band, or the earlier "neon" glow rails.
var gold_nodes: Array = []
var neon_nodes: Array = []
var neon_rail_materials: Array = []
var judgment_borders: Array = []
var highway_shadow_material: ShaderMaterial
var highway_shadow: MeshInstance3D
var judgment_material: ShaderMaterial
var track_materials: Array = []
var sky_material: ShaderMaterial
# The cover plane sits this far in front of the camera, behind the whole highway.
const COVER_DISTANCE = 150.0
const CAMERA_POSITION = Vector3(0,10,10)
const CAMERA_PITCH = -29.0
# Highway angle setting: the camera swings around the judgment bar, keeping its distance and the
# bar's place on screen (touch input relies on it), so only the slope of the highway changes.
const BAR_DISTANCE = 14.142136
const BAR_BELOW_CENTER = 16.0
const MIN_ANGLE = 18.0
const MAX_ANGLE = 44.0
# Fixed gameplay lens, including the loading-card transition.
const GAMEPLAY_FOV = 45.0

func material(color: Color, alpha = 1.0) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = Color(color, alpha)
	result.emission_enabled = true; result.emission = color; result.emission_energy_multiplier = .65
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.no_depth_test = false
	return result

func mesh_node(mesh: Mesh, parent: Node3D, mat: Material = null) -> MeshInstance3D:
	var node = MeshInstance3D.new(); node.mesh = mesh
	if mat != null: node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func box(parent: Node3D, center: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new(); mesh.size = dimensions
	var node = mesh_node(mesh,parent,mat); node.position = center
	return node

func line(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var mesh = CylinderMesh.new(); mesh.top_radius = width*.5; mesh.bottom_radius = width*.5
	mesh.height = maxf(.001,a.distance_to(b)); mesh.radial_segments = 6
	var node = mesh_node(mesh,parent,mat); node.position = (a+b)*.5
	var direction = (b-a).normalized()
	node.quaternion = Quaternion(Vector3.UP,direction)
	return node

func lane_x(lane: float) -> float: return (lane-CENTER_LANE)*LANE_WIDTH
# Where a note is drawn: its lane centre, nudged inward on the outer lanes so the note
# (about two lanes wide) stays inside the rails. Judging and touch still use lane_x.
# Taps are judged on the note itself, not its lane: a touch counts when it lands within the
# note's drawn half-width at the judgement bar (plus a little grace).
func note_reach() -> float: return NOTE_WIDTH * .5 * game.note_size * 1.1
func note_x(lane: float) -> float:
	var limit = HIGHWAY_HALF_WIDTH - EDGE_MARGIN - NOTE_WIDTH*.5*game.note_size
	return clampf(lane_x(lane), -limit, limit)
# Notes travel the whole 60-unit track, from the far end to the judgement bar.
func visible_length() -> float: return TRACK_LENGTH
func travel_speed() -> float: return TRACK_LENGTH / game.note_travel_seconds()
func render_time() -> float:
	return game.visual_song_time if game.audio.playing and game.mode in ["play","record"] and game.countdown<=0 and game.resume_countdown<=0 else game.song_time
func note_position(lane: float, chart_time: float) -> Vector3:
	return Vector3(note_x(lane), .13, (render_time()-chart_time)*travel_speed())
var camera_revision = 0
var camera_state: Array = []
func apply_camera(shake: Vector3 = Vector3.ZERO) -> void:
	var position = camera_rest_position() + shake
	var rotation = Vector3(-highway_angle(),0,0)
	var state = [position,rotation]
	if state==camera_state: return
	camera_state = state; camera_revision += 1
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = GAMEPLAY_FOV
	camera.position = position; camera.rotation_degrees = rotation

func _ready() -> void:
	camera = Camera3D.new(); add_child(camera); camera.current = true
	camera.near = .1; camera.far = 260
	apply_camera()
	var environment = WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("06091e")
	var sky_shader = Shader.new()
	sky_shader.code = """shader_type sky;
	float star_hash(vec2 cell) {
		return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	}
	void sky() {
		// Flat dark sky: no horizon glow or aurora behind the highway.
		vec3 color = vec3(0.012, 0.013, 0.035);
		vec2 star_cell = floor(vec2(EYEDIR.x, EYEDIR.y) * 145.0);
		vec2 star_center = fract(vec2(EYEDIR.x, EYEDIR.y) * 145.0) - 0.5;
		float star = step(0.997, star_hash(star_cell)) * exp(-dot(star_center, star_center) * 80.0);
		float twinkle = 0.62 + 0.38 * sin(TIME * 1.7 + star_hash(star_cell + 9.0) * 6.283);
		color += vec3(0.11, 0.10, 0.20) * star * twinkle;
		COLOR = color;
	}"""
	sky_material = ShaderMaterial.new(); sky_material.shader = sky_shader
	var sky = Sky.new(); sky.sky_material = sky_material
	environment.environment.sky = sky; environment.environment.background_mode = Environment.BG_SKY
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("46356c")
	add_child(environment)
	for color in COLORS:
		materials.append(material(color))
		note_meshes.append(make_note_mesh(color))
	build_track()
	build_effects()
	build_play_aids()
	build_cover_backdrop()
	build_ambient_particles()
	rail_atmosphere=preload("res://scripts/stage_rail_effects.gd").new(); rail_atmosphere.world=self; add_child(rail_atmosphere)

func build_cover_backdrop() -> void:
	# Child of the camera so it always fills the view; drawn first so the highway blends over it.
	cover_material = ShaderMaterial.new(); cover_material.shader = preload("res://scripts/cover_backdrop.gdshader")
	cover_material.render_priority = -20
	animated_materials.append(weakref(cover_material))
	cover_backdrop = mesh_node(QuadMesh.new(),camera,cover_material)
	cover_backdrop.position = Vector3(0,0,-COVER_DISTANCE)
	cover_backdrop.visible = false

func ambient_material(texture: Texture2D, billboard: bool) -> StandardMaterial3D:
	# Additive, unshaded, colored per particle; drawn before the highway so the track stays on top.
	var result = StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.vertex_color_use_as_albedo = true
	result.albedo_texture = texture
	result.disable_receive_shadows = true; result.disable_fog = true
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard: result.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	result.render_priority = -15
	return result

func build_ambient_particles() -> void:
	var dot = GradientTexture2D.new(); dot.width = 64; dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL; dot.fill_from = Vector2(.5,.5); dot.fill_to = Vector2(1,.5)
	var falloff = Gradient.new(); falloff.set_color(0,Color.WHITE); falloff.set_color(1,Color(1,1,1,0))
	falloff.add_point(.35,Color(1,1,1,.55)); dot.gradient = falloff
	var palette = Gradient.new(); palette.set_color(0,Color("a36aff")); palette.set_color(1,Color("38baff"))
	palette.add_point(.5,Color("ff7ad9"))
	ambient_palette = palette
	# Drifting light motes filling the space around and beyond the track.
	ambient_motes = CPUParticles3D.new(); add_child(ambient_motes)
	var mote_mesh = QuadMesh.new(); mote_mesh.size = Vector2(1.5,1.5)
	ambient_mote_material = ambient_material(dot,true)
	mote_mesh.material = ambient_mote_material
	ambient_motes.mesh = mote_mesh
	ambient_motes.amount = 170; ambient_motes.lifetime = 9.0; ambient_motes.preprocess = 9.0
	ambient_motes.position = Vector3(0,6,-90)
	ambient_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ambient_motes.emission_box_extents = Vector3(65,14,60)
	ambient_motes.direction = Vector3(0,1,0); ambient_motes.spread = 35
	ambient_motes.gravity = Vector3.ZERO
	ambient_motes.initial_velocity_min = .6; ambient_motes.initial_velocity_max = 1.8
	ambient_motes.scale_amount_min = .5; ambient_motes.scale_amount_max = 1.8
	ambient_motes.color_initial_ramp = palette
	var mote_life = Gradient.new(); mote_life.set_color(0,Color(1,1,1,0)); mote_life.set_color(1,Color(1,1,1,0))
	mote_life.add_point(.25,Color(1,1,1,.9)); mote_life.add_point(.75,Color(1,1,1,.9))
	ambient_motes.color_ramp = mote_life
	# A closer band of motes along each side, so the space beside the track feels alive too.
	for side in [-1,1]:
		var near = ambient_motes.duplicate() as CPUParticles3D; add_child(near)
		near.amount = 45; near.position = Vector3(side*26,3,-40); near.emission_box_extents = Vector3(10,5,28)
		near.scale_amount_min = .35; near.scale_amount_max = 1.0
		ambient_side_motes.append(near)
	# Speed streaks shoot away from the camera along both sides of the highway.
	var streak_mesh = BoxMesh.new(); streak_mesh.size = Vector3(.07,.07,5.0)
	streak_mesh.material = ambient_material(null,false)
	for side in [-1,1]:
		var streaks = CPUParticles3D.new(); add_child(streaks)
		streaks.mesh = streak_mesh
		streaks.amount = 22; streaks.lifetime = 1.8; streaks.preprocess = 1.8
		streaks.position = Vector3(side*17,1.2,8)
		streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		streaks.emission_box_extents = Vector3(5,2.2,30)
		streaks.direction = Vector3(0,0,-1); streaks.spread = 0
		streaks.gravity = Vector3.ZERO
		streaks.initial_velocity_min = 32; streaks.initial_velocity_max = 51
		streaks.particle_flag_align_y = false
		streaks.color_initial_ramp = palette
		var streak_life = Gradient.new(); streak_life.set_color(0,Color(1,1,1,0)); streak_life.set_color(1,Color(1,1,1,0))
		streak_life.add_point(.3,Color(1,1,1,.7)); streak_life.add_point(.7,Color(1,1,1,.7))
		streaks.color_ramp = streak_life
		ambient_streaks.append(streaks)

func update_ambient_particles(beat: float) -> void:
	# Freeze with the game when paused, follow the note speed, and brighten motes on the beat.
	var running = game.mode in ["play","record"]
	ambient_motes.speed_scale = 1.0 if running else 0.0
	for motes in ambient_side_motes: motes.speed_scale = ambient_motes.speed_scale
	for streaks in ambient_streaks: streaks.speed_scale = (game.note_speed if running else 0.0)
	ambient_mote_material.albedo_color = Color(1,1,1).lerp(Color(1.8,1.8,1.8),beat)
	var particles=game.features.effect("Particles")
	ambient_motes.visible=particles>0; ambient_motes.color=Color(1,1,1,particles)
	for motes in ambient_side_motes:
		motes.visible=particles>0; motes.color=Color(1,1,1,particles)
	var lasers=game.features.effect("Lasers")
	for streaks in ambient_streaks:
		streaks.visible=lasers>0; streaks.color=Color(element_color("lasers",Color.WHITE),lasers)
	cover_material.set_shader_parameter("brightness",game.features.effect("Background brightness"))

func set_cover(texture: Texture2D, tint: Color) -> void:
	cover_material.set_shader_parameter("cover",texture)
	cover_material.set_shader_parameter("tint",tint)
	cover_material.set_shader_parameter("strength",1.0)
	# With no background or album art, the stage behind the highway is plain black.
	cover_material.set_shader_parameter("plain",texture == null)
	cover_material.set_shader_parameter("image_aspect",float(texture.get_width())/maxf(1.0,texture.get_height()) if texture else 1.0)
	cover_backdrop.visible = true

# Recolors notes, rails, the judgment bar, track, sky and particles to the cover's colors.
func apply_palette(palette: Dictionary) -> void:
	# Cached hit materials belong to the previous palette.
	clear_hit_effects()
	colors = palette.notes.duplicate()
	if colors.size()==3: colors.append(colors[1])
	cover_palette_active = palette.from_cover
	stage_color = palette.stage
	materials.clear(); note_meshes.clear()
	for color in colors:
		materials.append(material(color))
		note_meshes.append(make_note_mesh(color))
	refresh_highway_look()
	ambient_palette.offsets = PackedFloat32Array([0.0,.5,1.0])
	ambient_palette.colors = PackedColorArray([element_color("particles",colors[1]),element_color("particles",colors[1].lerp(colors[2],.5) if cover_palette_active else Color("ff7ad9")),element_color("particles",colors[0])])
	finger_beam_material.set_shader_parameter("tint",element_color("beams",colors[0]))
	for beam in active_beams:
		var mat: ShaderMaterial = beam.get_child(0).material_override
		mat.set_shader_parameter("tint",element_color("beams",colors[1])); mat.set_shader_parameter("recolor",true)
	# Notes already on screen were built with the old colors.
	clear_notes()

var backdrop_projection_state: Array = []
var backdrop_projection_updates = 0
func update_cover_backdrop() -> void:
	var state = [get_viewport().get_visible_rect().size,camera.global_transform,camera.projection,camera.fov,camera.size,camera.h_offset,camera.v_offset,camera.keep_aspect]
	if state!=backdrop_projection_state:
		backdrop_projection_state = state; backdrop_projection_updates += 1
		var viewport_size = get_viewport().get_visible_rect().size
		if viewport_size.y <= 0: return
		var aspect = viewport_size.x/viewport_size.y
		var height = camera.size*1.04 if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else 2.0*COVER_DISTANCE*tan(deg_to_rad(camera.fov*.5))*1.04
		(cover_backdrop.mesh as QuadMesh).size = Vector2(height*aspect,height)
		cover_material.set_shader_parameter("screen_aspect",aspect)
		# Track the projected rail silhouette without moving the camera or highway geometry.
		for side in [-1,1]:
			var far_point=camera.unproject_position(Vector3(side*FRAME_HALF_WIDTH,0,-50))/viewport_size
			var near_point=camera.unproject_position(Vector3(side*FRAME_HALF_WIDTH,0,0))/viewport_size
			var slope=(near_point.x-far_point.x)/maxf(.001,near_point.y-far_point.y)
			var top_x=far_point.x-far_point.y*slope
			cover_material.set_shader_parameter("glow_left_rail" if side==-1 else "glow_right_rail",Vector2(top_x,top_x+slope))
	# A soft brightness kick on every beat while the song plays.
	var beat = 0.0
	if game.mode=="play" and game.audio.playing:
		var beats = maxf(0.0,game.song_time)*float(game.chart_bpm())/60.0
		beat = exp(-(beats-floorf(beats))*5.0)
		cover_material.set_shader_parameter("glow_beat",.5+.5*cos(beats*TAU))
	elif game.mode!="paused": cover_material.set_shader_parameter("glow_beat",0.0)
	beat = clampf(maxf(beat * .6, loudness) + flare * .8, 0.0, 1.5)
	cover_material.set_shader_parameter("beat",beat)
	if flare > 0.0: cover_material.set_shader_parameter("glow_beat", 1.0)
	update_ambient_particles(beat)

func make_note_mesh(color: Color) -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline = [Vector2(-.34,-.25),Vector2(.34,-.25),Vector2(.43,-.16),Vector2(.43,.16),Vector2(.34,.25),Vector2(-.34,.25),Vector2(-.43,.16),Vector2(-.43,-.16)]
	var levels = [.035,.11,.23,.27]
	var scales = [.84,1.0,1.0,.88]
	var shades = [color.darkened(.65),color.darkened(.2),color,Color("fff1ff")]
	for level in 3:
		for i in 8:
			var j = (i+1)%8
			var a: Vector2 = outline[i]*scales[level]; var b: Vector2 = outline[j]*scales[level]
			var c: Vector2 = outline[j]*scales[level+1]; var d: Vector2 = outline[i]*scales[level+1]
			var vertices = [Vector3(a.x,levels[level],a.y),Vector3(b.x,levels[level],b.y),Vector3(c.x,levels[level+1],c.y),Vector3(d.x,levels[level+1],d.y)]
			for index in [0,1,2,0,2,3]:
				st.set_color(shades[level] if index < 2 else shades[level+1]); st.add_vertex(vertices[index])
	for i in 8:
		var a: Vector2 = outline[i]*.88; var b: Vector2 = outline[(i+1)%8]*.88
		st.set_color(color.lightened(.35)); st.add_vertex(Vector3(0,.27,0))
		st.set_color(color); st.add_vertex(Vector3(a.x,.27,a.y)); st.add_vertex(Vector3(b.x,.27,b.y))
	st.generate_normals()
	var mat = material(Color.WHITE); mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = false
	st.set_material(mat)
	return st.commit()

func track_material(color: Color, opacity: float) -> ShaderMaterial:
	# See-through highway that also dissolves into the background at its far end.
	var result = ShaderMaterial.new(); result.shader = preload("res://scripts/track_surface.gdshader")
	result.set_shader_parameter("color",color); result.set_shader_parameter("opacity",opacity)
	return result

func build_track() -> void:
	# The highway is see-through so the cover art behind the stage glows through the lanes.
	# Low render priority draws it before the notes and effects, which stay crisp on top.
	var base_material = track_material(TRACK_COLOR,.30); base_material.render_priority = -10
	track_materials.append(base_material)
	box(self,Vector3(0,-.15,-28),Vector3(19.65,.25,64),base_material)
	var surface = PlaneMesh.new(); surface.size = Vector2(FRAME_HALF_WIDTH*2.0,60)
	var surface_material = track_material(TRACK_COLOR,.55); surface_material.render_priority = -9
	track_materials.append(surface_material)
	var rail = mesh_node(surface,self,surface_material); rail.position = Vector3(0,.008,-30)
	# A translucent, darkened echo of the judgment color sits beneath the rails.
	highway_shadow_material=ShaderMaterial.new()
	highway_shadow_material.shader=preload("res://scripts/highway_shadow.gdshader")
	highway_shadow_material.render_priority=-8
	var shadow_plane=PlaneMesh.new(); shadow_plane.size=Vector2(FRAME_HALF_WIDTH*2.0,TRACK_LENGTH)
	highway_shadow=mesh_node(shadow_plane,self,highway_shadow_material)
	highway_shadow.name="HighwayColorShadow"; highway_shadow.position=Vector3(0,.014,-TRACK_LENGTH*.5)
	# Recording-only guides make lane targets readable without adding lines to gameplay.
	recorder_guides = Node3D.new(); recorder_guides.name = "RecorderGuides"; add_child(recorder_guides)
	var guide_material = material(Color("777bd5"),.38)
	for boundary in range(1,SynkChart.LANES):
		var guide_mesh = PlaneMesh.new(); guide_mesh.size = Vector2(.035,60+JUDGMENT_DEPTH*.5)
		var guide = mesh_node(guide_mesh,recorder_guides,guide_material)
		guide.position = Vector3(lane_x(boundary-.5),.055,(-60+JUDGMENT_DEPTH*.5)*.5)
	var marker_material = material(Color("8be8ff"),.72)
	for lane in SynkChart.LANES:
		var marker_mesh = PlaneMesh.new(); marker_mesh.size = Vector2(.22,.62)
		var marker = mesh_node(marker_mesh,recorder_guides,marker_material)
		marker.position = Vector3(lane_x(lane),.052,-.03)
	recorder_guides.visible = false
	# Gold look: raised glossy rails, each casting a soft shadow onto the lanes beside it.
	for side in [-1,1]:
		var tube = CylinderMesh.new(); tube.top_radius = RAIL_WIDTH*.5; tube.bottom_radius = RAIL_WIDTH*.5
		tube.height = 64; tube.radial_segments = 24; tube.rings = 1; tube.cap_top = false; tube.cap_bottom = false
		var edge_material = ShaderMaterial.new(); edge_material.shader = preload("res://scripts/rail_tube.gdshader")
		edge_material.set_shader_parameter("tint",colors[1] if side==1 else colors[0])
		edge_material.set_shader_parameter("tint_amount",.12 if cover_palette_active else 0.0)
		rail_edge_materials.append(edge_material)
		var edge = mesh_node(tube,self,edge_material)
		edge.position = Vector3(side*(FRAME_HALF_WIDTH+RAIL_WIDTH*.5),RAIL_WIDTH*.32,-28); edge.rotation_degrees.x = 90
		gold_nodes.append(edge)
		var shadow_mesh = PlaneMesh.new(); shadow_mesh.size = Vector2(.9,60)
		var shadow_material = ShaderMaterial.new(); shadow_material.shader = preload("res://scripts/rail_shadow.gdshader")
		shadow_material.set_shader_parameter("flip",side==1); shadow_material.render_priority = -8
		var shadow = mesh_node(shadow_mesh,self,shadow_material)
		shadow.position = Vector3(side*(FRAME_HALF_WIDTH-.45),.02,-30)
		gold_nodes.append(shadow)
	# Neon look: flat glowing rail strips with light running along them.
	for side in [-1,1]:
		var strip = PlaneMesh.new(); strip.size = Vector2(.28,64)
		var strip_material = ShaderMaterial.new(); strip_material.shader = preload("res://scripts/rail_edge.gdshader")
		animated_materials.append(weakref(strip_material))
		neon_rail_materials.append(strip_material)
		var neon_edge = mesh_node(strip,self,strip_material)
		neon_edge.position = Vector3(side*9.72,.035,-28)
		neon_nodes.append(neon_edge)
	# A bit deeper than the visible note face so the hit line reads clearly.
	var judgment_mesh = QuadMesh.new(); judgment_mesh.size = Vector2(PAD_HALF_WIDTH*2.0,JUDGMENT_DEPTH)
	judgment_material = ShaderMaterial.new(); judgment_material.shader = preload("res://scripts/judgment_bar.gdshader")
	animated_materials.append(weakref(judgment_material))
	var judgment_bar = mesh_node(judgment_mesh,self,judgment_material)
	judgment_bar.name = "JudgmentPads"
	judgment_bar.position = Vector3(0,.035,0); judgment_bar.rotation_degrees.x = -90
	for edge in [-1,1]:
		var edge_mesh = QuadMesh.new(); edge_mesh.size = Vector2(PAD_HALF_WIDTH*2.0,.025)
		var border = mesh_node(edge_mesh,judgment_bar,material(Color("fff1cf"),.85))
		border.position = Vector3(0,edge*JUDGMENT_DEPTH*.5,.005)
		judgment_borders.append(border.material_override)
	refresh_highway_look()

# A player's custom color, or null to follow the style and song palette.
func custom_color(key: String) -> Variant:
	if game!=null and game.uses_recorder_colors(): return null
	var role="rail" if key=="rail_color" else "band"
	if game!=null and game.highway_colors=="theme" and game.gameplay_colors.has(role): return element_color(role,Color.WHITE)
	var value = str(game.get(key)) if game != null and game.get(key) != null else ""
	return Color.from_string(value,Color.BLACK) if value != "" else null

func element_color(key: String,fallback: Color) -> Color:
	return SynkGameplayColors.resolve(game,key,fallback) if game!=null else fallback

func trail_color(palette: int) -> Color:
	return element_color("slide_trail" if palette==3 else "hold_trail",colors[palette])

func rail_glow_colors() -> Array:
	var custom=custom_color("rail_color")
	var gold=game.uses_recorder_colors() or game.highway_style=="gold"
	var left: Color=custom if custom!=null else (JUDGMENT_GOLD if gold and not cover_palette_active else colors[0])
	var right: Color=custom if custom!=null else (JUDGMENT_GOLD if gold and not cover_palette_active else colors[1])
	return [element_color("glow",left),element_color("glow",right)]

# Applies the chosen highway style, custom rail/band colors and highway darkness.
func refresh_highway_look() -> void:
	if judgment_material == null or track_materials.size() < 2: return
	var gold = game == null or game.uses_recorder_colors() or str(game.get("highway_style")) != "neon"
	var darkness = clampf(float(game.get("highway_opacity")),.3,1.6) if game != null and game.get("highway_opacity") != null else 1.0
	if game.uses_recorder_colors(): darkness=1.0
	for node in gold_nodes: node.visible = gold
	for node in neon_nodes: node.visible = not gold
	var rail = custom_color("rail_color")
	var band = custom_color("band_color")
	# Tap color on the left rail, sustained on the right, unless the player picked one color.
	for i in 2:
		var tint: Color = rail if rail != null else (colors[1] if i==1 else colors[0])
		rail_edge_materials[i].set_shader_parameter("tint",tint)
		rail_edge_materials[i].set_shader_parameter("tint_amount",1.0 if rail != null else (.45 if cover_palette_active else 0.0))
		neon_rail_materials[i].set_shader_parameter("tint",tint)
	if gold:
		judgment_material.shader = preload("res://scripts/judgment_bar.gdshader")
		# Adaptive colors pull the band toward the artwork's main color; the theme keeps it golden.
		var base: Color = band if band != null else (JUDGMENT_GOLD.lerp(colors[1].lightened(.15),.6) if cover_palette_active else JUDGMENT_GOLD)
		judgment_material.set_shader_parameter("base_color",base)
		judgment_material.set_shader_parameter("sweep_color",base.lerp(Color.WHITE,.6))
		track_materials[0].set_shader_parameter("color",stage_color.darkened(.88) if cover_palette_active else TRACK_COLOR)
		track_materials[1].set_shader_parameter("color",stage_color.darkened(.85) if cover_palette_active else TRACK_COLOR)
		track_materials[0].set_shader_parameter("opacity",minf(.95,.30*darkness))
		track_materials[1].set_shader_parameter("opacity",minf(.95,.55*darkness))
		for m in track_materials: m.set_shader_parameter("near_fraction",.72)
	else:
		judgment_material.shader = preload("res://scripts/judgment_neon.gdshader")
		judgment_material.set_shader_parameter("base_color",band if band != null else (colors[1].lerp(Color.WHITE,.15) if cover_palette_active else Color(.60,.36,1.0)))
		judgment_material.set_shader_parameter("sweep_color",band.lerp(Color.WHITE,.45) if band != null else (colors[0].lerp(Color.WHITE,.45) if cover_palette_active else Color(.68,.91,1.0)))
		track_materials[0].set_shader_parameter("color",stage_color.darkened(.45) if cover_palette_active else Color("080b25"))
		track_materials[1].set_shader_parameter("color",stage_color if cover_palette_active else Color("0b1030"))
		track_materials[0].set_shader_parameter("opacity",minf(.95,.36*darkness))
		track_materials[1].set_shader_parameter("opacity",minf(.95,.42*darkness))
		for m in track_materials: m.set_shader_parameter("near_fraction",1.0)
	for m in judgment_borders: m.albedo_color = Color(Color("fff1cf") if gold else Color("ead6ff"),.85 if gold else 1.0)
	var judgment_color: Color=judgment_material.get_shader_parameter("base_color")
	highway_shadow_material.set_shader_parameter("tint",judgment_color.darkened(.65))
	highway_shadow_material.set_shader_parameter("opacity",.2)
	for m in track_materials:
		m.set_shader_parameter("color",element_color("track",m.get_shader_parameter("color")))
	if cover_material:
		var glow=rail_glow_colors()
		cover_material.set_shader_parameter("rail_glow_left",glow[0])
		cover_material.set_shader_parameter("rail_glow_right",glow[1])
		# The soft glow that spread outside the rails is removed.
		cover_material.set_shader_parameter("rail_glow_opacity",0.0)

func build_effects() -> void:
	spark_mesh = SphereMesh.new(); spark_mesh.radius = .065; spark_mesh.height = .13
	finger_beam_material = ShaderMaterial.new(); finger_beam_material.shader = preload("res://scripts/finger_beam.gdshader")
	# Drawn over the judgment bar so the lit lane reads all the way down to the bar's near edge.
	finger_beam_material.render_priority = 2
	finger_beam_material.set_shader_parameter("rail_half_width",FRAME_HALF_WIDTH)
	var beam_mesh = PlaneMesh.new(); beam_mesh.size = Vector2(NOTE_WIDTH,58+JUDGMENT_DEPTH*.5)
	for i in 10:
		var finger_beam = mesh_node(beam_mesh,self,finger_beam_material)
		finger_beam.position = Vector3(0,.045,(-58+JUDGMENT_DEPTH*.5)*.5); finger_beam.visible = false
		finger_beams.append(finger_beam)
	for lane in SynkChart.LANES:
		var beam = Node3D.new(); add_child(beam); beam.position = Vector3(lane_x(lane),.08,0)
		own_material(artwork(beam,"Hit_Effect_Pink",1,Vector3(0,1.35*FIT,0),Vector2(4.4,3.3)*FIT,Vector4(0,0,1,1),.75))  # each lane glow pulses on its own
		beam.visible = false; active_beams.append(beam)

# --- Shared note materials ------------------------------------------------------------
# Every note of the same look uses one material, so a dense chart draws with a handful of
# materials instead of hundreds. A note that needs its own state (a held trail being eaten,
# a missed note turning grey, a recorder ghost) gets a private copy at that moment.
var shared_materials: Dictionary = {}
func shared(key: String, build: Callable) -> Material:
	if shared_materials.has(key): return shared_materials[key]
	var mat: Material = build.call()
	mat.set_meta("shared", true)
	shared_materials[key] = mat
	return mat
func clear_shared_materials() -> void:
	shared_materials.clear()
# Gives this mesh its own copy of a shared material before it is changed.
func own_material(mesh: GeometryInstance3D) -> Material:
	var mat: Material = mesh.material_override
	if mat == null and mesh is MeshInstance3D and mesh.mesh: mat = mesh.mesh.surface_get_material(0)
	if mat == null or not mat.has_meta("shared"): return mat
	var copy: Material = mat.duplicate()
	copy.remove_meta("shared")
	mesh.material_override = copy
	if copy is ShaderMaterial: animated_materials.append(weakref(copy))
	return copy

func asset_material(name: String, palette: int, region = Vector4(0,0,1,1), opacity = 1.0) -> ShaderMaterial:
	return shared("asset|%s|%d|%s|%s|%s" % [name, palette, region, opacity, colors[palette]], func(): return build_asset_material(name, palette, region, opacity))
func build_asset_material(name: String, palette: int, region = Vector4(0,0,1,1), opacity = 1.0) -> ShaderMaterial:
	var mat = ShaderMaterial.new(); mat.shader = load("res://scripts/neon_asset.gdshader")
	mat.set_shader_parameter("artwork",load("res://assets/neon/"+name+".png"))
	mat.set_shader_parameter("region",region); mat.set_shader_parameter("opacity",opacity)
	# Blue tap artwork keeps its gradient; sustained and flick art takes its type color.
	mat.set_shader_parameter("recolor",palette!=0 or cover_palette_active or (game.highway_colors=="theme" and game.gameplay_colors.has("tap"))); mat.set_shader_parameter("tint",colors[palette])
	mat.set_shader_parameter("motion",.7 if name.begins_with("Hold_") else (.35 if name.begins_with("Flick_") else .12))
	if name.begins_with("Tap_") or name.begins_with("Hold_") or name.begins_with("Flick_") or name.begins_with("Slide_"):
		mat.set_shader_parameter("glow_pulse",.18)
	animated_materials.append(weakref(mat))
	return mat

func touch_hit_position(lane: float,pointer_id: int) -> Vector3:
	var x=lane_x(lane)
	if game.pointers.has(pointer_id) and game.pointers[pointer_id].has("world"):
		x=game.pointers[pointer_id].world.x
	# Follow horizontal touch movement, but never let the burst drift up/down the track.
	return Vector3(clampf(x,-HIGHWAY_HALF_WIDTH,HIGHWAY_HALF_WIDTH),.035,0)

# --- "Bloom" hit effect style (Settings > Visual effects > Hit effects) -------------------
# A flat overexposed flash with expanding rings on the judgement line, plus rising sparkles.
# Two quads per hit, pooled; holds keep re-pulsing while they are held.
const BLOOM_LIFE = .38
var prewarming_hits = false
var bloom_pool: Array = []
var blooms: Array = []
func make_bloom() -> Dictionary:
	var node = Node3D.new(); add_child(node)
	var flat_mesh = PlaneMesh.new(); flat_mesh.size = Vector2(10.0, 6.0)
	var flat_mat = ShaderMaterial.new(); flat_mat.shader = preload("res://scripts/bloom_hit.gdshader"); flat_mat.render_priority = 5
	var flat = mesh_node(flat_mesh, node, flat_mat); flat.position = Vector3(0, .02, 0)
	var spark_mesh = QuadMesh.new(); spark_mesh.size = Vector2(6.0, 5.0)
	var spark_mat = ShaderMaterial.new(); spark_mat.shader = preload("res://scripts/bloom_sparks.gdshader"); spark_mat.render_priority = 6
	var sparks = mesh_node(spark_mesh, node, spark_mat); sparks.position = Vector3(0, 2.4, 0); sparks.rotation = camera.rotation
	node.visible = false
	return {"node": node, "flat": flat_mat, "sparks": spark_mat, "age": 0.0, "sustain_entry": {}, "pointer_id": -999, "kind": "tap"}
func prefill_blooms(count: int = 24) -> void:
	while bloom_pool.size() + blooms.size() < count: bloom_pool.append(make_bloom())
func spawn_bloom(lane: float, kind: String, sustain_entry: Dictionary, pointer_id: int) -> void:
	if blooms.size() >= 24: bloom_pool.append(blooms.pop_front())
	var b: Dictionary = bloom_pool.pop_back() if not bloom_pool.is_empty() else make_bloom()
	var palette = palette_for_kind("tap" if kind in ["slide","flick"] else kind)
	var c: Color = element_color("hits", colors[palette])
	c = Color.from_hsv(c.h, minf(1.0, c.s * 1.15), 1.0)  # full-brightness glow in the note colour
	b.flat.set_shader_parameter("tint", c); b.sparks.set_shader_parameter("tint", c)
	b.sparks.set_shader_parameter("seed", randf() * 100.0)
	b.age = 0.0; b.kind = kind; b.sustain_entry = sustain_entry; b.pointer_id = pointer_id
	b.node.position = touch_hit_position(lane, pointer_id) + Vector3(0, .06, 0)
	b.node.visible = true; blooms.append(b)
func animate_blooms(delta: float, running: bool) -> void:
	var intensity = game.features.effect("Hit flashes"); var particles = game.features.effect("Particles")
	for i in range(blooms.size() - 1, -1, -1):
		var b: Dictionary = blooms[i]
		var sustained = not b.sustain_entry.is_empty() and not b.sustain_entry.done
		if running: b.age += delta
		if sustained:
			# Held notes re-pulse the bloom and follow the finger or slide head.
			if b.age >= BLOOM_LIFE * .7: b.age = BLOOM_LIFE * .18
			if game.pointers.has(int(b.sustain_entry.get("pointer", b.pointer_id))) and game.pointers[int(b.sustain_entry.get("pointer", b.pointer_id))].has("world"):
				b.node.position = touch_hit_position(0, int(b.sustain_entry.get("pointer", b.pointer_id))) + Vector3(0, .06, 0)
			elif b.kind == "slide": b.node.position.x = note_x(game.play_lane_at(b.sustain_entry,game.song_time))
		elif not b.sustain_entry.is_empty(): b.sustain_entry = {}
		if (not sustained and b.age >= BLOOM_LIFE) or game.mode not in ["play","record","paused"]:
			b.node.visible = false; blooms.remove_at(i); bloom_pool.append(b); continue
		var t = b.age / BLOOM_LIFE
		b.flat.set_shader_parameter("age", t); b.flat.set_shader_parameter("strength", intensity)
		b.sparks.set_shader_parameter("age", t); b.sparks.set_shader_parameter("strength", particles)

func spawn_hit(lane: float, kind: String, direction: int = 0, sustain_entry: Dictionary = {},pointer_id: int=-999) -> void:
	if game.hit_style == "bloom" and not prewarming_hits:
		spawn_bloom(lane, kind, sustain_entry, pointer_id); return
	if bursts.size() >= MAX_ACTIVE_HITS:
		recycle_hit(bursts.pop_front())
	var palette = palette_for_kind("tap" if kind in ["slide","flick"] else kind)
	var hit_color=element_color("hits",colors[palette])
	var pool_key=str(palette)+("flick"+str(direction) if kind=="flick" else "normal")
	for index in hit_pool.size():
		if hit_pool[index].pool_key!=pool_key: continue
		var reused: Dictionary=hit_pool.pop_at(index)
		reused.age=0.0; reused.kind=kind; reused.sustain_entry=sustain_entry; reused.pointer_id=pointer_id
		reused.node.position=touch_hit_position(lane,pointer_id)+Vector3(0,.065,0)
		reused.flash.rotation=camera.rotation; reused.fill.rotation=camera.rotation
		reused.flash.position=Vector3(0,(2.25-4.0*HIT_MIRROR*.5)*FIT,0)
		reused.fill.position=Vector3(0,2.25*FIT,0)
		reused.flash.material_override.set_shader_parameter("opacity",0.0)
		reused.fill.material_override.set_shader_parameter("opacity",0.0)
		reused.ring.material_override.albedo_color.a=0.0
		reused.particle_batch.multimesh.visible_instance_count = 0
		reused.node.show()
		bursts.append(reused)
		return
	var node = Node3D.new(); add_child(node); node.position = touch_hit_position(lane,pointer_id)+Vector3(0,.065,0)
	# Share the regular hit flash across taps, slides and flicks.
	var flash = artwork(node,"Hit_Effect_Blue" if palette==0 else "Hit_Effect_Pink",palette,Vector3(0,(2.25-4.0*HIT_MIRROR*.5)*FIT,0),Vector2(5.8,4.0*(1.0+HIT_MIRROR))*FIT)
	own_material(flash)  # each hit fades on its own
	flash.material_override.set_shader_parameter("mirror_extra",HIT_MIRROR)
	flash.material_override.set_shader_parameter("tint",hit_color)
	flash.material_override.set_shader_parameter("recolor",palette!=0 or cover_palette_active or (game.highway_colors=="theme" and game.gameplay_colors.has("hits")))
	var fill_mesh = QuadMesh.new(); fill_mesh.size = Vector2(5.9,4.2)*FIT
	var fill_material = ShaderMaterial.new(); fill_material.shader = preload("res://scripts/hit_fill.gdshader")
	fill_material.set_shader_parameter("tint",hit_color)
	var fill = mesh_node(fill_mesh,node,fill_material)
	fill.position = Vector3(0,2.25*FIT,0); fill.rotation = camera.rotation
	var flick_axis = camera.basis * [Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(direction,0,3)]
	var ring_mesh = TorusMesh.new(); ring_mesh.inner_radius=.9*FIT; ring_mesh.outer_radius=.97*FIT; ring_mesh.rings=32; ring_mesh.ring_segments=6
	var ring = mesh_node(ring_mesh,node,material(hit_color,.8))
	var particles: Array = []
	# One instanced draw per burst replaces one scene object/draw per spark.
	var particle_count = (10 if kind=="flick" else 6) if OS.has_feature("mobile") else (24 if kind=="flick" else 12)
	var particle_material = material(element_color("sparks",colors[palette].lightened(.65) if kind=="flick" else colors[palette]))
	var streak_mesh = BoxMesh.new(); streak_mesh.size=Vector3(.035,.035,.42)
	var instances = MultiMesh.new(); instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = streak_mesh if kind=="flick" else spark_mesh
	instances.instance_count = particle_count; instances.visible_instance_count = 0
	var batch = MultiMeshInstance3D.new(); batch.multimesh = instances
	batch.material_override = particle_material; batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(batch)
	for i in particle_count:
		var angle = i*TAU/float(particle_count)
		var velocity = Vector3(cos(angle)*3.5,3.0+float(i%4)*.9,sin(angle)*1.4-.8)
		var basis = Basis.IDENTITY
		if kind=="flick":
			var sideways = camera.basis * [Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT,Vector3.UP][clampi(direction,0,3)]
			velocity = flick_axis*(5.0+float(i%7)*1.4)+sideways*sin(angle)*4.8
			basis = Basis(Quaternion(Vector3.BACK,velocity.normalized()))
		particles.append({"velocity":velocity,"basis":basis})
	bursts.append({"node":node,"age":0.0,"flash":flash,"fill":fill,"ring":ring,"particles":particles,"particle_batch":batch,"kind":kind,"flick_axis":flick_axis,"sustain_entry":sustain_entry,"pointer_id":pointer_id,"pool_key":pool_key})

func recycle_hit(burst: Dictionary) -> void:
	burst.node.hide(); burst.sustain_entry={}
	if hit_pool.size()<HIT_POOL_LIMIT: hit_pool.append(burst)
	else: burst.node.queue_free()

# Fill the hit-effect pool for the chart before play, so even a dense opening never builds a
# flash, ring and spark set mid-song. Counts cover the most hits of each kind that can be on
# screen at once (a hit lasts about 0.65 s); every flick direction the chart uses gets its own.
const MAX_ACTIVE_HITS = 32
const HIT_POOL_LIMIT = MAX_ACTIVE_HITS * 6
# Sweep effect lifetimes, including sustain heads, releases, and checkpoint flashes.
# Each family is capped by the same limit as active effects, with a bounded total pool.
func chart_hit_pool_requirements() -> Dictionary:
	var families: Dictionary = {}
	for entry in game.live:
		var note: Dictionary = entry.note
		var kind = str(note.kind)
		var key = "1normal" if kind=="hold" else ("0flick"+str(int(note.get("direction",1))) if kind=="flick" else "0normal")
		if not families.has(key): families[key] = []
		var begin = float(note.time)
		var finish = begin + float(note.duration)
		var life = .65 + (float(note.duration) if kind in ["hold","slide"] else 0.0)
		families[key].append(Vector2(begin-.23,1)); families[key].append(Vector2(begin+life+.23,-1))
		if kind in ["hold","slide"]:
			families[key].append(Vector2(finish-.23,1)); families[key].append(Vector2(finish+.88,-1))
			for offset in note.get("checkpoints",[]):
				var at = begin + float(offset)
				families[key].append(Vector2(at,1)); families[key].append(Vector2(at+.88,-1))
	var wanted: Dictionary = {}
	for key in families:
		var events: Array = families[key]
		events.sort_custom(func(a,b): return a.y < b.y if a.x==b.x else a.x < b.x)
		var active = 0; var peak = 0
		for event in events:
			active += int(event.y); peak = maxi(peak,active)
		wanted[key] = mini(MAX_ACTIVE_HITS,peak)
	return wanted

# Build a missing effect without borrowing already prepared inventory.
func add_pooled_hit(pool_key: String) -> void:
	var existing_pool=hit_pool; hit_pool=[]
	var kind="hold" if pool_key=="1normal" else ("flick" if pool_key.begins_with("0flick") else "tap")
	var direction=int(pool_key.trim_prefix("0flick")) if kind=="flick" else 0
	prewarming_hits=true; spawn_hit(5,kind,direction); prewarming_hits=false
	var hit=bursts.pop_back(); hit_pool=existing_pool; recycle_hit(hit)

func prefill_hits() -> void:
	var wanted = chart_hit_pool_requirements()
	var have = {}
	for burst in hit_pool+bursts: have[burst.pool_key] = int(have.get(burst.pool_key, 0)) + 1
	var made: Array = []
	if game.hit_style == "bloom": prefill_blooms(); return
	# Build only missing inventory; do not consume the warm instances being counted.
	var existing_pool = hit_pool
	hit_pool = []
	prewarming_hits = true
	for pool_key in wanted:
		var kind = "hold" if pool_key == "1normal" else ("flick" if pool_key.begins_with("0flick") else "tap")
		var dir = int(pool_key.trim_prefix("0flick")) if kind == "flick" else 0
		for i in maxi(0, int(wanted[pool_key]) - int(have.get(pool_key, 0))):
			spawn_hit(5, kind, dir); made.append(bursts.pop_back())
	prewarming_hits = false
	hit_pool = existing_pool
	for burst in made: recycle_hit(burst)

# --- Play aids -------------------------------------------------------------------------
# Lane hints, the hit-window preview, miss lane flashes, combo flares, chord lines,
# Hidden/Sudden modifiers and a loudness-driven stage pulse. Settings live in game.extras.
var window_bands: Array = []
var miss_flashes: Array = []
var flare = 0.0
var chords: Array = []
var loudness = 0.0
var spectrum: AudioEffectSpectrumAnalyzerInstance

func extras_setting(key: String, fallback: Variant) -> Variant:
	if game == null or game.get("extras") == null: return fallback
	return game.extras.settings.get(key, fallback)

func build_play_aids() -> void:
	# PERFECT and GREAT bands on the judgment line, shown during the countdown.
	for i in 2:
		var band = mesh_node(PlaneMesh.new(), self, material(Color("7dffcf") if i == 0 else Color("6fc8ff"), .22 if i == 0 else .12))
		band.position = Vector3(0, .05 + i * .002, 0); band.visible = false; window_bands.append(band)
	# One red flash per lane for misses.
	for lane in SynkChart.LANES:
		var mesh = PlaneMesh.new(); mesh.size = Vector2(LANE_WIDTH * .96, 9.0)
		var flash_material = material(Color("ff3355"), 0.0); flash_material.render_priority = 3
		var node = mesh_node(mesh, self, flash_material); node.position = Vector3(lane_x(lane), .06, -4.5); node.visible = false
		miss_flashes.append({"node": node, "material": flash_material, "amount": 0.0})
	# Loudness from the master bus, for a stage that pulses with the music rather than a metronome.
	var analyzer = AudioEffectSpectrumAnalyzer.new(); analyzer.buffer_length = .1; analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
	AudioServer.add_bus_effect(0, analyzer)
	spectrum = AudioServer.get_bus_effect_instance(0, AudioServer.get_bus_effect_count(0) - 1)

func refresh_play_aids() -> void:
	pass  # Settings are read every frame; nothing needs rebuilding.

func flash_miss_lane(lane: float) -> void:
	if miss_flashes.is_empty(): return
	var flash_entry: Dictionary = miss_flashes[clampi(roundi(lane), 0, SynkChart.MAX_LANE)]
	flash_entry.amount = 1.0; flash_entry.node.visible = true

func rail_flare() -> void:
	flare = 1.0

# --- Combo multiplier effect -------------------------------------------------------------
# Each time the score multiplier steps up (every 100 combo): a gold wave sweeps from the
# judgement line to the horizon with a bright leading edge, the judgement bar glows gold,
# and the rails flare.
const GOLD = Color("ffd257")
var gold_wave: MeshInstance3D
var gold_bar: MeshInstance3D
var gold_age = -1.0
func gold_material(edge_only: bool) -> ShaderMaterial:
	var m = ShaderMaterial.new(); m.shader = preload("res://scripts/gold_wave.gdshader")
	m.set_shader_parameter("edge_only", 1.0 if edge_only else 0.0); m.render_priority = 4
	return m
func multiplier_wave() -> void:
	if gold_wave == null:
		# Leading edge at the far end of the band (UV.y 0), trail behind it toward the player.
		var band = PlaneMesh.new(); band.size = Vector2(HIGHWAY_HALF_WIDTH * 2.0, 14.0)
		gold_wave = mesh_node(band, self, gold_material(false))
		var bar = PlaneMesh.new(); bar.size = Vector2(HIGHWAY_HALF_WIDTH * 2.0, JUDGMENT_DEPTH * 2.2)
		gold_bar = mesh_node(bar, self, gold_material(true))
	gold_age = 0.0; rail_flare()
	for node in [gold_wave, gold_bar]: node.visible = true
func update_multiplier_wave(delta: float) -> void:
	if gold_age < 0.0: return
	if game.mode != "paused": gold_age += delta
	var t = clampf(gold_age / 1.5, 0.0, 1.0)
	gold_wave.position = Vector3(0, .07, -ease(t, .6) * 62.0 + 7.0)
	gold_bar.position = Vector3(0, .08, 0)
	(gold_wave.material_override as ShaderMaterial).set_shader_parameter("strength", 1.0 - t * t)
	(gold_bar.material_override as ShaderMaterial).set_shader_parameter("strength", .9 * (1.0 - clampf(gold_age / 1.0, 0.0, 1.0)))
	if t >= 1.0:
		gold_age = -1.0
		for node in [gold_wave, gold_bar]: node.visible = false

func update_play_aids(delta: float) -> void:
	var playing = game.mode == "play" or (game.mode == "paused" and game.paused_mode == "play")
	var counting = game.mode == "play" and game.countdown > 0
	var show_bands = counting and bool(extras_setting("window_preview", true)) and game.get("extras") != null
	for i in window_bands.size():
		window_bands[i].visible = show_bands
		if show_bands:
			var window = game.extras.perfect_window() if i == 0 else game.extras.great_window()
			(window_bands[i].mesh as PlaneMesh).size = Vector2(HIGHWAY_HALF_WIDTH * 2.0, maxf(.05, window * travel_speed() * 2.0))
	for flash_entry in miss_flashes:
		if flash_entry.amount <= 0.0: continue
		flash_entry.amount = maxf(0.0, flash_entry.amount - delta * 3.0)
		flash_entry.material.albedo_color.a = .35 * flash_entry.amount
		flash_entry.node.visible = flash_entry.amount > 0.0
	flare = maxf(0.0, flare - delta * 1.6)
	if spectrum and game.audio.playing:
		var low = spectrum.get_magnitude_for_frequency_range(30, 180).length()
		var target = clampf(low * 6.0, 0.0, 1.0)
		loudness = lerpf(loudness, target, 1.0 - exp(-delta * (18.0 if target > loudness else 5.0)))
	else: loudness = lerpf(loudness, 0.0, 1.0 - exp(-delta * 5.0))
	# Chord lines follow their notes.
	if playing:
		for chord in chords:
			var t = float(chord.time)
			var visible_now = t - render_time() <= game.note_travel_seconds() and render_time() - t < .2 and not chord_done(chord)
			chord.node.visible = visible_now
			if visible_now: chord.node.position.z = (render_time() - t) * travel_speed()
	else:
		for chord in chords: chord.node.visible = false

func chord_done(chord: Dictionary) -> bool:
	for index in chord.indices:
		if index < game.live.size() and not game.live[index].done: return false
	return true

func build_chords() -> void:
	for chord in chords: chord.node.queue_free()
	chords.clear()
	if not game.uses_recorder_colors(): return  # Chord lines only in the recorder.
	var by_time: Dictionary = {}
	for i in game.live.size():
		var key = roundi(float(game.live[i].note.time) * 1000.0)
		if not by_time.has(key): by_time[key] = []
		by_time[key].append(i)
	var line_material = material(Color("f2ecff"), .55); line_material.render_priority = 1
	for key in by_time:
		var indices: Array = by_time[key]
		if indices.size() < 2: continue
		var low = 99.0; var high = -1.0
		for i in indices:
			low = minf(low, float(game.live[i].note.lane)); high = maxf(high, float(game.live[i].note.lane))
		if high - low < 1.0: continue
		var mesh = BoxMesh.new(); mesh.size = Vector3((high - low) * LANE_WIDTH, .04, .14)
		var node = mesh_node(mesh, self, line_material)
		node.position = Vector3((lane_x(low) + lane_x(high)) * .5, .16, 0); node.visible = false
		chords.append({"time": key / 1000.0, "indices": indices, "node": node})

# Hidden: notes vanish as they approach the line. Sudden: notes appear late, partway down.
func modifier_hides(z: float) -> bool:
	var distance = -z
	if bool(extras_setting("sudden", false)) and distance > visible_length() * .5: return true
	if bool(extras_setting("hidden", false)) and distance < visible_length() * .28 and distance > .5: return true
	return false

func clear_hit_effects() -> void:
	# Pooled effects for the previous chart are freed; prefill_hits builds the next set.
	for burst in bursts+hit_pool: burst.node.queue_free()
	bursts.clear(); hit_pool.clear()
	for bloom in blooms+bloom_pool: bloom.node.queue_free()
	blooms.clear(); bloom_pool.clear()
	gold_age=-1; flare=0; miss_shake_remaining=0
	for node in [gold_wave,gold_bar]:
		if is_instance_valid(node): node.visible=false
	for beam in finger_beams+active_beams: beam.visible=false
	for entry in miss_flashes:
		entry.amount=0; entry.node.visible=false; entry.material.albedo_color.a=0

func clear_notes() -> void:
	clear_shared_materials()
	play_render_cursor=0; play_visibility=null
	prebuilding=false; prebuild_queue.clear(); prebuild_total=0; prebuild_index=0
	for entry in notes.values(): entry.node.queue_free()
	notes.clear()

func animate_effects(delta: float) -> void:
	var running = game.mode in ["play","record"]
	if running: animation_time += delta
	# Every highway shader reads this one global clock (project setting shader_globals/synk_time).
	RenderingServer.global_shader_parameter_set("synk_time",animation_time)
	# Settings read once per frame, not once per burst or particle.
	animate_blooms(delta, running)
	var hit_intensity=game.features.effect("Hit flashes")
	var particle_share=game.features.effect("Particles")
	var hold_wave = .5+.5*sin(animation_time*TAU*2.8)
	for i in range(bursts.size()-1,-1,-1):
		var burst: Dictionary = bursts[i]
		var sustained = not burst.sustain_entry.is_empty() and not burst.sustain_entry.done
		if not sustained and not burst.sustain_entry.is_empty():
			burst.sustain_entry={}
			burst.age=.45
		if running: burst.age += delta
		if (not sustained and burst.age>=.65) or game.mode not in ["play","record","paused"]:
			recycle_hit(burst); bursts.remove_at(i); continue
		var t = minf(float(burst.age)/.65,1.0)
		# A quick, full flash that holds its body before fading out.
		var fade = pow(1.0-smoothstep(.10,1.0,t),1.5)
		var attack = minf(1.0,burst.age/.018)
		var hold_blend = smoothstep(0.0,.18,burst.age) if sustained else 0.0
		if sustained: burst.pointer_id=int(burst.sustain_entry.get("pointer",burst.pointer_id))
		if sustained and game.pointers.has(burst.pointer_id) and game.pointers[burst.pointer_id].has("world"):
			burst.node.position=touch_hit_position(0,burst.pointer_id)+Vector3(0,.065,0)
		elif sustained and burst.kind=="slide":
			# Keep the normal hit burst on the moving slide head, with repeated flashes.
			burst.node.position.x = note_x(game.play_lane_at(burst.sustain_entry,game.song_time))
		var flash_opacity = lerpf(attack*fade,.60+hold_wave*.26,hold_blend)
		var fill_opacity = lerpf(attack*fade,.55+hold_wave*.22,hold_blend)
		if sustained and burst.kind=="slide":
			var slide_flash = .18+.82*pow(hold_wave,2.0)
			flash_opacity = lerpf(attack*fade,slide_flash,hold_blend); fill_opacity = flash_opacity
		burst.flash.material_override.set_shader_parameter("opacity",flash_opacity*hit_intensity)
		burst.fill.material_override.set_shader_parameter("opacity",fill_opacity*hit_intensity)
		burst.fill.scale = Vector3(1.0+t*.7,1.0+t*.35,1).lerp(Vector3(1.18+hold_wave*.15,1.05+hold_wave*.14,1),hold_blend)
		burst.flash.scale = Vector3(1.0+t*.6,1.0+t*.25,1).lerp(Vector3(1.14+hold_wave*.12,1.0+hold_wave*.12,1),hold_blend)
		burst.ring.scale = Vector3.ONE*lerpf(.8+t*.75,1.12+hold_wave*.22,hold_blend)
		burst.ring.material_override.albedo_color.a = lerpf(fade*.8,.15+hold_wave*.25,hold_blend)*hit_intensity
		var particle_count = burst.particles.size()
		var shown_count = clampi(ceili(particle_count*particle_share),0,particle_count)
		var instances: MultiMesh = burst.particle_batch.multimesh
		instances.visible_instance_count = shown_count
		for particle_index in shown_count:
			var particle = burst.particles[particle_index]
			var position: Vector3 = particle.velocity*burst.age
			if burst.kind=="flick": position += Vector3(0,1.8,0)
			else: position += Vector3(0,-2.5*burst.age*burst.age,0)
			instances.set_instance_transform(particle_index,Transform3D(particle.basis.scaled(Vector3.ONE*maxf(.01,1-t)),position))

func artwork(parent: Node3D, name: String, palette: int, position_value: Vector3, dimensions: Vector2, region = Vector4(0,0,1,1), opacity = 1.0) -> MeshInstance3D:
	var quad = QuadMesh.new(); quad.size = dimensions
	var node = mesh_node(quad,parent,asset_material(name,palette,region,opacity))
	node.position = position_value; node.rotation = camera.rotation
	return node

func palette_for_kind(kind: String) -> int:
	if kind=="flick": return 2
	if kind=="slide": return 3
	if kind=="hold": return 1
	return 0

# Tails reuse the exact head artwork, with their own relative size.
func make_cap(parent: Node3D, lane: float, offset: float, palette: int, recording = false, size = 1.0) -> MeshInstance3D:
	size*=game.note_size
	var position_value = Vector3(note_x(lane),.2,offset*travel_speed()*(1 if recording else -1))
	if game.round_notes():
		return make_circle_cap(parent,position_value,palette,size)
	return artwork(parent,"Tap_Note_Blue" if palette==0 else "Tap_Note_Pink",palette,position_value,Vector2(NOTE_WIDTH,1.4*FIT)*size,CAP_REGION)

func make_circle_cap(parent: Node3D, position_value: Vector3, palette: int, size = 1.0) -> MeshInstance3D:
	# The supplied artwork already contains its perspective and thickness.
	# Face the camera once so it keeps that silhouette rather than flattening twice.
	var radius = 1.16*NOTE_SCALE*size
	var role=["tap","hold","flick","slide"][palette]
	# Artwork, its base hue (rotated to each note colour) and its aspect ratio.
	var puck = game.note_shape=="puck"
	var art: Texture2D = preload("res://assets/neon/Circle_Note_Puck.png") if puck else preload("res://assets/neon/Circle_Note_Reference.png")
	var base_hue = .76 if puck else .53
	var mat = shared("circle|%s|%d|%s|%s|%s" % [game.note_shape, palette, colors[palette], game.highway_colors, game.uses_recorder_colors()], func():
		var m = ShaderMaterial.new(); m.shader = preload("res://scripts/reference_note.gdshader")
		m.set_shader_parameter("artwork",art)
		m.set_shader_parameter("hue_shift",colors[palette].h-base_hue)
		if game.highway_colors=="theme" and not game.uses_recorder_colors() and game.gameplay_colors.has(role):
			m.set_shader_parameter("saturation_scale",colors[palette].s/.78)
			m.set_shader_parameter("value_scale",colors[palette].v)
		return m)
	var mesh_key = "%s|%s" % [game.note_shape, size]
	if not reference_note_meshes.has(mesh_key):
		var quad = QuadMesh.new()
		# The puck art has no wide halo margin, so it is drawn a little narrower.
		var width = radius/.4*(.72 if puck else 1.0)
		quad.size = Vector2(width,width*art.get_height()/art.get_width())
		reference_note_meshes[mesh_key]=quad
	var head = mesh_node(reference_note_meshes[mesh_key],parent,mat)
	head.position = Vector3(position_value.x,.38*size,position_value.z)
	head.rotation = camera.rotation
	return head

func make_tail_cap(parent: Node3D, lane: float, offset: float, palette: int, recording = false) -> MeshInstance3D:
	var cap=make_cap(parent,lane,offset,palette,recording,TAIL_CAP_SIZE)
	# Keep its filled center above the ribbon instead of sinking with the smaller sprite.
	if game.round_notes(): cap.position.y=.38*game.note_size
	cap.name="SustainEndCap"
	return cap

func make_flick(parent: Node3D, note: Dictionary, palette: int) -> void:
	make_cap(parent,float(note.lane),0,palette)
	# One bold chevron keeps the direction clear without overlapping arrows.
	var axis = camera.basis*[Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(int(note.direction),0,3)]
	for i in 1:
		var base = Vector3(note_x(note.lane),2.0*FIT*game.note_size,0)
		var arrow_mesh = QuadMesh.new(); arrow_mesh.size=Vector2(3.22,1.6)*FIT*game.note_size
		var arrow_material = shared("arrow|%d|%s" % [palette, element_color("arrows",colors[palette])], func():
			var m = ShaderMaterial.new(); m.shader=preload("res://scripts/flick_arrow.gdshader")
			m.set_shader_parameter("tint",element_color("arrows",colors[palette])); return m)
		var arrow = mesh_node(arrow_mesh,parent,arrow_material)
		arrow.position=base; arrow.rotation=camera.rotation
		arrow.rotate_object_local(Vector3.FORWARD,float(note.direction)*PI*.5)
		arrow.set_meta("flick_base",base)
		arrow.set_meta("flick_axis",axis)

# Trails run through the middle of their notes: just above the track for flat rectangle
# notes, and at half height through the thicker circle pucks.
func trail_height() -> float:
	return (.38 if game.round_notes() else .09)*game.note_size

func trail_centers(note: Dictionary, count: int, recording = false) -> Array:
	var duration = float(note.duration)
	var result: Array = []
	for i in count+1:
		var t = duration*i/count
		var point = Vector3(note_x(SynkChart.lane_at(note,note.time+t)),trail_height(),-t*travel_speed())
		if recording: point.z = -point.z
		result.append(point)
	return result

# Unit vectors across the trail at each center point. They are perpendicular to the averaged
# direction of travel, so a slide that cuts sideways keeps the same visible width as a straight
# hold instead of pinching thin, and neighbouring segments join without kinks.
func trail_sides(centers: Array) -> Array:
	var result: Array = []
	for i in centers.size():
		var before: Vector3 = centers[maxi(i-1,0)]; var after: Vector3 = centers[mini(i+1,centers.size()-1)]
		var direction = Vector3(after.x-before.x,0,after.z-before.z)
		if direction.length() < .0001: direction = Vector3(0,0,-1)
		direction = direction.normalized()
		var side = Vector3(-direction.z,0,direction.x)
		if side.x < 0: side = -side
		result.append(side)
	return result

func make_ribbon(parent: Node3D, note: Dictionary, palette: int, recording = false) -> void:
	var duration = float(note.duration)
	var half_width = TRAIL_HALF*.65*game.hold_trail_width
	var count = clampi(ceili(duration*32),16,256)
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge = SurfaceTool.new(); edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers = trail_centers(note,count,recording)
	var sides = trail_sides(centers)
	for i in count:
		var a: Vector3 = centers[i]; var b: Vector3 = centers[i+1]
		var sa: Vector3 = sides[i]; var sb: Vector3 = sides[i+1]
		for index in [0,1,2,0,2,3]:
			st.set_uv([Vector2(0,float(i)/count),Vector2(0,float(i+1)/count),Vector2(1,float(i+1)/count),Vector2(1,float(i)/count)][index])
			st.add_vertex([a-sa*half_width,b-sb*half_width,b+sb*half_width,a+sa*half_width][index])
		for side in [-1,1]:
			var lift = Vector3(0,.01,0)
			for index in [0,1,2,0,2,3]:
				edge.add_vertex([a+sa*(side*half_width-.012),b+sb*(side*half_width-.012),b+sb*(side*half_width+.012),a+sa*(side*half_width+.012)][index]+lift)
	var solid=game.trail_style=="solid"
	var trail_material: ShaderMaterial
	if solid:
		trail_material=shared("solid_trail|%s" % trail_color(palette), func():
			var m=ShaderMaterial.new(); m.shader=preload("res://scripts/solid_trail.gdshader")
			m.set_shader_parameter("tint",trail_color(palette)); return m)
	else:
		var still = note.kind=="hold"
		trail_material=shared("art_trail|%d|%s|%s" % [palette, trail_color(palette), still], func():
			var m=build_asset_material("Hold_Note_Pink",palette,TRAIL_REGION,.85)
			m.set_shader_parameter("tint",trail_color(palette))
			if still:
				m.set_shader_parameter("motion",0.0); m.set_shader_parameter("glow_pulse",0.0)
			return m)
	st.set_material(trail_material); mesh_node(st.commit(),parent)
	if solid:
		make_solid_trail_joints(parent,note,palette,recording,half_width)
	else:
		var edge_material = shared("ribbon_edge|%s" % trail_color(palette), func():
			var m = ShaderMaterial.new(); m.shader = preload("res://scripts/ribbon_edge.gdshader")
			m.set_shader_parameter("color",trail_color(palette).lightened(.4)); return m)
		edge.set_material(edge_material); mesh_node(edge.commit(),parent)
	# Checkpoint dots: glowing beads where the finger must be when they reach the bar.
	if note.has("checkpoints") and not solid:
		var dot_material = shared("bead", func():
			var m = ShaderMaterial.new(); m.shader = preload("res://scripts/ribbon_edge.gdshader")
			m.set_shader_parameter("color",Color("fff4ff")); return m)
		var halo_material = shared("halo|%s" % trail_color(palette), func():
			var m = ShaderMaterial.new(); m.shader = preload("res://scripts/ribbon_edge.gdshader")
			m.set_shader_parameter("color",trail_color(palette).lightened(.55)); return m)
		for offset in note.checkpoints:
			var at = float(offset)
			var dot_position = Vector3(note_x(SynkChart.lane_at(note,note.time+at)),trail_height()+.07,-at*travel_speed()*(-1 if recording else 1))
			var halo_mesh = CylinderMesh.new(); halo_mesh.top_radius=.62*FIT; halo_mesh.bottom_radius=.62*FIT; halo_mesh.height=.02; halo_mesh.radial_segments=24
			var halo = mesh_node(halo_mesh,parent,halo_material); halo.position = dot_position
			var bead_mesh = SphereMesh.new(); bead_mesh.radius=.34*FIT; bead_mesh.height=.24*FIT; bead_mesh.radial_segments=16; bead_mesh.rings=6
			var bead = mesh_node(bead_mesh,parent,dot_material); bead.position = dot_position+Vector3(0,.06,0)
	var end_cap=make_tail_cap(parent,SynkChart.lane_at(note,note.time+duration),duration,palette,recording)
	if solid:
		end_cap.set_meta("solid_trail_joint",true); end_cap.set_meta("checkpoint_offset",duration)

func solid_trail_offsets(note: Dictionary) -> Array:
	# Recorded slide path samples describe its shape, not extra playable points.
	var duration=float(note.duration)
	var offsets: Array=[duration] if duration>0 else []
	for value in note.get("checkpoints",[]):
		var offset=float(value)
		if not is_finite(offset) or offset<=0 or offset>=duration: continue
		if not offsets.any(func(existing): return is_equal_approx(float(existing),offset)): offsets.append(offset)
	offsets.sort()
	return offsets

func make_solid_trail_joints(parent: Node3D,note: Dictionary,palette: int,recording: bool,half_width: float) -> void:
	var offsets=solid_trail_offsets(note)
	var material=shared("joint|%s" % trail_color(palette), func():
		var m=ShaderMaterial.new(); m.shader=preload("res://scripts/solid_trail.gdshader")
		m.set_shader_parameter("tint",trail_color(palette)); m.set_shader_parameter("joint",true); return m)
	var disc=PlaneMesh.new(); disc.size=Vector2.ONE*half_width*3.0
	for offset in offsets:
		# The endpoint is the smaller note cap, rather than a second disc beneath it.
		if is_equal_approx(float(offset),float(note.duration)): continue
		var joint=mesh_node(disc,parent,material)
		joint.set_meta("solid_trail_joint",true); joint.set_meta("checkpoint_offset",offset)
		joint.position=Vector3(note_x(SynkChart.lane_at(note,float(note.time)+offset)),trail_height()+.015,offset*travel_speed()*(1 if recording else -1))

func make_alignment_lines(parent: Node3D, note: Dictionary, palette: int) -> Array:
	# Recording-only rows across the highway at each note's head (and tail) for lining notes up.
	var result: Array = []
	var line_material = material(colors[palette].lightened(.35),.55)
	var offsets = [0.0]
	if note.kind in ["hold","slide"]: offsets.append(float(note.duration))
	for offset in offsets:
		var line_mesh = PlaneMesh.new(); line_mesh.size = Vector2(PAD_HALF_WIDTH*2.0,.07)
		var row = mesh_node(line_mesh,parent,line_material)
		row.position = Vector3(0,.06,offset*travel_speed())
		result.append(row)
	return result

# held: the note is a hold or slide being held, so its trail is eaten up at the judgment bar.
# --- Chart prebuild -------------------------------------------------------------------
# During the loading screen every note of the chart is built once (head, trail mesh, ring,
# materials) and kept hidden. Play then only shows, moves and hides notes, so nothing is
# created mid-song and high note speeds cannot cause spawn spikes. Work is done in small
# time-boxed batches per frame, so the loading animation never stalls.
const PREBUILD_BUDGET_MS = 6.0
var prebuilding = false
var prebuild_queue: Array = []
var prebuild_total = 0
var prebuild_index = 0

func build_note_node(key: String, note: Dictionary, recording = false) -> void:
	# Materials this note creates are animated with the note (only while it's visible),
	# not by the global per-frame list, so hundreds of hidden prebuilt notes cost nothing.
	var first_material = animated_materials.size()
	var node = Node3D.new(); add_child(node)
	var palette = palette_for_kind(str(note.kind))
	if note.kind=="flick": make_flick(node,note,palette)
	else: make_cap(node,float(note.lane),0,palette,recording)
	if note.kind in ["hold","slide"]: make_ribbon(node,note,palette,recording)
	var lines: Array = []
	if recording: lines = make_alignment_lines(node,note,palette)
	var signature = (hash(note) if recording or game.mode=="record" else 0)^hash([game.note_speed,game.note_shape,game.note_size,game.hold_trail_width,game.trail_style])
	var own_materials: Array = []
	for ref in animated_materials.slice(first_material):
		var m = ref.get_ref()
		if m and not m.has_meta("shared"): own_materials.append(ref)
	var keep_shared = animated_materials.slice(first_material).filter(func(ref): return ref.get_ref() != null and ref.get_ref().has_meta("shared"))
	animated_materials.resize(first_material); animated_materials.append_array(keep_shared)
	notes[key] = {"node":node,"signature":signature,"lines":lines,"held":false,"prebuilt":false,"materials":own_materials}

func begin_prebuild() -> void:
	clear_notes()
	build_chords()
	prebuild_queue = range(game.live.size())
	prebuild_total = prebuild_queue.size(); prebuild_index = 0
	prebuilding = prebuild_total > 0

func step_prebuild() -> void:
	if not prebuilding: return
	var start = Time.get_ticks_usec()
	while prebuild_index < prebuild_total and (Time.get_ticks_usec() - start) < PREBUILD_BUDGET_MS * 1000.0:
		var i: int = prebuild_queue[prebuild_index]; prebuild_index += 1
		if i >= game.live.size(): continue
		var key: String = game.live[i].key
		if notes.has(key): continue
		build_note_node(key, game.live[i].note)
		notes[key].node.visible = false; notes[key].prebuilt = true
	if prebuild_index >= prebuild_total: prebuilding = false; prebuild_queue.clear()

func prebuild_progress() -> float:
	if prebuild_total <= 0: return 1.0
	return float(prebuild_index) / float(prebuild_total)

# The note-look part of each note's signature, computed once per frame.
var look_signature = 0
var look_signature_frame = -1
func sync_note(key: String, note: Dictionary, visible_keys: Dictionary, recording = false, freeze_time: float = -1.0, held = false) -> void:
	var tail = float(note.time)+float(note.duration)
	var visible_time=freeze_time if freeze_time>=0 else render_time()
	if freeze_time<0:
		if recording:
			if note.time>visible_time or visible_time-tail>game.note_travel_seconds(): return
		elif note.time-visible_time > game.note_travel_seconds() or (visible_time-tail)*travel_speed()>5: return
	visible_keys[key] = true
	if look_signature_frame != Engine.get_process_frames():
		look_signature_frame = Engine.get_process_frames()
		look_signature = hash([game.note_speed,game.note_shape,game.note_size,game.hold_trail_width,game.trail_style])
	var signature = (hash(note) if recording or game.mode=="record" else 0)^look_signature
	if notes.has(key) and notes[key].signature != signature:
		notes[key].node.queue_free(); notes.erase(key)
	if not notes.has(key): build_note_node(key, note, recording)
	notes[key].node.visible = true
	if notes[key].held != held:
		notes[key].held = held
		set_trail_clip(notes[key].node, 0.02 if held else 1000.0)
	for alignment_line in notes[key].lines: alignment_line.visible = game.note_lines
	if note.kind=="flick":
		# The arrow glides forward and returns smoothly; pausing freezes animation_time.
		var nudge = sin(animation_time*TAU*1.8)*.35
		for arrow in notes[key].node.get_children():
			if arrow.has_meta("flick_base"):
				arrow.position=arrow.get_meta("flick_base")+arrow.get_meta("flick_axis")*nudge
	notes[key].node.position.z = (visible_time-float(note.time))*travel_speed()
	if recording: notes[key].node.position.z *= -1
	elif not held and modifier_hides(notes[key].node.position.z): notes[key].node.visible = false

func update_finger_beams() -> void:
	# Each finger on the stage lights a column up the highway that slides with it.
	var touches: Array = game.pointers.values() if game.mode=="play" else []
	for i in finger_beams.size():
		var beam: MeshInstance3D = finger_beams[i]
		beam.visible = i < touches.size()
		# Beams snap to whole lanes rather than following the finger smoothly.
		# Keep the full note-width glow centered on its lane, including outer notes.
		if beam.visible: beam.position.x = clampf(lane_x(roundi(SynkCapture.lane(touches[i].position.x))),-BEAM_MAX_X,BEAM_MAX_X)

func set_trail_clip(node: Node3D, clip_z: float) -> void:
	for mesh in node.get_children():
		if not mesh is GeometryInstance3D: continue
		var current: Material = mesh.material_override
		if current == null and mesh is MeshInstance3D and mesh.mesh: current = mesh.mesh.surface_get_material(0)
		if not current is ShaderMaterial: continue
		# Unclipped is the shared default, so only a held note needs its own copy.
		if current.has_meta("shared") and clip_z >= 999.0: continue
		var mat: Material = own_material(mesh)
		if mat is ShaderMaterial: mat.set_shader_parameter("clip_z",clip_z)

# fade=false keeps the note fully visible (missed holds stay gray and scroll past).
func fade_missed_slide(key: String, age: float, fade_out: bool = true) -> void:
	var gray=clampf(age/.16,0,1)
	var fade=1.0-smoothstep(.40,.9,age) if fade_out else 1.0
	for mesh in notes[key].node.get_children():
		if not mesh is GeometryInstance3D: continue
		var mat: Material=own_material(mesh)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("desaturate",gray)
			mat.set_shader_parameter("ghost_fade",fade)
			mat.set_shader_parameter("motion",0.0)
			mat.set_shader_parameter("glow_pulse",0.0)
		elif mat is StandardMaterial3D:
			mat.emission_enabled=false
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color=Color(.42,.44,.5,fade)

func highway_angle() -> float:
	return clampf(float(game.highway_angle) if game else -CAMERA_PITCH,MIN_ANGLE,MAX_ANGLE)

func camera_rest_position() -> Vector3:
	var to_bar = deg_to_rad(highway_angle()+BAR_BELOW_CENTER)
	return Vector3(0,BAR_DISTANCE*sin(to_bar),BAR_DISTANCE*cos(to_bar))

func shake_on_miss() -> void:
	# Repeated misses refresh the short shake without increasing its strength.
	miss_shake_remaining = .22

func animate_miss_shake(delta: float) -> void:
	if game.mode=="paused": return
	if game.mode!="play" or (game.stage_intro and game.stage_intro.running()): miss_shake_remaining=0
	miss_shake_remaining=maxf(0,miss_shake_remaining-delta)
	var strength=miss_shake_remaining/.22
	var phase=(.22-miss_shake_remaining)*90.0
	# The loading card fades away over a stationary highway. No entrance zoom.
	apply_camera(Vector3(sin(phase)*.065,sin(phase*1.3)*.025,0)*strength)

# A missed sustain remains visible until its tail exits, even after judgment retires it.
func first_visible_play_index() -> int:
	while play_render_cursor<game.live.size():
		var entry: Dictionary=game.live[play_render_cursor]
		if not entry.done: break
		if entry.note.kind in ["hold","slide"] and entry.has("missed_at"):
			if (render_time()-float(entry.note.time)-float(entry.note.duration))*travel_speed()<=5: break
		play_render_cursor+=1
	return play_render_cursor

var shown_keys: Dictionary = {}
func _process(delta: float) -> void:
	if game==null: return
	if game.gameplay_loading and game.gameplay_loading.preparing:
		if game.mode=="play" and game.gameplay_loading.allow_note_build: step_prebuild()
		return
	step_prebuild()
	if rail_atmosphere: rail_atmosphere.update(delta)
	var in_play = game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play")
	recorder_guides.visible = game.mode=="record" or (game.mode=="paused" and game.paused_mode=="record") or (in_play and bool(extras_setting("lane_hints", false)))
	update_play_aids(delta)
	update_multiplier_wave(delta)
	animate_miss_shake(delta)
	update_cover_backdrop()
	animate_effects(delta)
	var visible_keys = {}
	for beam in active_beams: beam.visible = false
	update_finger_beams()
	if game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play"):
		var candidates: Variant
		if play_visibility and is_equal_approx(play_visibility.travel,game.note_travel_seconds()): candidates=play_visibility.indices(render_time())
		else: candidates=range(first_visible_play_index(),game.live.size())
		for i in candidates:
			if game.live[i].note.time>render_time()+game.note_travel_seconds(): break
			if not game.live[i].done:
				var held = game.live[i].started and game.live[i].note.kind in ["hold","slide"]
				sync_note(game.live[i].key,game.live[i].note,visible_keys,false,-1.0,held)
				if game.live[i].started and game.live[i].note.kind=="slide":
					var lane = game.play_lane_at(game.live[i],render_time())
					var beam = active_beams[clampi(roundi(lane),0,SynkChart.MAX_LANE)]
					beam.position=touch_hit_position(lane,int(game.live[i].pointer))+Vector3(0,.045,0); beam.visible = true
					var pulse = .5+.5*sin(animation_time*TAU*3.0)
					beam.get_child(0).scale = Vector3(1+pulse*.12,.9+pulse*.25,1)
					beam.get_child(0).material_override.set_shader_parameter("opacity",.45+pulse*.3)
			elif game.live[i].note.kind in ["hold","slide"] and game.live[i].has("missed_at"):
				# A missed hold or slide turns gray and keeps travelling down the highway until it leaves.
				var key: String=game.live[i].key
				sync_note(key,game.live[i].note,visible_keys)
				if notes.has(key) and visible_keys.has(key):
					fade_missed_slide(key,maxf(0,game.song_time-float(game.live[i].missed_at)),false)
	if game.mode=="record" or (game.mode=="paused" and game.paused_mode=="record"):
		if game.overdub:
			for i in game.document.notes.size():
				if game.arranging: sync_note("record"+str(i),game.document.notes[i],visible_keys,true)
				elif game.ghost_recording:
					var key="ghost"+str(i)
					sync_note(key,game.document.notes[i],visible_keys)
					if notes.has(key) and visible_keys.has(key): style_record_ghost(notes[key].node)
		for i in game.capture.notes.size(): sync_note("captured"+str(i),game.capture.notes[i],visible_keys,true)
		for id in game.capture.gestures:
			sync_note("gesture"+str(id),recording_preview(game.capture.gestures[id]),visible_keys,true)
	# Only notes shown last frame can need hiding now, so this stays cheap on long charts.
	for key in shown_keys:
		if visible_keys.has(key) or not notes.has(key): continue
		# Prebuilt chart notes are kept and hidden; anything built on the fly is freed.
		if notes[key].get("prebuilt", false): notes[key].node.visible = false
		else: notes[key].node.queue_free(); notes.erase(key)
	shown_keys = visible_keys

# A stationary touch emits no drag events. Advance its visual tail using the song
# clock, without changing captured notes, gesture classification or saved timing.
# Only build the visible portion so a minute-long hold stays cheap to render.
func recording_preview(gesture: Dictionary) -> Dictionary:
	var preview: Dictionary=gesture.note.duplicate(true)
	var now=maxf(float(preview.time)+float(preview.duration),render_time())
	preview.duration=now-float(preview.time)
	if preview.kind=="slide":
		preview.path.append({"offset":preview.duration,"lane":clampf(SynkCapture.lane(gesture.position.x)+float(gesture.get("lane_shift",0)),0,SynkChart.MAX_LANE)})
	var start=maxf(float(preview.time),now-game.note_travel_seconds())
	if start>float(preview.time):
		var start_lane=SynkChart.lane_at(preview,start)
		var shift=start-float(preview.time)
		var path: Array=[{"offset":0.0,"lane":start_lane}]
		for point in preview.path:
			if float(point.offset)>shift: path.append({"offset":float(point.offset)-shift,"lane":point.lane})
		preview.path=path if preview.kind=="slide" else []
		preview.time=start; preview.duration=now-start; preview.lane=start_lane
	return preview

func style_record_ghost(node: Node3D) -> void:
	for mesh in node.get_children():
		if not mesh is MeshInstance3D: continue
		var mat: Material=own_material(mesh)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("ghost_fade",.32)
			mat.set_shader_parameter("glow_pulse",0.0)
		elif mat is StandardMaterial3D:
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a=.32; mat.emission_enabled=false
