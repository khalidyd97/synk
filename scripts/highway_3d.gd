extends Node3D

# All note positions are in world units. Camera perspective supplies the depth.
const CENTER_LANE = (SynkChart.LANES-1)*.5
# Notes, trails and finger beams are 1.3x the size they were tuned at (1.5-unit lanes).
const NOTE_SCALE = 1.3
const NOTE_WIDTH = 3.1*NOTE_SCALE
const TRAIL_HALF = .8*NOTE_SCALE
const TAIL_CAP_SIZE = .5
# How far below the hit flash art its mirrored glow extends, as a fraction of the art height.
const HIT_MIRROR = .35
# Diameter of the hollow release ring that marks where a hold or slide ends.
const RELEASE_RING_SIZE = 3.2
# The glowing band of Hold_Note_Pink.png spans u .225 to .68; using exactly that slice keeps
# the trail centered on its notes with its bright edges on the trail's outline.
const TRAIL_REGION = Vector4(.225,.27,.455,.43)
# The tap note art fades in on its left but is cut off at its right edge; trimming the left
# glow centers the note body on its lane.
const CAP_REGION = Vector4(.12,0,.88,1)
# The highway surface is 19.5 wide. Lanes are spaced so even the outermost notes stay
# inside the rails, with a small margin.
const HIGHWAY_HALF_WIDTH = 9.75
const EDGE_MARGIN = .2
const LANE_WIDTH = (HIGHWAY_HALF_WIDTH-EDGE_MARGIN-NOTE_WIDTH*.5)/CENTER_LANE
const BEAM_MAX_X = HIGHWAY_HALF_WIDTH-NOTE_WIDTH*.5
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
var spark_mesh: SphereMesh
var miss_shake_remaining = 0.0
var cover_backdrop: MeshInstance3D
var ambient_motes: CPUParticles3D
var ambient_streaks: Array = []
var sustain_streaks: Array = []
var ambient_side_motes: Array = []
var ambient_mote_material: StandardMaterial3D
var cover_material: ShaderMaterial
var ambient_palette: Gradient
var rail_edge_materials: Array = []
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
# Lens zoom for the stage entrance; the stage keeps its position and proportions.
const GAMEPLAY_FOV = 45.0
const INTRO_FOV = 65.0

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
func travel_speed() -> float: return TRACK_LENGTH / game.note_travel_seconds()
func render_time() -> float:
	return game.visual_song_time if game.audio.playing and game.mode in ["play","record"] and game.countdown<=0 and game.resume_countdown<=0 else game.song_time
func note_position(lane: float, chart_time: float) -> Vector3:
	return Vector3(lane_x(lane), .13, (render_time()-chart_time)*travel_speed())

func _ready() -> void:
	camera = Camera3D.new(); add_child(camera); camera.current = true
	camera.position = camera_rest_position(); camera.rotation_degrees.x = -highway_angle()
	camera.fov = GAMEPLAY_FOV; camera.near = .1; camera.far = 180
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
	build_cover_backdrop()
	build_ambient_particles()

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
		# Extra streams emit only while a hold or slide is being played.
		var extra = streaks.duplicate() as CPUParticles3D
		extra.amount=44; extra.preprocess=0.0; extra.emitting=false
		extra.initial_velocity_min=42; extra.initial_velocity_max=64
		add_child(extra); sustain_streaks.append(extra)

func update_ambient_particles(beat: float) -> void:
	# Freeze with the game when paused, follow the note speed, and brighten motes on the beat.
	var running = game.mode in ["play","record"]
	ambient_motes.speed_scale = 1.0 if running else 0.0
	for motes in ambient_side_motes: motes.speed_scale = ambient_motes.speed_scale
	for streaks in ambient_streaks: streaks.speed_scale = (game.note_speed if running else 0.0)
	var sustaining=false
	if game.mode=="play":
		for entry in game.live:
			if entry.started and not entry.done and entry.note.kind in ["hold","slide"]:
				if game.auto_play or game.pointers.has(entry.pointer):
					sustaining=true; break
	for streaks in sustain_streaks:
		streaks.speed_scale=game.note_speed if running else 0.0
		if game.mode!="paused": streaks.emitting=sustaining
	ambient_mote_material.albedo_color = Color(1,1,1).lerp(Color(1.8,1.8,1.8),beat)
	var particles=game.features.effect("Particles")
	ambient_motes.visible=particles>0; ambient_motes.color=Color(1,1,1,particles)
	for motes in ambient_side_motes:
		motes.visible=particles>0; motes.color=Color(1,1,1,particles)
	var lasers=game.features.effect("Lasers")
	for streaks in ambient_streaks+sustain_streaks:
		streaks.visible=lasers>0; streaks.color=Color(1,1,1,lasers)
	cover_material.set_shader_parameter("brightness",game.features.effect("Background brightness"))

func set_cover(texture: Texture2D, tint: Color) -> void:
	cover_material.set_shader_parameter("cover",texture)
	cover_material.set_shader_parameter("tint",tint)
	cover_material.set_shader_parameter("strength",1.0)
	cover_backdrop.visible = texture != null

# Recolors notes, rails, the judgment bar, track, sky and particles to the cover's colors.
func apply_palette(palette: Dictionary) -> void:
	colors = palette.notes.duplicate()
	cover_palette_active = palette.from_cover
	stage_color = palette.stage
	materials.clear(); note_meshes.clear()
	for color in colors:
		materials.append(material(color))
		note_meshes.append(make_note_mesh(color))
	# Tap on the left rail, sustained on the right, as with the house palette.
	for i in rail_edge_materials.size():
		rail_edge_materials[i].set_shader_parameter("tint",colors[1] if i==1 else colors[0])
	judgment_material.set_shader_parameter("base_color",colors[1].lerp(Color.WHITE,.15) if cover_palette_active else Color(.60,.36,1.0))
	judgment_material.set_shader_parameter("sweep_color",colors[0].lerp(Color.WHITE,.45) if cover_palette_active else Color(.68,.91,1.0))
	track_materials[0].set_shader_parameter("color",stage_color.darkened(.45) if cover_palette_active else Color("080b25"))
	track_materials[1].set_shader_parameter("color",stage_color if cover_palette_active else Color("0b1030"))
	ambient_palette.offsets = PackedFloat32Array([0.0,.5,1.0])
	ambient_palette.colors = PackedColorArray([colors[1],colors[1].lerp(colors[2],.5) if cover_palette_active else Color("ff7ad9"),colors[0]])
	finger_beam_material.set_shader_parameter("tint",colors[0])
	for beam in active_beams:
		var mat: ShaderMaterial = beam.get_child(0).material_override
		mat.set_shader_parameter("tint",colors[1]); mat.set_shader_parameter("recolor",true)
	# Notes already on screen were built with the old colors.
	clear_notes()

func update_cover_backdrop() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.y <= 0: return
	var aspect = viewport_size.x/viewport_size.y
	var height = 2.0*COVER_DISTANCE*tan(deg_to_rad(camera.fov*.5))*1.04
	(cover_backdrop.mesh as QuadMesh).size = Vector2(height*aspect,height)
	cover_material.set_shader_parameter("screen_aspect",aspect)
	# A soft brightness kick on every beat while the song plays.
	var beat = 0.0
	if game.mode=="play" and game.audio.playing:
		var beats = maxf(0.0,game.song_time)*float(game.chart_bpm())/60.0
		beat = exp(-(beats-floorf(beats))*5.0)
	cover_material.set_shader_parameter("beat",beat)
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
	var base_material = track_material(Color("080b25"),.36); base_material.render_priority = -10
	track_materials.append(base_material)
	box(self,Vector3(0,-.15,-28),Vector3(19.65,.25,64),base_material)
	var surface = PlaneMesh.new(); surface.size = Vector2(19.50,60)
	var surface_material = track_material(Color("0b1030"),.42); surface_material.render_priority = -9
	track_materials.append(surface_material)
	var rail = mesh_node(surface,self,surface_material); rail.position = Vector3(0,.008,-30)
	# Recording-only guides make lane targets readable without adding lines to gameplay.
	recorder_guides = Node3D.new(); recorder_guides.name = "RecorderGuides"; add_child(recorder_guides)
	var guide_material = material(Color("777bd5"),.38)
	for boundary in range(1,SynkChart.LANES):
		var guide_mesh = PlaneMesh.new(); guide_mesh.size = Vector2(.035,60)
		var guide = mesh_node(guide_mesh,recorder_guides,guide_material)
		guide.position = Vector3(lane_x(boundary-.5),.048,-30)
	var marker_material = material(Color("8be8ff"),.72)
	for lane in SynkChart.LANES:
		var marker_mesh = PlaneMesh.new(); marker_mesh.size = Vector2(.22,.62)
		var marker = mesh_node(marker_mesh,recorder_guides,marker_material)
		marker.position = Vector3(lane_x(lane),.052,-.03)
	recorder_guides.visible = false
	for side in [-1,1]:
		var edge_mesh = PlaneMesh.new(); edge_mesh.size = Vector2(.28,64)
		var edge_material = ShaderMaterial.new(); edge_material.shader = preload("res://scripts/rail_edge.gdshader")
		edge_material.set_shader_parameter("tint",colors[1] if side==1 else colors[0])
		animated_materials.append(weakref(edge_material))
		rail_edge_materials.append(edge_material)
		var edge = mesh_node(edge_mesh,self,edge_material)
		edge.position = Vector3(side*9.72,.035,-28)
	# A bit deeper than the visible note face so the hit line reads clearly.
	var judgment_mesh = QuadMesh.new(); judgment_mesh.size = Vector2(19.50,JUDGMENT_DEPTH)
	judgment_material = ShaderMaterial.new(); judgment_material.shader = preload("res://scripts/judgment_bar.gdshader")
	animated_materials.append(weakref(judgment_material))
	var judgment_bar = mesh_node(judgment_mesh,self,judgment_material)
	judgment_bar.position = Vector3(0,.035,0); judgment_bar.rotation_degrees.x = -90
	for edge in [-1,1]:
		var edge_mesh = QuadMesh.new(); edge_mesh.size = Vector2(19.50,.025)
		var border = mesh_node(edge_mesh,judgment_bar,material(Color("ead6ff")))
		border.position = Vector3(0,edge*JUDGMENT_DEPTH*.5,.005)

func build_effects() -> void:
	spark_mesh = SphereMesh.new(); spark_mesh.radius = .065; spark_mesh.height = .13
	finger_beam_material = ShaderMaterial.new(); finger_beam_material.shader = preload("res://scripts/finger_beam.gdshader")
	# Drawn over the judgment bar so the lit lane reads all the way down to the bar's near edge.
	finger_beam_material.render_priority = 2
	var beam_mesh = PlaneMesh.new(); beam_mesh.size = Vector2(NOTE_WIDTH,58+JUDGMENT_DEPTH*.5)
	for i in 10:
		var finger_beam = mesh_node(beam_mesh,self,finger_beam_material)
		finger_beam.position = Vector3(0,.045,(-58+JUDGMENT_DEPTH*.5)*.5); finger_beam.visible = false
		finger_beams.append(finger_beam)
	for lane in SynkChart.LANES:
		var beam = Node3D.new(); add_child(beam); beam.position = Vector3(lane_x(lane),.08,0)
		artwork(beam,"Hit_Effect_Pink",1,Vector3(0,1.35,0),Vector2(4.4,3.3),Vector4(0,0,1,1),.75)
		beam.visible = false; active_beams.append(beam)

func asset_material(name: String, palette: int, region = Vector4(0,0,1,1), opacity = 1.0) -> ShaderMaterial:
	var mat = ShaderMaterial.new(); mat.shader = load("res://scripts/neon_asset.gdshader")
	mat.set_shader_parameter("artwork",load("res://assets/neon/"+name+".png"))
	mat.set_shader_parameter("region",region); mat.set_shader_parameter("opacity",opacity)
	# Blue tap artwork keeps its gradient; sustained and flick art takes its type color.
	mat.set_shader_parameter("recolor",palette!=0 or cover_palette_active); mat.set_shader_parameter("tint",colors[palette])
	mat.set_shader_parameter("motion",.7 if name.begins_with("Hold_") else (.35 if name.begins_with("Flick_") else .12))
	if name.begins_with("Tap_") or name.begins_with("Hold_") or name.begins_with("Flick_") or name.begins_with("Slide_"):
		mat.set_shader_parameter("glow_pulse",.18)
	animated_materials.append(weakref(mat))
	return mat

func spawn_hit(lane: float, kind: String, direction: int = 0, sustain_entry: Dictionary = {}) -> void:
	if bursts.size() >= 32:
		bursts.pop_front().node.queue_free()
	var palette = palette_for_kind("tap" if kind in ["slide","flick"] else kind)
	var node = Node3D.new(); add_child(node); node.position = Vector3(lane_x(lane),.1,0)
	# Share the regular hit flash across taps, slides and flicks.
	var flash = artwork(node,"Hit_Effect_Blue" if palette==0 else "Hit_Effect_Pink",palette,Vector3(0,2.25-4.0*HIT_MIRROR*.5,0),Vector2(5.8,4.0*(1.0+HIT_MIRROR)))
	flash.material_override.set_shader_parameter("mirror_extra",HIT_MIRROR)
	var fill_mesh = QuadMesh.new(); fill_mesh.size = Vector2(5.9,4.2)
	var fill_material = ShaderMaterial.new(); fill_material.shader = preload("res://scripts/hit_fill.gdshader")
	fill_material.set_shader_parameter("tint",colors[palette])
	var fill = mesh_node(fill_mesh,node,fill_material)
	fill.position = Vector3(0,2.25,0); fill.rotation = camera.rotation
	var flick_axis = camera.basis * [Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(direction,0,3)]
	var ring_mesh = TorusMesh.new(); ring_mesh.inner_radius=.9; ring_mesh.outer_radius=.97; ring_mesh.rings=32; ring_mesh.ring_segments=6
	var ring = mesh_node(ring_mesh,node,material(colors[palette],.8))
	var particles: Array = []
	var particle_count = 24 if kind=="flick" else 12
	var particle_material = material(colors[palette].lightened(.65)) if kind=="flick" else materials[palette]
	var streak_mesh = BoxMesh.new(); streak_mesh.size=Vector3(.035,.035,.42)
	for i in particle_count:
		var particle=mesh_node(streak_mesh if kind=="flick" else spark_mesh,node,particle_material)
		var angle=i*TAU/float(particle_count)
		var velocity=Vector3(cos(angle)*3.5,3.0+float(i%4)*.9,sin(angle)*1.4-.8)
		if kind=="flick":
			var sideways = camera.basis * [Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT,Vector3.UP][clampi(direction,0,3)]
			velocity = flick_axis*(5.0+float(i%7)*1.4)+sideways*sin(angle)*4.8
			# Align each fine streak with its own flight path in the camera plane.
			particle.quaternion=Quaternion(Vector3.BACK,velocity.normalized())
		particles.append({"node":particle,"velocity":velocity})
	bursts.append({"node":node,"age":0.0,"flash":flash,"fill":fill,"ring":ring,"particles":particles,"kind":kind,"flick_axis":flick_axis,"sustain_entry":sustain_entry})

func clear_hit_effects() -> void:
	for burst in bursts: burst.node.queue_free()
	bursts.clear()

func clear_notes() -> void:
	for entry in notes.values(): entry.node.queue_free()
	notes.clear()

func animate_effects(delta: float) -> void:
	var running = game.mode in ["play","record"]
	if running: animation_time += delta
	for i in range(animated_materials.size()-1,-1,-1):
		var mat = animated_materials[i].get_ref()
		if mat==null: animated_materials.remove_at(i)
		else: mat.set_shader_parameter("animation_time",animation_time)
	for i in range(bursts.size()-1,-1,-1):
		var burst: Dictionary = bursts[i]
		var sustained = not burst.sustain_entry.is_empty() and not burst.sustain_entry.done
		if not sustained and not burst.sustain_entry.is_empty():
			burst.sustain_entry={}
			burst.age=.45
		if running: burst.age += delta
		if (not sustained and burst.age>=.65) or game.mode not in ["play","record","paused"]:
			burst.node.queue_free(); bursts.remove_at(i); continue
		var t = minf(float(burst.age)/.65,1.0)
		# A quick, full flash that holds its body before fading out.
		var fade = pow(1.0-smoothstep(.10,1.0,t),1.5)
		var attack = minf(1.0,burst.age/.018)
		var hold_wave = .5+.5*sin(animation_time*TAU*2.8)
		var hold_blend = smoothstep(0.0,.18,burst.age) if sustained else 0.0
		if sustained and burst.kind=="slide":
			# Keep the normal hit burst on the moving slide head, with repeated flashes.
			burst.node.position.x = lane_x(SynkChart.lane_at(burst.sustain_entry.note,game.song_time))
		burst.flash.material_override.set_shader_parameter("opacity",lerpf(attack*fade,.60+hold_wave*.26,hold_blend))
		burst.fill.material_override.set_shader_parameter("opacity",lerpf(attack*fade,.55+hold_wave*.22,hold_blend))
		if sustained and burst.kind=="slide":
			var slide_flash = .18+.82*pow(hold_wave,2.0)
			burst.flash.material_override.set_shader_parameter("opacity",lerpf(attack*fade,slide_flash,hold_blend))
			burst.fill.material_override.set_shader_parameter("opacity",lerpf(attack*fade,slide_flash,hold_blend))
		var hit_intensity=game.features.effect("Hit flashes")
		for art in [burst.flash,burst.fill]:
			art.material_override.set_shader_parameter("opacity",float(art.material_override.get_shader_parameter("opacity"))*hit_intensity)
		burst.fill.scale = Vector3(1.0+t*.7,1.0+t*.35,1).lerp(Vector3(1.18+hold_wave*.15,1.05+hold_wave*.14,1),hold_blend)
		burst.flash.scale = Vector3(1.0+t*.6,1.0+t*.25,1).lerp(Vector3(1.14+hold_wave*.12,1.0+hold_wave*.12,1),hold_blend)
		burst.ring.scale = Vector3.ONE*lerpf(.8+t*.75,1.12+hold_wave*.22,hold_blend)
		burst.ring.material_override.albedo_color.a = lerpf(fade*.8,.15+hold_wave*.25,hold_blend)*hit_intensity
		for particle_index in burst.particles.size():
			var particle=burst.particles[particle_index]
			particle.node.visible=float(particle_index)/maxi(1,burst.particles.size())<game.features.effect("Particles")
			particle.node.position = particle.velocity*burst.age
			if burst.kind=="flick": particle.node.position += Vector3(0,1.8,0)
			if burst.kind!="flick": particle.node.position += Vector3(0,-2.5*burst.age*burst.age,0)
			particle.node.scale = Vector3.ONE*maxf(.01,1-t)

func artwork(parent: Node3D, name: String, palette: int, position_value: Vector3, dimensions: Vector2, region = Vector4(0,0,1,1), opacity = 1.0) -> MeshInstance3D:
	var quad = QuadMesh.new(); quad.size = dimensions
	var node = mesh_node(quad,parent,asset_material(name,palette,region,opacity))
	node.position = position_value; node.rotation = camera.rotation
	return node

func palette_for_kind(kind: String) -> int:
	if kind=="flick": return 2
	if kind in ["hold","slide"]: return 1
	return 0

# size scales the cap; hold and slide tails use a half-size cap so their end reads clearly.
func make_cap(parent: Node3D, lane: float, offset: float, palette: int, recording = false, size = 1.0) -> void:
	size*=game.note_size
	var position_value = Vector3(lane_x(lane),.2,offset*travel_speed()*(1 if recording else -1))
	if game.note_shape=="circle":
		make_circle_cap(parent,position_value,palette,size); return
	artwork(parent,"Tap_Note_Blue" if palette==0 else "Tap_Note_Pink",palette,position_value,Vector2(NOTE_WIDTH,1.4)*size,CAP_REGION)

func make_circle_cap(parent: Node3D, position_value: Vector3, palette: int, size = 1.0) -> MeshInstance3D:
	# A thick puck lying flat on the highway: a domed top face over a shaded edge wall.
	# Both meshes are direct children of the note so hold clipping and miss graying reach them.
	var RADIUS = 1.16*NOTE_SCALE*size
	var THICKNESS = .65*size
	var mat = ShaderMaterial.new(); mat.shader = preload("res://scripts/circle_note.gdshader")
	mat.set_shader_parameter("tint",colors[palette]); mat.set_shader_parameter("recolor",palette!=0 or cover_palette_active)
	mat.set_shader_parameter("glow_pulse",.09); mat.render_priority = 1
	animated_materials.append(weakref(mat))
	var quad = QuadMesh.new(); quad.size = Vector2(RADIUS/.4,RADIUS/.4)
	var top = mesh_node(quad,parent,mat)
	top.position = Vector3(position_value.x,.06+THICKNESS,position_value.z); top.rotation_degrees.x = -90
	var side_material = ShaderMaterial.new(); side_material.shader = preload("res://scripts/circle_side.gdshader")
	side_material.set_shader_parameter("tint",colors[palette]); side_material.set_shader_parameter("half_height",THICKNESS*.5)
	side_material.set_shader_parameter("recolor",palette!=0 or cover_palette_active)
	side_material.set_shader_parameter("glow_pulse",.07)
	animated_materials.append(weakref(side_material))
	var wall = CylinderMesh.new(); wall.top_radius = RADIUS; wall.bottom_radius = RADIUS*.94; wall.height = THICKNESS
	wall.cap_top = false; wall.cap_bottom = false; wall.radial_segments = 40; wall.rings = 1
	var side = mesh_node(wall,parent,side_material)
	side.position = Vector3(position_value.x,.06+THICKNESS*.5,position_value.z)
	return top

# The end of a hold or slide: a hollow ring on the highway marking where to let go.
func make_release_ring(parent: Node3D, lane: float, offset: float, palette: int, recording = false) -> MeshInstance3D:
	var mat = ShaderMaterial.new(); mat.shader = preload("res://scripts/release_ring.gdshader")
	mat.set_shader_parameter("tint",colors[palette].lightened(.15))
	animated_materials.append(weakref(mat))
	var quad = QuadMesh.new(); quad.size = Vector2(RELEASE_RING_SIZE,RELEASE_RING_SIZE)*game.note_size
	var ring = mesh_node(quad,parent,mat)
	ring.position = Vector3(lane_x(lane),trail_height()+.03,offset*travel_speed()*(1 if recording else -1))
	ring.rotation_degrees.x = -90
	return ring

func make_flick(parent: Node3D, note: Dictionary, palette: int) -> void:
	make_cap(parent,float(note.lane),0,palette)
	# One bold chevron keeps the direction clear without overlapping arrows.
	var axis = camera.basis*[Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(int(note.direction),0,3)]
	for i in 1:
		var base = Vector3(lane_x(note.lane),2.0*game.note_size,0)
		var arrow_mesh = QuadMesh.new(); arrow_mesh.size=Vector2(3.22,1.6)*game.note_size
		var arrow_material = ShaderMaterial.new(); arrow_material.shader=preload("res://scripts/flick_arrow.gdshader")
		arrow_material.set_shader_parameter("tint",colors[palette])
		var arrow = mesh_node(arrow_mesh,parent,arrow_material)
		arrow.position=base; arrow.rotation=camera.rotation
		arrow.rotate_object_local(Vector3.FORWARD,float(note.direction)*PI*.5)
		arrow.set_meta("flick_base",base)
		arrow.set_meta("flick_axis",axis)

# Trails run through the middle of their notes: just above the track for flat rectangle
# notes, and at half height through the thicker circle pucks.
func trail_height() -> float:
	return (.38 if game.note_shape=="circle" else .09)*game.note_size

func trail_centers(note: Dictionary, count: int, recording = false) -> Array:
	var duration = float(note.duration)
	var result: Array = []
	for i in count+1:
		var t = duration*i/count
		var point = Vector3(lane_x(SynkChart.lane_at(note,note.time+t)),trail_height(),-t*travel_speed())
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
	var half_width = TRAIL_HALF*.65*game.hold_trail_width if note.kind=="hold" else TRAIL_HALF
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
	var trail_material = asset_material("Hold_Note_Pink",palette,TRAIL_REGION,.85)
	if note.kind=="hold":
		trail_material.set_shader_parameter("motion",0.0)
		trail_material.set_shader_parameter("glow_pulse",0.0)
	st.set_material(trail_material); mesh_node(st.commit(),parent)
	var edge_material = ShaderMaterial.new(); edge_material.shader = preload("res://scripts/ribbon_edge.gdshader")
	edge_material.set_shader_parameter("color",colors[palette].lightened(.4))
	edge.set_material(edge_material); mesh_node(edge.commit(),parent)
	# Checkpoint dots: glowing beads where the finger must be when they reach the bar.
	if note.has("checkpoints"):
		var dot_material = ShaderMaterial.new(); dot_material.shader = preload("res://scripts/ribbon_edge.gdshader")
		dot_material.set_shader_parameter("color",Color("fff4ff"))
		var halo_material = ShaderMaterial.new(); halo_material.shader = preload("res://scripts/ribbon_edge.gdshader")
		halo_material.set_shader_parameter("color",colors[palette].lightened(.55))
		for offset in note.checkpoints:
			var at = float(offset)
			var dot_position = Vector3(lane_x(SynkChart.lane_at(note,note.time+at)),trail_height()+.07,-at*travel_speed()*(-1 if recording else 1))
			var halo_mesh = CylinderMesh.new(); halo_mesh.top_radius=.62; halo_mesh.bottom_radius=.62; halo_mesh.height=.02; halo_mesh.radial_segments=24
			var halo = mesh_node(halo_mesh,parent,halo_material); halo.position = dot_position
			var bead_mesh = SphereMesh.new(); bead_mesh.radius=.34; bead_mesh.height=.24; bead_mesh.radial_segments=16; bead_mesh.rings=6
			var bead = mesh_node(bead_mesh,parent,dot_material); bead.position = dot_position+Vector3(0,.06,0)
	make_release_ring(parent,SynkChart.lane_at(note,note.time+duration),duration,palette,recording)

func make_alignment_lines(parent: Node3D, note: Dictionary, palette: int) -> Array:
	# Recording-only rows across the highway at each note's head (and tail) for lining notes up.
	var result: Array = []
	var line_material = material(colors[palette].lightened(.35),.55)
	var offsets = [0.0]
	if note.kind in ["hold","slide"]: offsets.append(float(note.duration))
	for offset in offsets:
		var line_mesh = PlaneMesh.new(); line_mesh.size = Vector2(19.50,.07)
		var row = mesh_node(line_mesh,parent,line_material)
		row.position = Vector3(0,.06,offset*travel_speed())
		result.append(row)
	return result

# held: the note is a hold or slide being held, so its trail is eaten up at the judgment bar.
func sync_note(key: String, note: Dictionary, visible_keys: Dictionary, recording = false, freeze_time: float = -1.0, held = false) -> void:
	var tail = float(note.time)+float(note.duration)
	var visible_time=freeze_time if freeze_time>=0 else render_time()
	if freeze_time<0:
		if recording:
			if note.time>visible_time or visible_time-tail>game.note_travel_seconds(): return
		elif note.time-visible_time > game.note_travel_seconds() or (visible_time-tail)*travel_speed()>5: return
	visible_keys[key] = true
	var signature = hash(note)^hash([game.note_speed,game.note_shape,game.note_size,game.hold_trail_width])
	if notes.has(key) and notes[key].signature != signature:
		notes[key].node.queue_free(); notes.erase(key)
	if not notes.has(key):
		var node = Node3D.new(); add_child(node)
		var palette = palette_for_kind(str(note.kind))
		if note.kind=="flick": make_flick(node,note,palette)
		else: make_cap(node,float(note.lane),0,palette,recording)
		if note.kind in ["hold","slide"]: make_ribbon(node,note,palette,recording)
		var lines: Array = []
		if recording: lines = make_alignment_lines(node,note,palette)
		notes[key] = {"node":node,"signature":signature,"lines":lines,"held":false}
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

func update_finger_beams() -> void:
	# Each finger on the stage lights a column up the highway that slides with it.
	var touches: Array = game.pointers.values() if game.mode=="play" else []
	for i in finger_beams.size():
		var beam: MeshInstance3D = finger_beams[i]
		beam.visible = i < touches.size()
		# Beams snap to whole lanes rather than following the finger smoothly.
		# Edge lanes are clamped so the beam never spills past the highway's rails.
		if beam.visible: beam.position.x = clampf(lane_x(roundi(SynkCapture.lane(touches[i].position.x))),-BEAM_MAX_X,BEAM_MAX_X)

func set_trail_clip(node: Node3D, clip_z: float) -> void:
	for mesh in node.get_children():
		var mat: Material = mesh.material_override
		if mat == null and mesh.mesh: mat = mesh.mesh.surface_get_material(0)
		if mat is ShaderMaterial: mat.set_shader_parameter("clip_z",clip_z)

# fade=false keeps the note fully visible (missed holds stay gray and scroll past).
func fade_missed_slide(key: String, age: float, fade_out: bool = true) -> void:
	var gray=clampf(age/.16,0,1)
	var fade=1.0-smoothstep(.40,.9,age) if fade_out else 1.0
	for mesh in notes[key].node.get_children():
		var mat: Material=mesh.material_override
		if mat==null: mat=mesh.mesh.surface_get_material(0)
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
	if game.mode!="play": miss_shake_remaining=0
	miss_shake_remaining=maxf(0,miss_shake_remaining-delta)
	var strength=miss_shake_remaining/.22
	var phase=(.22-miss_shake_remaining)*90.0
	camera.position=camera_rest_position()+Vector3(sin(phase)*.065,sin(phase*1.3)*.025,0)*strength
	# Zoom the lens into the stage without moving or tilting the camera.
	var away=1.0-game.stage_intro.entrance() if game.stage_intro and game.mode in ["play","paused"] else 0.0
	camera.fov=lerpf(GAMEPLAY_FOV,INTRO_FOV,away)
	camera.rotation_degrees.x=-highway_angle()

func _process(delta: float) -> void:
	if game==null: return
	recorder_guides.visible = game.mode=="record" or (game.mode=="paused" and game.paused_mode=="record")
	animate_miss_shake(delta)
	update_cover_backdrop()
	animate_effects(delta)
	var visible_keys = {}
	for beam in active_beams: beam.visible = false
	update_finger_beams()
	if game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play"):
		for i in game.live.size():
			if game.live[i].note.time>render_time()+game.note_travel_seconds(): break
			if not game.live[i].done:
				var held = game.live[i].started and game.live[i].note.kind in ["hold","slide"]
				sync_note("play"+str(i),game.live[i].note,visible_keys,false,-1.0,held)
				if game.live[i].started and game.live[i].note.kind=="slide":
					var lane = SynkChart.lane_at(game.live[i].note,render_time())
					var beam = active_beams[clampi(roundi(lane),0,SynkChart.MAX_LANE)]
					beam.position.x = lane_x(lane); beam.visible = true
					var pulse = .5+.5*sin(animation_time*TAU*3.0)
					beam.get_child(0).scale = Vector3(1+pulse*.12,.9+pulse*.25,1)
					beam.get_child(0).material_override.set_shader_parameter("opacity",.45+pulse*.3)
			elif game.live[i].note.kind in ["hold","slide"] and game.live[i].has("missed_at"):
				# A missed hold or slide turns gray and keeps travelling down the highway until it leaves.
				var key="play"+str(i)
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
		for id in game.capture.gestures: sync_note("gesture"+str(id),game.capture.gestures[id].note,visible_keys,true)
	for key in notes.keys():
		if not visible_keys.has(key): notes[key].node.queue_free(); notes.erase(key)

func style_record_ghost(node: Node3D) -> void:
	for mesh in node.get_children():
		if not mesh is MeshInstance3D: continue
		var mat: Material=mesh.material_override
		if mat==null and mesh.mesh: mat=mesh.mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("ghost_fade",.32)
			mat.set_shader_parameter("glow_pulse",0.0)
		elif mat is StandardMaterial3D:
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a=.32; mat.emission_enabled=false
