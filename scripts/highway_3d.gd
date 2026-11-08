extends Node3D
const SsrgNotes = preload("res://scripts/ssrg_note_animation.gd")
const SsrgCurves = preload("res://scripts/ssrg_runtime_curves.gd")

# Gameplay uses one flat canvas with a shared projection curve; the recorder uses a perspective camera.
const CENTER_LANE = (SynkChart.LANES-1)*.5
# Keep the reference taper and original track width, with larger readable note faces.
const HIGHWAY_HALF_WIDTH = 9.75
const EDGE_MARGIN = .2
const NOTE_SCALE = 1.3
const NOTE_WIDTH = 3.1*NOTE_SCALE
const FIT = NOTE_SCALE/1.3
# Every lane, the outer two included, gets the same share of the highway.
const LANE_WIDTH = 62.71392*(9.75/512.0)
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
var colors: Array = COLORS + [COLORS[1]]
var stage_color = Color("0b1030")
var laser_streaks: Node3D
var cover_palette_active = false
var game: Control
var camera: Camera3D
var notes: Dictionary = {}
var note_meshes: Array = []
var materials: Array = []
var effects: Node3D
var recorder_guides: Node3D
var lane_markers: Node3D
var recorder_channels: MeshInstance3D
var recorder_channel_material: ShaderMaterial
var recorder_lit: PackedFloat32Array = PackedFloat32Array()
var guide_material: ShaderMaterial
var active_beams: Array = []
# Light columns that follow each finger touching the highway.
var finger_beams: Array = []
var finger_beam_material: ShaderMaterial
var ssrg_finger_beam_material: ShaderMaterial
var animation_time = 0.0
var animated_materials: Array = []
var bursts: Array = []
var hit_pool: Array = []
var play_render_cursor = 0
var reference_note_meshes: Dictionary = {}
var spark_mesh: SphereMesh
var miss_shake_remaining = 0.0
var ssrg_shake_x=0.0
var cover_backdrop: MeshInstance3D
var rail_atmosphere: Node3D
var synk_hits:Node3D
var concept_theme:Node3D
var ssrg_theme: Node3D
var cover_material: ShaderMaterial
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
var track_nodes: Array = []
var sky_material: ShaderMaterial
# The cover plane sits this far in front of the camera, behind the whole highway.
const COVER_DISTANCE = 150.0
const CAMERA_POSITION = Vector3(0,10,10)
const CAMERA_PITCH = -35.0
# Highway angle setting: the camera swings around the judgment bar, keeping its distance and the
# bar's place on screen (touch input relies on it), so only the slope of the highway changes.
const PERSPECTIVE_SCALE = .55
# How far below the screen centre the judgement bar sits (as seen through a 45-degree lens):
# 14 degrees puts it about 80% down the screen, clear of the bottom edge (18 was about 89%).
const BAR_SCREEN_ANGLE = 14.0
const BAR_DISTANCE = 14.142136*PERSPECTIVE_SCALE*cos(deg_to_rad(BAR_SCREEN_ANGLE))/cos(deg_to_rad(BAR_BELOW_CENTER))
const BAR_BELOW_CENTER = rad_to_deg(atan(tan(deg_to_rad(BAR_SCREEN_ANGLE))/PERSPECTIVE_SCALE))
const MIN_ANGLE = 18.0
const MAX_ANGLE = 90.0
# Fixed gameplay lens, including the loading-card transition.
# A closer, wider lens narrows the far end while preserving the judgment bar framing.
const GAMEPLAY_FOV = rad_to_deg(2.0*atan(tan(deg_to_rad(45.0)*.5)/PERSPECTIVE_SCALE))

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
	node.extra_cull_margin=TRACK_LENGTH+SSRG_STAGE_DISTANCE
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

# The recorder splits the full highway into 13 equal lanes (wider, easier targets).
# Charts store lane numbers only, so play still places those lanes at SSRG's spacing.
const RECORD_LANE_WIDTH = PAD_HALF_WIDTH*2.0/SynkChart.LANES
func lane_step() -> float: return RECORD_LANE_WIDTH if game.uses_recorder_colors() else LANE_WIDTH
func lane_x(lane: float) -> float: return (lane-CENTER_LANE)*lane_step()
# Where a note is drawn: its lane centre, nudged inward on the outer lanes so the note
# (about two lanes wide) stays inside the rails. Judging and touch still use lane_x.
# Taps are judged on the note itself, not its lane: a touch counts when it lands within the
# note's drawn half-width at the judgement bar (plus a little grace).
func note_reach() -> float:
	if game.uses_ssrg_gameplay(): return SSRG_NOTE_SIZE.x * .5 * game.note_size * 1.1
	return NOTE_WIDTH * .5 * game.note_size * 1.1
# SSRG Playables use SSRG's own layout, in its 2D units scaled so its rail edge at the
# judgement line (512 units from centre) meets the rails at x = 9.75: 13 positions 62.7 units
# apart around the centre, and notes and target rings 212 x 116 units.
const SSRG_UNIT = 9.75/512.0
# SSRG footage: judgement line 0.379 screen heights below centre (87.9% down), rails 0.826
# screen heights out from the centre there.
const SSRG_LINE_DOWN = .379
const SSRG_RAIL_OUT = .826
const SSRG_FOOTAGE_ASPECT = 2.246
# Fixed SSRG view, not adjustable: tilt 20 and lens 45, fitted to the rails in SSRG footage.
const SSRG_TILT = 20.0
const SSRG_LENS = 45.0
const SSRG_STEP = 62.71392*SSRG_UNIT
const SSRG_NOTE_SIZE = Vector2(212.0,116.0)*SSRG_UNIT
# SYNK and SSRG share thirteen positions, numbered 0..12.
func ssrg_x(lane: float) -> float: return (lane*12.0/SynkChart.MAX_LANE-6.0)*SSRG_STEP
# Lane <-> world x for touches. SSRG Playables use the SSRG spacing above, so a finger is
# measured in the same lane units as the notes it is judged against.
func lane_world_x(lane: float) -> float: return ssrg_x(lane) if game.uses_ssrg_gameplay() else lane_x(lane)
func world_lane(x: float) -> float:
	if game.uses_ssrg_gameplay(): return clampf((x/SSRG_STEP+6.0)*SynkChart.MAX_LANE/12.0,0.0,float(SynkChart.MAX_LANE))
	return x/lane_step()+CENTER_LANE
func note_x(lane: float) -> float:
	# Thirteen distinct centres, with the same spacing as SSRG. Never clamp adjacent
	# outer lanes onto one another to fit a wide note face.
	return lane_world_x(lane)
# Notes travel the whole 60-unit track, from the far end to the judgement bar.
func uses_projected_highway() -> bool:
	return game != null and not game.uses_recorder_colors() and (game.mode in ["play","paused"] or game.highway_preview)
func source_long_visuals() -> bool:
	return uses_projected_highway()
func enhanced_synk_long_visuals() -> bool:
	return false
func visible_length() -> float: return TRACK_LENGTH
func travel_speed() -> float: return TRACK_LENGTH / game.note_travel_seconds()
# Recovered from Perspective2dSettings.ToAcceleration in the supplied APK:
# raw chart progress p becomes q = p^6 for BOTH position and sprite size.
# Gameplay is drawn directly in the original 2D UI coordinate system on X/Z.
# An orthographic camera adds no further perspective to the recovered curve.
const SSRG_APPROACH_POWER = 6.0
const SSRG_STAGE_DISTANCE = 514.0*SSRG_UNIT
const SSRG_UI_HEIGHT = 640.0
# Paired 3.6-speed recordings: source note footprints are about 80% of
# SYNK's previous maximum. This is an artwork fit, not a timing change.
const SSRG_REFERENCE_NOTE_SCALE = .8
func ssrg_art_scale() -> float:
	return game.note_size*(SSRG_REFERENCE_NOTE_SCALE if game.ssrg_playable_run else 1.0)
func ssrg_canvas_height() -> float:
	var view=get_viewport().get_visible_rect().size
	var aspect=maxf(.1,view.x/maxf(1.0,view.y))
	# Keep the reference canvas on phones. Narrow landscape screens/tablets
	# must still fit the full outer note sprites and their touch rectangles.
	var playable_width=12.0*62.71392+212.0*game.note_size+32.0
	if not game.uses_ssrg_gameplay():playable_width=(FRAME_HALF_WIDTH*2.0+NOTE_WIDTH*game.note_size)/SSRG_UNIT+32.0
	return maxf(SSRG_UI_HEIGHT,playable_width/aspect)
func ssrg_approach(z: float) -> float:
	return pow(maxf(1.0+z/TRACK_LENGTH,0.0),SSRG_APPROACH_POWER)
# Mirrors ssrg_warp_z() in ssrg_warp.gdshaderinc.
func ssrg_warped_z(z: float) -> float:
	if not uses_projected_highway(): return z
	return SSRG_STAGE_DISTANCE*(ssrg_approach(z)-1.0)
func update_ssrg_warp() -> void:
	var on = 1.0 if uses_projected_highway() else 0.0
	RenderingServer.global_shader_parameter_set("ssrg_warp",Vector4(on,SSRG_APPROACH_POWER,SSRG_STAGE_DISTANCE,TRACK_LENGTH))
func render_time() -> float:
	if uses_projected_highway() and game.mode=="paused" and game.visual_clock_ready: return game.visual_song_time
	return game.visual_song_time if game.audio.playing and game.mode in ["play","record"] and game.countdown<=0 and game.resume_countdown<=0 else game.song_time
func note_position(lane: float, chart_time: float) -> Vector3:
	return Vector3(note_x(lane), .13, (render_time()-chart_time)*travel_speed())
func apply_camera(shake: Vector3 = Vector3.ZERO) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = GAMEPLAY_FOV
	# SSRG Playables draw their track out to 1500 units (ssrg_stage.gd); other views stop at 260.
	camera.far = 1600.0 if game != null and game.uses_ssrg_gameplay() else 260.0
	camera.position = camera_rest_position() + shake; camera.rotation_degrees = Vector3(-highway_angle(), 0, 0)
	# Place the SSRG judgment area near the bottom while preserving the camera's
	# projection for note rendering and touch raycasts together.
	if uses_projected_highway():
		# UI y=280 at the top, y=-234 at judgment. X/Z is a flat UI canvas;
		# camera centre corresponds to original UI (0,0), never a fitted lens.
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var canvas_height=ssrg_canvas_height()
		camera.size = canvas_height*SSRG_UNIT
		# UI bottom -320 remains attached to the display bottom during fitting.
		var center_ui=canvas_height*.5-320.0
		camera.position = Vector3(0,30,-(234.0+center_ui)*SSRG_UNIT)+shake
		camera.rotation_degrees = Vector3(-90,0,0)
	if game != null and game.mode == "record": orient_recorder_notes()

func orient_recorder_notes() -> void:
	# Recorder artwork lies on the track; perspective foreshortens it as the camera tilts.
	for entry in notes.values():
		orient_recorder_note(entry.node)

func orient_recorder_note(node: Node3D) -> void:
	for child in node.get_children():
		if child.has_meta("recorder_billboard"):
			child.rotation=Vector3(-PI*.5,0,0)
			if child.has_meta("flick_axis"):
				child.rotate_object_local(Vector3.FORWARD,float(child.get_meta("flick_direction"))*PI*.5)
				child.set_meta("flick_axis",Basis(Vector3.RIGHT,-PI*.5)*child.get_meta("flick_axis_local"))

func _ready() -> void:
	var aids=preload("res://scripts/record_aids.gd").new(); aids.world=self; add_child.call_deferred(aids)
	camera = Camera3D.new(); add_child(camera); camera.current = true
	camera.near = .1; camera.far = 260
	apply_camera()
	var environment = WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("06091e")
	var sky_shader = Shader.new()
	sky_shader.code = """shader_type sky;
	void sky() {
		COLOR = vec3(0.012, 0.013, 0.035);
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
	ssrg_theme=preload("res://scripts/ssrg_highway.gd").new(); ssrg_theme.world=self; add_child(ssrg_theme)
	build_effects()
	laser_streaks=preload("res://scripts/laser_streaks.gd").new(); add_child(laser_streaks); laser_streaks.build(self)
	synk_hits=preload("res://scripts/synk_hit_effects.gd").new();synk_hits.world=self;add_child(synk_hits)
	build_play_aids()
	build_cover_backdrop()
	concept_theme=preload("res://scripts/concept_highway.gd").new();concept_theme.world=self;add_child(concept_theme)
	rail_atmosphere=preload("res://scripts/stage_rail_effects.gd").new(); rail_atmosphere.world=self; add_child(rail_atmosphere)

func build_cover_backdrop() -> void:
	# Child of the camera so it always fills the view; drawn first so the highway blends over it.
	cover_material = ShaderMaterial.new(); cover_material.shader = preload("res://scripts/cover_backdrop.gdshader")
	cover_material.render_priority = -20
	for index in 4:cover_material.set_shader_parameter("ssrg_fever_%d" % index,load("res://assets/ssrg/imported/presentation/Fever_bg_%d.png" % (index+1)))
	animated_materials.append(weakref(cover_material))
	cover_backdrop = mesh_node(QuadMesh.new(),camera,cover_material)
	cover_backdrop.position = Vector3(0,0,-COVER_DISTANCE)
	cover_backdrop.visible = false

func set_cover(texture: Texture2D, tint: Color, album_art: bool = false) -> void:
	cover_material.set_shader_parameter("cover",texture)
	# Album art alone is shown twice: blurred to fill the screen, and sharp at its own size on top.
	var blurred = blurred_cover(texture) if album_art and texture else null
	cover_material.set_shader_parameter("album_art",blurred != null)
	cover_material.set_shader_parameter("cover_blurred",blurred)
	cover_material.set_shader_parameter("tint",tint)
	cover_material.set_shader_parameter("strength",1.0)
	# With no background or album art, the stage behind the highway is plain black.
	cover_material.set_shader_parameter("plain",texture == null)
	cover_material.set_shader_parameter("image_aspect",float(texture.get_width())/maxf(1.0,texture.get_height()) if texture else 1.0)
	cover_backdrop.visible = true

var blurred_covers: Dictionary = {}
# Shrinking to a few pixels and scaling back up smoothly gives a soft, cheap blur.
func blurred_cover(texture: Texture2D) -> Texture2D:
	var key = texture.get_instance_id()
	if blurred_covers.has(key): return blurred_covers[key]
	var image = texture.get_image()
	if image == null: return null
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(20,20,Image.INTERPOLATE_LANCZOS)
	image.resize(256,256,Image.INTERPOLATE_CUBIC)
	blurred_covers[key] = ImageTexture.create_from_image(image)
	return blurred_covers[key]

# Recolors notes, rails, the judgment bar, track and sky to the cover's colors.
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
	finger_beam_material.set_shader_parameter("tint",element_color("beams",colors[0]))
	ssrg_finger_beam_material.set_shader_parameter("tint",element_color("beams",Color(0,.7843137383,1)))
	for beam in active_beams:
		var mat: ShaderMaterial = beam.get_child(0).material_override
		mat.set_shader_parameter("tint",element_color("beams",colors[1])); mat.set_shader_parameter("recolor",true)
	# Notes already on screen were built with the old colors.
	clear_notes()

func update_cover_backdrop() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.y <= 0: return
	var aspect = viewport_size.x/viewport_size.y
	var height = camera.size*1.04 if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else 2.0*COVER_DISTANCE*tan(deg_to_rad(camera.fov*.5))*1.04
	(cover_backdrop.mesh as QuadMesh).size = Vector2(height*aspect,height)
	cover_material.set_shader_parameter("screen_aspect",aspect)
	# Track the projected rail silhouette without moving the camera or highway geometry.
	for side in [-1,1]:
		var far_world=Vector3(side*FRAME_HALF_WIDTH,0,-50)
		var near_world=Vector3(side*FRAME_HALF_WIDTH,0,0)
		if game.uses_ssrg_gameplay():
			far_world=Vector3(side*27.0*SSRG_UNIT,0,-492.0*SSRG_UNIT)
			near_world=Vector3(side*607.5*SSRG_UNIT,0,86.0*SSRG_UNIT)
		elif uses_projected_highway():
			far_world=Vector3(side*FRAME_HALF_WIDTH*ssrg_approach(-50),0,ssrg_warped_z(-50))
		var far_point=camera.unproject_position(far_world)/viewport_size
		var near_point=camera.unproject_position(near_world)/viewport_size
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
	cover_material.set_shader_parameter("brightness",game.features.effect("Background brightness"))

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
	track_nodes.append(box(self,Vector3(0,-.15,-28),Vector3(FRAME_HALF_WIDTH*2.0+.15,.25,64),base_material))
	var surface = PlaneMesh.new(); surface.size = Vector2(FRAME_HALF_WIDTH*2.0,60)
	var surface_material = track_material(TRACK_COLOR,.55); surface_material.render_priority = -9
	track_materials.append(surface_material)
	var rail = mesh_node(surface,self,surface_material); rail.position = Vector3(0,.008,-30)
	track_nodes.append(rail)
	# A translucent, darkened echo of the judgment color sits beneath the rails.
	highway_shadow_material=ShaderMaterial.new()
	highway_shadow_material.shader=preload("res://scripts/highway_shadow.gdshader")
	highway_shadow_material.render_priority=-8
	var shadow_plane=PlaneMesh.new(); shadow_plane.size=Vector2(FRAME_HALF_WIDTH*2.0,TRACK_LENGTH)
	highway_shadow=mesh_node(shadow_plane,self,highway_shadow_material)
	highway_shadow.name="HighwayColorShadow"; highway_shadow.position=Vector3(0,.014,-TRACK_LENGTH*.5)
	# Recording-only guides make lane targets readable without adding lines to gameplay.
	recorder_guides = Node3D.new(); recorder_guides.name = "RecorderGuides"; add_child(recorder_guides)
	guide_material = ShaderMaterial.new();guide_material.shader=preload("res://scripts/synk_canvas_color.gdshader")
	guide_material.set_shader_parameter("color",Color("777bd561"))
	for boundary in range(1,SynkChart.LANES):
		var guide_mesh = PlaneMesh.new(); guide_mesh.size = Vector2(.035,60+JUDGMENT_DEPTH*.5)
		var guide = mesh_node(guide_mesh,recorder_guides,guide_material)
		guide.position = Vector3((boundary-.5-CENTER_LANE)*RECORD_LANE_WIDTH,.055,(-60+JUDGMENT_DEPTH*.5)*.5)
	var marker_material = ShaderMaterial.new();marker_material.shader=preload("res://scripts/synk_canvas_color.gdshader")
	marker_material.set_shader_parameter("color",Color("8be8ffb8"))
	lane_markers = Node3D.new(); lane_markers.name = "LaneMarkers"; recorder_guides.add_child(lane_markers)
	for lane in SynkChart.LANES:
		var marker_mesh = PlaneMesh.new(); marker_mesh.size = Vector2(.22,.62)
		var marker = mesh_node(marker_mesh,lane_markers,marker_material)
		marker.position = Vector3(lane_x(lane),.052,-.03)
	# Recorder pad: SSRG's thirteen channels drawn as slots that light under a finger.
	var channel_mesh = PlaneMesh.new(); channel_mesh.size = Vector2(PAD_HALF_WIDTH*2.0,JUDGMENT_DEPTH)
	recorder_channel_material = ShaderMaterial.new(); recorder_channel_material.shader = preload("res://scripts/recorder_channels.gdshader")
	recorder_channel_material.set_shader_parameter("span",SynkChart.LANES*RECORD_LANE_WIDTH/(PAD_HALF_WIDTH*2.0))
	recorder_channel_material.render_priority = 1
	recorder_channels = mesh_node(channel_mesh,self,recorder_channel_material)
	recorder_channels.name = "RecorderChannels"; recorder_channels.position = Vector3(0,.05,0); recorder_channels.visible = false
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
		neon_edge.position = Vector3(side*(FRAME_HALF_WIDTH-.03),.035,-28)
		neon_nodes.append(neon_edge)
	# A bit deeper than the visible note face so the hit line reads clearly.
	var judgment_mesh = QuadMesh.new(); judgment_mesh.size = Vector2(PAD_HALF_WIDTH*2.0,JUDGMENT_DEPTH)
	judgment_material = ShaderMaterial.new(); judgment_material.shader = preload("res://scripts/judgment_bar.gdshader")
	# Fixed canvas layers: road, band, ribbons, note faces, then hit effects.
	# Transparent distance sorting must not put the band over approaching notes.
	judgment_material.render_priority=-6 if uses_projected_highway() else 0
	animated_materials.append(weakref(judgment_material))
	var judgment_bar = mesh_node(judgment_mesh,self,judgment_material)
	judgment_bar.name = "JudgmentPads"
	judgment_bar.position = Vector3(0,.035,0); judgment_bar.rotation_degrees.x = -90
	for edge in [-1,1]:
		var edge_mesh = QuadMesh.new(); edge_mesh.size = Vector2(PAD_HALF_WIDTH*2.0,.025)
		var border_material=ShaderMaterial.new();border_material.shader=preload("res://scripts/synk_canvas_color.gdshader")
		border_material.render_priority=-5 if uses_projected_highway() else 0
		border_material.set_shader_parameter("color",Color(Color("fff1cf"),.85))
		var border = mesh_node(edge_mesh,judgment_bar,border_material)
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
	# A hit colour picked on the Hit effects page wins over theme and adaptive colours.
	if key in ["hits","sparks"] and game!=null and str(game.get("hit_color"))!="" and not game.uses_recorder_colors():
		return Color.from_string(str(game.hit_color),fallback)
	return SynkGameplayColors.resolve(game,key,fallback) if game!=null else fallback

func trail_color(palette: int) -> Color:
	if game.old_ssrg_ui() and palette in [1,3]: return Color("edb65c")
	if source_long_visuals() and palette in [1,3]: return Color("f9d568")
	if palette in [1,3] and game.uses_recorder_colors(): return Color("f9d568")
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
	var concept=game.highway_style in preload("res://scripts/concept_highway.gd").STYLES and not game.uses_recorder_colors() and not game.uses_ssrg_gameplay()
	var prism = game != null and game.uses_ssrg_gameplay() and not game.uses_recorder_colors()
	var gold = game == null or game.uses_recorder_colors() or (game.highway_style=="gold" and not game.uses_ssrg_gameplay())
	var darkness = clampf(float(game.get("highway_opacity")),.3,1.6) if game != null and game.get("highway_opacity") != null else 1.0
	judgment_material.render_priority=-6 if uses_projected_highway() else 0
	if game.uses_recorder_colors(): darkness=1.0
	for node in gold_nodes: node.visible = gold
	for node in neon_nodes: node.visible = not gold and not prism and not concept
	get_node("JudgmentPads").position.z=0.0
	get_node("JudgmentPads").scale=Vector3.ONE
	get_node("JudgmentPads").visible=not prism
	if ssrg_theme: ssrg_theme.refresh()
	var rail = custom_color("rail_color")
	var band = custom_color("band_color")
	# Tap color on the left rail, sustained on the right, unless the player picked one color.
	for i in 2:
		var tint: Color = rail if rail != null else (colors[1] if i==1 else colors[0])
		rail_edge_materials[i].set_shader_parameter("tint",tint)
		rail_edge_materials[i].set_shader_parameter("tint_amount",1.0 if rail != null else 0.0)
		neon_rail_materials[i].set_shader_parameter("tint",tint)
	if gold:
		judgment_material.shader = preload("res://scripts/judgment_bar.gdshader")
		# Adaptive colors pull the band toward the artwork's main color; the theme keeps it golden.
		var base: Color = Color("1b1c20") if game.uses_recorder_colors() else (band if band != null else JUDGMENT_GOLD)
		judgment_material.set_shader_parameter("base_color",base)
		judgment_material.set_shader_parameter("sweep_color",Color("2c2d33") if game.uses_recorder_colors() else base.lerp(Color.WHITE,.6))
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
	for m in judgment_borders:
		m.render_priority=-5 if uses_projected_highway() else 0
		m.set_shader_parameter("color",Color(Color("f4f1ea"),.18) if game.uses_recorder_colors() else Color(Color("fff1cf") if gold else Color("ead6ff"),.85 if gold else 1.0))
	var judgment_color: Color=judgment_material.get_shader_parameter("base_color")
	highway_shadow_material.set_shader_parameter("tint",judgment_color.darkened(.65))
	highway_shadow_material.set_shader_parameter("opacity",.2)
	for m in track_materials:
		m.set_shader_parameter("color",element_color("track",m.get_shader_parameter("color")))
	# The source rail sprites already contain the translucent black road. Old
	# rectangular 3D floor passes otherwise tint the whole orthographic canvas blue.
	var original_stage=game.uses_ssrg_gameplay() and not game.uses_recorder_colors()
	for node in track_nodes: node.visible=not original_stage and not concept
	if original_stage:
		for m in track_materials: m.set_shader_parameter("opacity",0.0)
	if highway_shadow: highway_shadow.visible=not original_stage and not concept
	if cover_material:
		var glow=rail_glow_colors()
		cover_material.set_shader_parameter("rail_glow_left",glow[0])
		cover_material.set_shader_parameter("rail_glow_right",glow[1])
		# The soft glow that spread outside the rails is removed.
		cover_material.set_shader_parameter("rail_glow_opacity",0.0)

	if concept_theme:concept_theme.refresh()

func build_effects() -> void:
	spark_mesh = SphereMesh.new(); spark_mesh.radius = .065; spark_mesh.height = .13
	finger_beam_material = ShaderMaterial.new(); finger_beam_material.shader = preload("res://scripts/finger_beam.gdshader")
	# Drawn over the judgment bar so the lit lane reads all the way down to the bar's near edge.
	finger_beam_material.render_priority = 2
	finger_beam_material.set_shader_parameter("rail_half_width",FRAME_HALF_WIDTH)
	finger_beam_material.set_shader_parameter("ssrg_beam_reach",SSRG_BEAM_REACH)
	finger_beam_material.set_shader_parameter("ssrg_beam_art",preload("res://assets/ssrg/imported/beam_original.png"))
	# Original atlas material uses SrcAlpha/OneMinusSrcAlpha, not additive glow.
	ssrg_finger_beam_material=ShaderMaterial.new()
	ssrg_finger_beam_material.shader=preload("res://scripts/ssrg_beam.gdshader")
	ssrg_finger_beam_material.render_priority=-6
	ssrg_finger_beam_material.set_shader_parameter("ssrg_beam_reach",SSRG_BEAM_REACH)
	ssrg_finger_beam_material.set_shader_parameter("ssrg_beam_art",preload("res://assets/ssrg/imported/beam_original.png"))
	ssrg_finger_beam_material.set_shader_parameter("tint",element_color("beams",Color(0,.7843137383,1)))
	var beam_mesh = PlaneMesh.new(); beam_mesh.size = Vector2(NOTE_WIDTH,58+JUDGMENT_DEPTH*.5)
	for i in 13:
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
var ssrg_note_materials: Array = []
func shared(key: String, build: Callable) -> Material:
	if shared_materials.has(key): return shared_materials[key]
	var mat: Material = build.call()
	mat.set_meta("shared", true)
	if mat.has_meta("ssrg_palette"): ssrg_note_materials.append(weakref(mat))
	shared_materials[key] = mat
	return mat
func clear_shared_materials() -> void:
	shared_materials.clear()
	ssrg_note_materials.clear()
	ssrg_animation_frame=-1
# Gives this mesh its own copy of a shared material before it is changed.
func own_material(mesh: GeometryInstance3D) -> Material:
	var mat: Material = mesh.material_override
	if mat == null and mesh is MeshInstance3D and mesh.mesh: mat = mesh.mesh.surface_get_material(0)
	if mat == null or not mat.has_meta("shared"): return mat
	var copy: Material = mat.duplicate()
	copy.remove_meta("shared")
	mesh.material_override = copy
	if copy is ShaderMaterial: animated_materials.append(weakref(copy))
	if copy.has_meta("ssrg_palette"): ssrg_note_materials.append(weakref(copy))
	return copy

func asset_material(name: String, palette: int, region = Vector4(0,0,1,1), opacity = 1.0) -> ShaderMaterial:
	return shared("asset|%s|%d|%s|%s|%s|%s|%s" % [name, palette, region, opacity, colors[palette], game.uses_recorder_colors(), long_head_tint(palette)], func(): return build_asset_material(name, palette, region, opacity))
# Hold and slide heads take their ribbon's colour (SSRG gold where the ribbon is gold).
func long_head_tint(palette: int) -> Color:
	return trail_color(palette) if palette in [1,3] else colors[palette]
func build_asset_material(name: String, palette: int, region = Vector4(0,0,1,1), opacity = 1.0) -> ShaderMaterial:
	var mat = ShaderMaterial.new(); mat.shader = load("res://scripts/neon_asset.gdshader")
	if name.begins_with("Tap_") and game.uses_recorder_colors():
		mat.shader=preload("res://scripts/recorder_note.gdshader")
		mat.render_priority=2
	if uses_projected_highway() and not game.uses_ssrg_gameplay() and name.begins_with("Tap_"):
		mat.shader=preload("res://scripts/synk_canvas_art.gdshader");mat.render_priority=3
	mat.set_shader_parameter("artwork",load("res://assets/neon/"+name+".png"))
	mat.set_shader_parameter("region",region); mat.set_shader_parameter("opacity",opacity)
	if name.begins_with("Hit_"):mat.set_shader_parameter("project_geometry",false);mat.set_shader_parameter("note_brightness_applies",false)
	# Blue tap artwork keeps its gradient; sustained and flick art takes its type color.
	mat.set_shader_parameter("recolor",palette!=0 or cover_palette_active or game.highway_style in preload("res://scripts/concept_highway.gd").STYLES or (game.highway_colors=="theme" and game.gameplay_colors.has("tap"))); mat.set_shader_parameter("tint",long_head_tint(palette))
	mat.set_shader_parameter("motion",.7 if name.begins_with("Hold_") else (.35 if name.begins_with("Flick_") else .12))
	if name.begins_with("Tap_") or name.begins_with("Hold_") or name.begins_with("Flick_") or name.begins_with("Slide_"):
		mat.set_shader_parameter("glow_pulse",.18)
	animated_materials.append(weakref(mat))
	return mat

func touch_hit_position(lane: float,pointer_id: int) -> Vector3:
	var x=lane_world_x(lane)
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
func projected_synk_effects() -> bool:
	return uses_projected_highway() and not game.uses_ssrg_gameplay()

func make_bloom() -> Dictionary:
	var node = Node3D.new(); add_child(node)
	var flat_mesh = PlaneMesh.new(); flat_mesh.size = Vector2(10.0, 6.0)
	var flat_mat = ShaderMaterial.new(); flat_mat.shader = preload("res://scripts/bloom_hit.gdshader"); flat_mat.render_priority = 5
	var flat = mesh_node(flat_mesh, node, flat_mat); flat.position = Vector3(0, .02, 0)
	var spark_mesh = QuadMesh.new(); spark_mesh.size = Vector2(6.0, 5.0)
	var spark_mat = ShaderMaterial.new(); spark_mat.shader = preload("res://scripts/bloom_sparks.gdshader"); spark_mat.render_priority = 6
	var sparks = mesh_node(spark_mesh, node, spark_mat); sparks.position = Vector3(0, 2.4, 0); sparks.rotation = camera.rotation
	if projected_synk_effects():sparks.position.z=-spark_mesh.size.y*.5
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
	b.node.scale=Vector3.ONE*(.55*game.note_size if projected_synk_effects() else 1.0)*game.hit_size
	b.node.get_child(1).position.z=-b.node.get_child(1).mesh.size.y*.5 if projected_synk_effects() else 0.0
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
			elif b.kind == "slide": b.node.position.x = note_x(SynkChart.lane_at(b.sustain_entry.note, game.song_time))
		elif not b.sustain_entry.is_empty(): b.sustain_entry = {}
		if (not sustained and b.age >= BLOOM_LIFE) or (game.mode not in ["play","record","paused"] and not game.highway_preview):
			b.node.visible = false; blooms.remove_at(i); bloom_pool.append(b); continue
		var t = b.age / BLOOM_LIFE
		b.flat.set_shader_parameter("age", t); b.flat.set_shader_parameter("strength", intensity*(.42 if projected_synk_effects() else 1.0))
		b.sparks.set_shader_parameter("age", t); b.sparks.set_shader_parameter("strength", particles*(.65 if projected_synk_effects() else 1.0))

func layout_classic_hit(burst:Dictionary) -> void:
	burst.node.scale=Vector3.ONE*(.62*game.note_size if projected_synk_effects() else 1.0)*game.hit_size
	if projected_synk_effects():
		# Bright centers are low in the original upright sprites. On the flat
		# canvas, offset in screen space so they land on the timing line.
		burst.flash.position.z=-(.83/(1.0+HIT_MIRROR)-.5)*burst.flash.mesh.size.y*burst.flash.scale.y
		burst.fill.position.z=-.18*burst.fill.mesh.size.y*burst.fill.scale.y
	else:
		burst.flash.position.z=0.0;burst.fill.position.z=0.0

func spawn_hit(lane: float, kind: String, direction: int = 0, sustain_entry: Dictionary = {},pointer_id: int=-999) -> void:
	if ssrg_theme and (ssrg_theme.active or game.hit_style=="ssrg") and not prewarming_hits:
		ssrg_theme.spawn(lane, kind, sustain_entry, pointer_id); return
	if game.hit_style == "bloom" and not prewarming_hits:
		spawn_bloom(lane, kind, sustain_entry, pointer_id); return
	if bursts.size() >= 32:
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
		tint_classic_hit(reused,palette,kind)
		for particle_index in reused.particles.size():
			var particle=reused.particles[particle_index]
			particle.node.hide()
			if kind=="flick":
				var axis=camera.basis*[Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(direction,0,3)]
				var sideways=camera.basis*[Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT,Vector3.UP][clampi(direction,0,3)]
				particle.velocity=axis*(5.0+float(particle_index%7)*1.4)+sideways*sin(particle_index*TAU/24.0)*4.8
				particle.node.quaternion=Quaternion(Vector3.BACK,particle.velocity.normalized())
		layout_classic_hit(reused)
		reused.node.show()
		bursts.append(reused)
		return
	var node = Node3D.new(); add_child(node); node.position = touch_hit_position(lane,pointer_id)+Vector3(0,.065,0)
	# Share the regular hit flash across taps, slides and flicks.
	var flash = artwork(node,"Hit_Effect_Blue" if palette==0 else "Hit_Effect_Pink",palette,Vector3(0,(2.25-4.0*HIT_MIRROR*.5)*FIT,0),Vector2(5.8,4.0*(1.0+HIT_MIRROR))*FIT)
	own_material(flash)  # each hit fades on its own
	flash.material_override.set_shader_parameter("mirror_extra",HIT_MIRROR)
	flash.material_override.set_shader_parameter("tint",hit_color)
	flash.material_override.set_shader_parameter("recolor",classic_recolor(palette))
	var fill_mesh = QuadMesh.new(); fill_mesh.size = Vector2(5.9,4.2)*FIT
	var fill_material = ShaderMaterial.new(); fill_material.shader = preload("res://scripts/hit_fill.gdshader")
	fill_material.set_shader_parameter("tint",hit_color)
	var fill = mesh_node(fill_mesh,node,fill_material)
	fill.position = Vector3(0,2.25*FIT,0); fill.rotation = camera.rotation
	var flick_axis = camera.basis * [Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(direction,0,3)]
	var ring_mesh = TorusMesh.new(); ring_mesh.inner_radius=.9*FIT; ring_mesh.outer_radius=.97*FIT; ring_mesh.rings=32; ring_mesh.ring_segments=6
	var ring = mesh_node(ring_mesh,node,material(hit_color,.8))
	var particles: Array = []
	# Each spark is its own object and draw call; phones get fewer so dense charts stay smooth.
	var particle_count = (10 if kind=="flick" else 6) if OS.has_feature("mobile") else (24 if kind=="flick" else 12)
	var particle_material = material(element_color("sparks",colors[palette].lightened(.65) if kind=="flick" else colors[palette]))
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
	bursts.append({"node":node,"age":0.0,"flash":flash,"fill":fill,"ring":ring,"particles":particles,"kind":kind,"flick_axis":flick_axis,"sustain_entry":sustain_entry,"pointer_id":pointer_id,"pool_key":pool_key})
	layout_classic_hit(bursts[-1])

# The blue tap art keeps its own gradient unless a hit colour was chosen.
func classic_recolor(palette: int) -> bool:
	return palette!=0 or cover_palette_active or (game.highway_colors=="theme" and game.gameplay_colors.has("hits")) or str(game.hit_color)!=""
func tint_classic_hit(burst: Dictionary,palette: int,kind: String) -> void:
	var hit_color=element_color("hits",colors[palette])
	burst.flash.material_override.set_shader_parameter("tint",hit_color)
	burst.flash.material_override.set_shader_parameter("recolor",classic_recolor(palette))
	burst.fill.material_override.set_shader_parameter("tint",hit_color)
	var ring: StandardMaterial3D=burst.ring.material_override
	ring.albedo_color=Color(hit_color,ring.albedo_color.a); ring.emission=hit_color
	var spark=element_color("sparks",colors[palette].lightened(.65) if kind=="flick" else colors[palette])
	for particle in burst.particles:
		var mat: StandardMaterial3D=particle.node.material_override
		if mat: mat.albedo_color=Color(spark,mat.albedo_color.a); mat.emission=spark
func recycle_hit(burst: Dictionary) -> void:
	burst.node.hide(); burst.sustain_entry={}
	if hit_pool.size()<HIT_POOL_LIMIT: hit_pool.append(burst)
	else: burst.node.queue_free()

# Shader warm-up. The Compatibility renderer compiles a shader the first time a material is
# drawn, which on phones stalls a frame or more; doing it mid-song reads as random stutter.
# While the loading card covers the stage, draw one of every note look, trail, ring and hit
# effect far down the highway for a few frames so every shader is ready before play starts.
var prewarmed: Dictionary = {}
func prewarm() -> void:
	var key = str(game.note_shape) + str(game.get("trail_style"))
	if prewarmed.has(key): return
	prewarmed[key] = true
	var group = Node3D.new(); group.name = "ShaderPrewarm"; add_child(group); group.position.z = -30.0
	make_cap(group, 1, 0, 0)
	var flick = SynkChart.note(0, 3, "flick"); flick.direction = 1; make_flick(group, flick, 2)
	var hold = SynkChart.note(0, 5, "hold"); hold.duration = .5; make_ribbon(group, hold, 1)
	var slide = SynkChart.note(0, 7, "slide"); slide.duration = .5; slide.end_lane = 9
	slide.path = [{"offset": 0.0, "lane": 7.0}, {"offset": .5, "lane": 9.0}]; make_ribbon(group, slide, 1)
	prewarming_hits = true
	for kind in ["tap", "hold", "flick"]: spawn_hit(5, kind, 1)
	prewarming_hits = false
	if game.hit_style == "bloom": spawn_bloom(5, "tap", {}, -999)
	for beam in finger_beams.slice(0, 1): beam.visible = true
	for i in 4: await get_tree().process_frame
	if is_instance_valid(group): group.queue_free()
	# Keep the warm-up hits: they go back into the pool for the song to reuse.
	for burst in bursts: recycle_hit(burst)
	bursts.clear()
	if synk_hits:
		for hit in synk_hits.hits:synk_hits.release(hit)
		synk_hits.hits.clear()

# Fill the hit-effect pool for the chart before play, so even a dense opening never builds a
# flash, ring and spark set mid-song. Counts cover the most hits of each kind that can be on
# screen at once (a hit lasts about 0.65 s); every flick direction the chart uses gets its own.
const HIT_POOL_LIMIT = 48
func prefill_hits() -> void:
	if ssrg_theme and ssrg_theme.active: ssrg_theme.prefill(); return
	var counts = {"tap": 0, "hold": 0}
	var flick_dirs = {}
	for entry in game.live:
		var kind = str(entry.note.kind)
		if kind == "flick": flick_dirs[int(entry.note.get("direction", 1))] = true
		elif kind == "hold": counts.hold += 1
		else: counts.tap += 1
	var wanted = {"0normal": mini(10, counts.tap), "1normal": mini(6, counts.hold)}
	for dir in flick_dirs: wanted["0flick" + str(dir)] = 3
	var have = {}
	for burst in hit_pool: have[burst.pool_key] = int(have.get(burst.pool_key, 0)) + 1
	var made: Array = []
	if game.hit_style == "bloom": prefill_blooms(); return
	prewarming_hits = true
	for pool_key in wanted:
		var kind = "hold" if pool_key == "1normal" else ("flick" if pool_key.begins_with("0flick") else "tap")
		var dir = int(pool_key.trim_prefix("0flick")) if kind == "flick" else 0
		for i in maxi(0, int(wanted[pool_key]) - int(have.get(pool_key, 0))):
			spawn_hit(5, kind, dir); made.append(bursts.pop_back())
	prewarming_hits = false
	for burst in made: recycle_hit(burst)

# --- Play aids -------------------------------------------------------------------------
# Lane hints, the hit-window preview, combo flares, chord lines,
# Hidden/Sudden modifiers and a loudness-driven stage pulse. Settings live in game.extras.
var window_bands: Array = []
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
	# Loudness from the master bus, for a stage that pulses with the music rather than a metronome.
	var analyzer = AudioEffectSpectrumAnalyzer.new(); analyzer.buffer_length = .1; analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
	AudioServer.add_bus_effect(0, analyzer)
	spectrum = AudioServer.get_bus_effect_instance(0, AudioServer.get_bus_effect_count(0) - 1)

func refresh_play_aids() -> void:
	pass  # Settings are read every frame; nothing needs rebuilding.

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
	m.set_shader_parameter("edge_only", 1.0 if edge_only else 0.0)
	m.render_priority=1 if uses_projected_highway() and not game.uses_ssrg_gameplay() else 4
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
	if uses_projected_highway():
		var q=pow(1.0-t,SSRG_APPROACH_POWER)
		gold_wave.position=Vector3(0,.07,SSRG_STAGE_DISTANCE*(q-1.0))
		gold_wave.scale.x=q
	else:
		gold_wave.position = Vector3(0, .07, -ease(t, .6) * 62.0 + 7.0)
		gold_wave.scale.x=1.0
	gold_bar.position = Vector3(0, .08, 0)
	(gold_wave.material_override as ShaderMaterial).set_shader_parameter("strength", 1.0 - t * t)
	(gold_bar.material_override as ShaderMaterial).set_shader_parameter("strength", .9 * (1.0 - clampf(gold_age / 1.0, 0.0, 1.0)))
	if t >= 1.0:
		gold_age = -1.0
		for node in [gold_wave, gold_bar]: node.visible = false

func update_play_aids(delta: float) -> void:
	var playing = game.mode == "play" or (game.mode == "paused" and game.paused_mode == "play")
	var counting = game.mode == "play" and game.countdown > 0
	var show_bands = counting and bool(extras_setting("window_preview", false)) and game.get("extras") != null
	for i in window_bands.size():
		window_bands[i].visible = show_bands
		if show_bands:
			var window = game.extras.perfect_window() if i == 0 else game.extras.great_window()
			(window_bands[i].mesh as PlaneMesh).size = Vector2(HIGHWAY_HALF_WIDTH * 2.0, maxf(.05, window * travel_speed() * 2.0))
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
		var mesh = BoxMesh.new(); mesh.size = Vector3((high - low) * lane_step(), .04, .14)
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
	if ssrg_theme: ssrg_theme.clear_hits()
	if synk_hits:synk_hits.clear()
	ssrg_beam_release.clear()
	for burst in bursts+hit_pool: burst.node.queue_free()
	bursts.clear(); hit_pool.clear()
	for bloom in blooms+bloom_pool:bloom.node.queue_free()
	blooms.clear();bloom_pool.clear()

func clear_notes() -> void:
	clear_shared_materials()
	play_render_cursor=0
	prebuilding=false; prebuild_queue.clear(); prebuild_total=0
	for entry in notes.values(): entry.node.queue_free()
	notes.clear()

func animate_effects(delta: float) -> void:
	if synk_hits:synk_hits.advance(delta)
	var running = game.mode in ["play","record"] or game.highway_preview
	if running: animation_time += delta
	# Every highway shader reads this one global clock (project setting shader_globals/synk_time).
	RenderingServer.global_shader_parameter_set("synk_time",animation_time)
	update_ssrg_warp()
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
		if (not sustained and burst.age>=.65) or (game.mode not in ["play","record","paused"] and not game.highway_preview):
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
			burst.node.position.x = note_x(SynkChart.lane_at(burst.sustain_entry.note,game.song_time))
		var flash_opacity = lerpf(attack*fade,.60+hold_wave*.26,hold_blend)
		var fill_opacity = lerpf(attack*fade,.55+hold_wave*.22,hold_blend)
		if sustained and burst.kind=="slide":
			var slide_flash = .18+.82*pow(hold_wave,2.0)
			flash_opacity = lerpf(attack*fade,slide_flash,hold_blend); fill_opacity = flash_opacity
		burst.flash.material_override.set_shader_parameter("opacity",flash_opacity*hit_intensity*(.65 if projected_synk_effects() else 1.0))
		burst.fill.material_override.set_shader_parameter("opacity",fill_opacity*hit_intensity*(.20 if projected_synk_effects() else 1.0))
		burst.fill.scale = Vector3(1.0+t*.7,1.0+t*.35,1).lerp(Vector3(1.18+hold_wave*.15,1.05+hold_wave*.14,1),hold_blend)
		burst.flash.scale = Vector3(1.0+t*.6,1.0+t*.25,1).lerp(Vector3(1.14+hold_wave*.12,1.0+hold_wave*.12,1),hold_blend)
		burst.ring.scale = Vector3.ONE*lerpf(.8+t*.75,1.12+hold_wave*.22,hold_blend)
		burst.ring.material_override.albedo_color.a = lerpf(fade*.8,.15+hold_wave*.25,hold_blend)*hit_intensity*(.5 if projected_synk_effects() else 1.0)
		layout_classic_hit(burst)
		var particle_count=burst.particles.size()
		for particle_index in particle_count:
			var particle=burst.particles[particle_index]
			var shown=float(particle_index)/maxi(1,particle_count)<particle_share
			particle.node.visible=shown
			if not shown: continue
			particle.node.position = particle.velocity*burst.age
			if burst.kind=="flick": particle.node.position += camera.basis*Vector3(0,1.8,0) if projected_synk_effects() else Vector3(0,1.8,0)
			else:
				if projected_synk_effects():particle.node.position=camera.basis*Vector3(particle.velocity.x*burst.age,particle.velocity.y*burst.age,0)
				particle.node.position += (camera.basis*Vector3.UP if projected_synk_effects() else Vector3.UP)*(-2.5*burst.age*burst.age)
			particle.node.scale = Vector3.ONE*maxf(.01,1-t)

func artwork(parent: Node3D, name: String, palette: int, position_value: Vector3, dimensions: Vector2, region = Vector4(0,0,1,1), opacity = 1.0) -> MeshInstance3D:
	var quad = QuadMesh.new(); quad.size = dimensions
	var node = mesh_node(quad,parent,asset_material(name,palette,region,opacity))
	node.position = position_value; node.rotation = camera.rotation
	node.set_meta("recorder_billboard",true)
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
	# Holds and slides follow the chosen note shape like taps: round shapes use SSRG's
	# round long-note puck, rectangles keep the rectangle head in the ribbon's gold.
	var long_puck=palette in [1,3] and game.round_notes()
	if (not recording and (ssrg_theme and ssrg_theme.active or source_long_visuals() and long_puck)) or (recording and long_puck):
		var cap=make_ssrg_cap(parent,position_value,palette,size)
		if recording:
			# Recorder slide pucks sit above the gold ribbon, like the other recorder note faces.
			var base: ShaderMaterial=cap.material_override
			cap.material_override=shared("ssrg_rec|%s" % base.get_instance_id(), func():
				var m: ShaderMaterial=base.duplicate(); m.render_priority=2; return m)
		elif enhanced_synk_long_visuals() and palette in [1,3]:make_source_long_glow(parent,position_value,size)
		return cap
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
		if game.uses_recorder_colors():m.render_priority=2
		if uses_projected_highway():
			m.shader=preload("res://scripts/synk_canvas_note.gdshader");m.render_priority=3
		m.set_shader_parameter("artwork",art)
		m.set_shader_parameter("hue_shift",colors[palette].h-base_hue)
		if game.highway_colors=="theme" and not game.uses_recorder_colors() and (game.gameplay_colors.has(role) or game.highway_style in preload("res://scripts/concept_highway.gd").STYLES):
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
	head.set_meta("recorder_billboard",true)
	return head

# SSRG style: glossy pucks coloured by note type (blue tap, gold hold, pink flick, green slide);
# tail caps use the small gold end puck. SYNK's own art in assets/ssrg.
const SSRG_ART=[preload("res://assets/ssrg/hold.png"),preload("res://assets/ssrg/tap.png"),preload("res://assets/ssrg/flick.png"),preload("res://assets/ssrg/slide.png")]
func make_ssrg_cap(parent: Node3D, position_value: Vector3, palette: int, size = 1.0) -> MeshInstance3D:
	var tail = size < game.note_size*.99
	# Connector pucks along slides (and the end puck) are the head note's own art at 60%.
	var phase=fposmod((render_time()-game.chart_offset())*game.chart_bpm()/60.0,1.0)
	var old_ui=game.old_ssrg_ui()
	var art := ssrg_cap_artwork(palette,tail,phase,old_ui)
	var mat = shared("ssrg|%d|%s|%s" % [palette,tail,old_ui], func():
		var m = ShaderMaterial.new(); m.shader = preload("res://scripts/reference_note.gdshader")
		m.set_shader_parameter("artwork",art); m.set_shader_parameter("approach_glow",false)
		m.set_meta("ssrg_palette",palette);m.set_meta("ssrg_tail",tail);m.set_meta("ssrg_old_ui",old_ui)
		m.set_shader_parameter("core_tint",Color("4fc8ff") if palette==0 else Color("ffc23a")); return m)
	var mesh_key = "ssrg|%s|%s|%s|%s|%s" % [size, tail, palette,ssrg_art_scale(),old_ui]
	if not reference_note_meshes.has(mesh_key):
		# Packaged IngameRenderer maximum sizes, before the shared p^6 scale.
		var quad = QuadMesh.new()
		quad.size = (Vector2(132,72) if tail else Vector2(212,116))*SSRG_UNIT*ssrg_art_scale()
		reference_note_meshes[mesh_key]=quad
	var head = mesh_node(reference_note_meshes[mesh_key],parent,mat)
	head.position = Vector3(position_value.x,.13,position_value.z)
	head.rotation = camera.rotation
	head.set_meta("ssrg_long_start",palette in [1,3] and not tail)
	# The GPU projects the raw timing depth onto a short 2D canvas. CPU frustum
	# culling must cover that displacement or notes pop in late despite p>=.5.
	head.extra_cull_margin=TRACK_LENGTH+SSRG_STAGE_DISTANCE
	ssrg_billboards.append(weakref(head))
	return head

func ssrg_cap_artwork(palette: int, tail: bool, phase: float, old_ui: bool) -> Texture2D:
	return SsrgNotes.artwork(palette in [1,3],not tail,phase,old_ui)

func make_source_long_glow(parent: Node3D, position_value: Vector3, size: float) -> void:
	var mesh=PlaneMesh.new()
	mesh.size=Vector2.ONE*(2.8 if size>=game.note_size*.99 else 1.9)*game.note_size
	var mat=shared("synk_long_glow",func():
		var result=ShaderMaterial.new();result.shader=preload("res://scripts/source_long_glow.gdshader")
		result.render_priority=-2
		return result)
	var glow=mesh_node(mesh,parent,mat)
	glow.name="LongNoteGlow"
	glow.position=Vector3(position_value.x,.14,position_value.z)
	glow.extra_cull_margin=TRACK_LENGTH+SSRG_STAGE_DISTANCE

# SSRG notes face the camera; when the view is changed mid-song they turn to face it again.
var ssrg_billboards: Array = []
func face_ssrg_billboards() -> void:
	var alive: Array = []
	for ref in ssrg_billboards:
		var node = ref.get_ref()
		if node: node.rotation = camera.rotation; alive.append(ref)
	ssrg_billboards = alive

func make_tail_cap(parent: Node3D, lane: float, offset: float, palette: int, recording = false) -> MeshInstance3D:
	var cap=make_cap(parent,lane,offset,palette,recording,TAIL_CAP_SIZE)
	# Keep its filled center above the ribbon instead of sinking with the smaller sprite.
	if game.round_notes() and not game.uses_ssrg_gameplay() and not source_long_visuals(): cap.position.y=.38*game.note_size
	cap.name="SustainEndCap"
	return cap

func make_flick(parent: Node3D, note: Dictionary, palette: int) -> void:
	make_cap(parent,float(note.lane),0,palette)
	# One bold chevron keeps the direction clear without overlapping arrows.
	var axis = camera.basis*[Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(int(note.direction),0,3)]
	for i in 1:
		var base = Vector3(note_x(note.lane),2.0*FIT*game.note_size,0)
		var arrow_mesh = QuadMesh.new(); arrow_mesh.size=Vector2(3.22,1.6)*FIT*game.note_size
		# The SSRG puck is wide and bright; a larger chevron keeps left, up and right readable on it.
		if game.uses_ssrg_gameplay(): arrow_mesh.size*=1.7
		var arrow_material = shared("arrow|%d|%s" % [palette, element_color("arrows",colors[palette])], func():
			var m = ShaderMaterial.new(); m.shader=preload("res://scripts/flick_arrow.gdshader")
			if uses_projected_highway() and not game.uses_ssrg_gameplay():
				m.shader=preload("res://scripts/synk_canvas_arrow.gdshader");m.render_priority=4
			m.set_shader_parameter("tint",element_color("arrows",colors[palette])); return m)
		var arrow = mesh_node(arrow_mesh,parent,arrow_material)
		arrow.position=base; arrow.rotation=camera.rotation
		arrow.rotate_object_local(Vector3.FORWARD,float(note.direction)*PI*.5)
		arrow.set_meta("recorder_billboard",true)
		arrow.set_meta("flick_direction",int(note.direction))
		arrow.set_meta("flick_axis_local",[Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(int(note.direction),0,3)])
		arrow.set_meta("flick_base",base)
		arrow.set_meta("flick_axis",axis)

# Trails run through the middle of their notes: just above the track for flat rectangle
# notes, and at half height through the thicker circle pucks.
func trail_height() -> float:
	if source_long_visuals(): return .13
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

# Miter joins meet at the exact connector without narrowing either segment.
func connector_sides(centers: Array) -> Array:
	var sides: Array=[]
	for i in centers.size():
		var incoming: Vector3=centers[i]-centers[maxi(0,i-1)]
		var outgoing: Vector3=centers[mini(centers.size()-1,i+1)]-centers[i]
		if incoming.length_squared()<.000001: incoming=outgoing
		if outgoing.length_squared()<.000001: outgoing=incoming
		incoming=incoming.normalized(); outgoing=outgoing.normalized()
		var first=Vector3(-incoming.z,0,incoming.x)
		var second=Vector3(-outgoing.z,0,outgoing.x)
		if first.x<0: first=-first
		if second.x<0: second=-second
		var joined=first+second
		var miter=joined.normalized() if joined.length_squared()>.0001 else second
		sides.append(miter*minf(4.0,1.0/maxf(.1,miter.dot(second))))
	return sides

func make_ribbon(parent: Node3D, note: Dictionary, palette: int, recording = false) -> void:
	var duration = float(note.duration)
	var source_visual=source_long_visuals() and not recording
	var old_source=source_visual and game.old_ssrg_ui()
	var half_width = TRAIL_HALF*.65
	# SSRG footage: holds and slides are a thin bar, about 23 px times p wide where the
	# note is 148 px times p (0.12 of the 212-unit sprite); drawn a little thicker, at 0.16.
	if source_visual: half_width = 116.0*.4*.5*SSRG_UNIT*ssrg_art_scale()
	if old_source: half_width = 116.0*.48*.5*SSRG_UNIT*ssrg_art_scale()
	# Recorder holds and slides share SSRG's look on the flat recorder highway: thin gold ribbon,
	# cream core, a slow shimmer flowing toward the line, and SSRG pucks at every turn.
	var recorder_slide=recording and note.kind in ["hold","slide"]
	if recorder_slide: half_width = 116.0*.4*.5*SSRG_UNIT*game.note_size*1.05
	var count = clampi(ceili(duration*96),32,1024)
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1,SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(2,SurfaceTool.CUSTOM_RGBA_FLOAT)
	var edge = SurfaceTool.new(); edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers = trail_centers(note,count,recording)
	var sides = trail_sides(centers)
	var ordered_segments:Array=[]
	var split_source=game.uses_ssrg_gameplay() and not recording and note.has("ssrg_orders")
	if note.kind=="slide" and note.path.size()>1 and (source_visual or recording and note.get("ssrg_path",false)):
		centers=[]
		var shape_points:Array=note.path.duplicate(true)
		for offset_value in note.get("checkpoints",[]):
			var offset=float(offset_value)
			if offset<=0.0 or offset>=duration or shape_points.any(func(point):return absf(float(point.offset)-offset)<.001):continue
			var anchor={"offset":offset,"lane":SynkChart.lane_at(note,float(note.time)+offset)}
			var insert_at=shape_points.size()-1
			for point_index in range(1,shape_points.size()):
				if float(shape_points[point_index].offset)>offset:insert_at=point_index;break
			shape_points.insert(insert_at,anchor)
		# Curved bend points are sampled along the shared lane curve; corners stay sharp.
		var any_curve=note.path.any(func(point): return bool(point.get("curve",false)))
		for point_index in shape_points.size():
			var point=shape_points[point_index]
			if any_curve and point_index>0:
				var from_offset=float(shape_points[point_index-1].offset); var to_offset=float(point.offset)
				for step in range(1,10):
					var sample_offset=lerpf(from_offset,to_offset,step/10.0)
					centers.append(Vector3(note_x(SynkChart.lane_at(note,float(note.time)+sample_offset)),trail_height(),sample_offset*travel_speed()*(1.0 if recording else -1.0)))
			centers.append(Vector3(note_x(float(point.lane)),trail_height(),float(point.offset)*travel_speed()*(1.0 if recording else -1.0)))
		count=centers.size()-1
		sides=connector_sides(centers)
	elif source_visual and note.kind!="slide":
		centers=[]
		for offset in [0.0]+solid_trail_offsets(note):
			centers.append(Vector3(note_x(float(note.lane)),trail_height(),-float(offset)*travel_speed()))
		count=centers.size()-1;sides=connector_sides(centers)
	for i in count:
		var a: Vector3 = centers[i]; var b: Vector3 = centers[i+1]
		var sa: Vector3 = sides[i]; var sb: Vector3 = sides[i+1]
		var source=source_visual
		# One continuous face avoids three overlapping copies making dark
		# triangles where a sharp slide changes direction.
		var layers=[0] if source and (old_source or not game.uses_ssrg_gameplay()) else ([3,0,1,2] if source and enhanced_synk_long_visuals() else ([0,1,2] if source else [0]))
		for layer in layers:
			var color=Color8(255,188,52) if layer==3 else [Color8(255,199,33),Color8(255,242,111),Color8(255,220,89)][layer]
			for index in [0,1,2,0,2,3]:
				var anchor=i if index in [0,3] else i+1
				var previous:Vector3=centers[maxi(0,anchor-1)]
				var following:Vector3=centers[mini(centers.size()-1,anchor+1)]
				st.set_uv([Vector2(0,float(i)/count),Vector2(0,float(i+1)/count),Vector2(1,float(i+1)/count),Vector2(1,float(i)/count)][index])
				# Source l1/l2/l3 are uniform chips. CUSTOM1 retains their colors
				# and the fixed horizontal 0/1/2-pixel expansions for each quad.
				st.set_custom(1,Color((7.0 if layer==3 else float(layer))*SSRG_UNIT,color.r,color.g,color.b) if source else Color(0,1,1,1))
				st.set_uv2(Vector2([a.z,b.z,b.z,a.z][index],[-1.0,-1.0,1.0,1.0][index]))
				st.set_custom(0,Color(a.x,a.z,b.x,b.z) if source else Color(0,0,0,0))
				st.set_custom(2,Color(previous.x,previous.z,following.x,following.z))
				st.add_vertex([a-sa*half_width,b-sb*half_width,b+sb*half_width,a+sa*half_width][index])
		for side in [-1,1]:
			var lift = Vector3(0,.01,0)
			for index in [0,1,2,0,2,3]:
				edge.add_vertex([a+sa*(side*half_width-.012),b+sb*(side*half_width-.012),b+sb*(side*half_width+.012),a+sa*(side*half_width+.012)][index]+lift)
		if split_source:
			ordered_segments.append({"mesh":st.commit(),"offset":-a.z/travel_speed()})
			st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT);st.set_custom_format(1,SurfaceTool.CUSTOM_RGBA_FLOAT);st.set_custom_format(2,SurfaceTool.CUSTOM_RGBA_FLOAT)
	var solid=game.trail_style=="solid" or source_visual or recorder_slide
	var trail_material: ShaderMaterial
	if solid:
		trail_material=shared("solid_trail|%s|%s|%s|%s|%s|%s|%s" % [trail_color(palette),half_width,source_visual,enhanced_synk_long_visuals(),game.uses_ssrg_gameplay(),old_source,recorder_slide], func():
			var m=ShaderMaterial.new(); m.shader=preload("res://scripts/solid_trail.gdshader")
			if uses_projected_highway() and not recording: m.render_priority=-4
			m.set_shader_parameter("source_art",source_visual)
			m.set_shader_parameter("old_ssrg_art",old_source)
			m.set_shader_parameter("joined_source",source_visual)
			m.set_shader_parameter("enhanced_synk",enhanced_synk_long_visuals())
			m.set_shader_parameter("ssrg_line_x_scale",ssrg_art_scale()*1.3 if source_visual else 1.0)
			m.set_shader_parameter("ssrg_ribbon",recorder_slide)
			m.set_shader_parameter("tint",trail_color(palette)); m.set_shader_parameter("ssrg_half_width",half_width); return m)
	else:
		var still = note.kind=="hold"
		trail_material=shared("art_trail|%d|%s|%s" % [palette, trail_color(palette), still], func():
			var m=build_asset_material("Hold_Note_Pink",palette,TRAIL_REGION,.85)
			m.set_shader_parameter("projected_ribbon",true)
			m.render_priority=-4 if uses_projected_highway() else 0
			m.set_shader_parameter("tint",trail_color(palette))
			if still:
				m.set_shader_parameter("motion",0.0); m.set_shader_parameter("glow_pulse",0.0)
			return m)
	if split_source:
		for segment in ordered_segments:
			segment.mesh.surface_set_material(0,trail_material)
			var mesh=mesh_node(segment.mesh,parent)
			mesh.set_meta("checkpoint_offset",segment.offset)
	else:
		st.set_material(trail_material); mesh_node(st.commit(),parent)
	if solid:
		make_solid_trail_joints(parent,note,palette,recording,half_width)
	else:
		var edge_material = shared("ribbon_edge|%s" % trail_color(palette), func():
			var m = ShaderMaterial.new(); m.shader = preload("res://scripts/ribbon_edge.gdshader")
			m.render_priority=-3 if uses_projected_highway() else 0
			m.set_shader_parameter("color",trail_color(palette).lightened(.4));m.set_shader_parameter("projected_ribbon",true); return m)
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
	# Path anchors add visual continuation caps without changing gameplay judgments.
	var duration=float(note.duration)
	var offsets: Array=[duration] if duration>0 else []
	var checkpoints: Array=note.get("checkpoints",[]).duplicate()
	# Shape anchors bend the ribbon; only timed continuation nodes get caps.
	for value in checkpoints:
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
		if source_long_visuals() or recording:
			var cap=make_tail_cap(parent,SynkChart.lane_at(note,float(note.time)+float(offset)),float(offset),palette,recording)
			cap.name="SlideTurnCap"
			cap.set_meta("solid_trail_joint",true); cap.set_meta("checkpoint_offset",offset)
			continue
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

func build_note_node(key: String, note: Dictionary, recording = false) -> void:
	# Materials this note creates are animated with the note (only while it's visible),
	# not by the global per-frame list, so hundreds of hidden prebuilt notes cost nothing.
	var first_material = animated_materials.size()
	var node = Node3D.new(); add_child(node)
	var palette = palette_for_kind(str(note.kind))
	if note.kind=="flick": make_flick(node,note,palette)
	else: make_cap(node,float(note.lane),0,palette,recording)
	if note.kind in ["hold","slide"]: make_ribbon(node,note,palette,recording)
	if game.uses_ssrg_gameplay() and not recording and note.has("ssrg_special") and game.ssrg_presentation:
		var head=node.get_child(0)
		var mat=own_material(head)
		mat.set_meta("ssrg_special",int(note.ssrg_special));mat.set_meta("ssrg_item",int(note.get("ssrg_item",0)))
		mat.set_shader_parameter("artwork",game.ssrg_presentation.special_art(int(note.ssrg_special),int(note.get("ssrg_item",0)),0.0))
	var lines: Array = []
	if recording: lines = make_alignment_lines(node,note,palette)
	var signature = (hash(note) if recording or game.mode=="record" else 0)^hash([game.note_speed,game.ssrg_speed_setting() if game.ssrg_playable_run else 0,game.note_shape,game.note_size,game.trail_style,game.uses_ssrg_gameplay(),game.old_ssrg_ui()])
	if uses_projected_highway() and not recording:
		for child in node.get_children():
			if child is GeometryInstance3D:
				child.extra_cull_margin=TRACK_LENGTH+SSRG_STAGE_DISTANCE
				# Native batch order: heads 20,000,000-100*Id; lines
				# 10,000,000-100*Id. Farther notes draw first on this flat canvas.
				child.sorting_offset=-ssrg_note_order(note,float(child.get_meta("checkpoint_offset",0.0)))
	var own_materials: Array = []
	for ref in animated_materials.slice(first_material):
		var m = ref.get_ref()
		if m and not m.has_meta("shared"): own_materials.append(ref)
	var keep_shared = animated_materials.slice(first_material).filter(func(ref): return ref.get_ref() != null and ref.get_ref().has_meta("shared"))
	animated_materials.resize(first_material); animated_materials.append_array(keep_shared)
	notes[key] = {"node":node,"signature":signature,"lines":lines,"held":false,"prebuilt":false,"materials":own_materials}
	if game.mode=="record": orient_recorder_note(node)

func ssrg_note_order(note: Dictionary, offset: float = 0.0) -> float:
	for point in note.get("ssrg_orders",[]):
		if point is Dictionary and is_equal_approx(float(point.get("offset",-1)),offset): return float(point.get("order",0))
	return float(note.get("ssrg_order",float(note.time)+offset))

func begin_prebuild() -> void:
	clear_notes()
	build_chords()
	prebuild_queue = range(game.live.size())
	prebuild_total = prebuild_queue.size()
	prebuilding = prebuild_total > 0

func step_prebuild() -> void:
	if not prebuilding: return
	var start = Time.get_ticks_usec()
	while not prebuild_queue.is_empty() and (Time.get_ticks_usec() - start) < PREBUILD_BUDGET_MS * 1000.0:
		var i: int = prebuild_queue.pop_front()
		if i >= game.live.size(): continue
		var key: String = game.live[i].key
		if notes.has(key): continue
		build_note_node(key, game.live[i].note)
		notes[key].node.visible = false; notes[key].prebuilt = true
	if prebuild_queue.is_empty(): prebuilding = false

func prebuild_progress() -> float:
	if prebuild_total <= 0: return 1.0
	return 1.0 - float(prebuild_queue.size()) / float(prebuild_total)

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
		look_signature = hash([game.note_speed,game.ssrg_speed_setting() if game.ssrg_playable_run else 0,game.note_shape,game.note_size,game.trail_style,game.uses_ssrg_gameplay(),game.old_ssrg_ui()])
	var signature = (hash(note) if recording or game.mode=="record" else 0)^look_signature
	if notes.has(key) and notes[key].signature != signature:
		notes[key].node.queue_free(); notes.erase(key)
	if not notes.has(key): build_note_node(key, note, recording)
	notes[key].node.visible = true
	if held: notes[key].head_hit=true
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

# Beam sections share the same apex and lane centres as the 2D notes.
func ssrg_beam_lane(lane: float) -> float:
	var slots=maxi(2,game.gameplay_lane_count())
	return roundf(clampf(lane,0,SynkChart.MAX_LANE)/SynkChart.MAX_LANE*(slots-1))*SynkChart.MAX_LANE/(slots-1)
# Original UIPolySprite: apex (0,286), bottom y=-320, width295;
# bottom channel centres are73.75 apart. Use its judgment-plane cross-section.
const SSRG_BEAM_REACH = 520.0*SSRG_UNIT
const SSRG_BEAM_NEAR = 86.0*SSRG_UNIT
func ssrg_beam_center(lane: float) -> float:
	return (lane*12.0/SynkChart.MAX_LANE-6.0)*73.75*(520.0/606.0)*SSRG_UNIT
func ssrg_beam_width() -> float:
	return 295.0*(520.0/606.0)*SSRG_UNIT
var ssrg_beam_release: Dictionary={}
func update_finger_beams(delta: float = 0.0) -> void:
	var touches: Array = game.pointers.values() if game.mode=="play" else []
	var ssrg=game.uses_ssrg_gameplay()
	if ssrg and game.mode=="paused": return
	var pressed:Dictionary={}
	if ssrg and game.countdown<=0:
		for touch in touches:
			var lane=ssrg_beam_lane(SynkCapture.lane(touch.position.x))
			if game.ssrg_playable_run and touch.has("ssrg_channel"):
				if int(touch.ssrg_channel)<0 or touch.get("ssrg_ended",false):continue
				lane=float(touch.ssrg_channel)*SynkChart.MAX_LANE/12.0
			elif game.ssrg_playable_run and touch.has("world") and not game.ssrg_touch_lane(touch.world,lane): continue
			pressed[clampi(roundi(lane*12.0/SynkChart.MAX_LANE),0,12)]=lane
	for i in finger_beams.size():
		var beam: MeshInstance3D = finger_beams[i]
		# Reuse one mesh per view; rebuild only when switching view/lane layout.
		var signature=hash([game.gameplay_lane_count(),game.note_size]) if ssrg else (-2 if uses_projected_highway() else -1)
		if beam.get_meta("layout",-99)!=signature:
			var mesh=PlaneMesh.new()
			var near=SSRG_BEAM_NEAR if uses_projected_highway() else JUDGMENT_DEPTH*.5
			var reach=SSRG_BEAM_REACH if uses_projected_highway() else 58.0
			mesh.size=Vector2(ssrg_beam_width() if ssrg else NOTE_WIDTH,reach+near)
			beam.mesh=mesh; beam.position.z=(near-reach)*.5
			beam.material_override=ssrg_finger_beam_material.duplicate() if ssrg else finger_beam_material
			beam.extra_cull_margin=SSRG_STAGE_DISTANCE if ssrg else 0.0
			beam.set_meta("layout",signature)
		if ssrg:
			var age=float(ssrg_beam_release.get(i,SsrgCurves.BEAM_RELEASE_SECONDS))
			if pressed.has(i):
				age=0.0;beam.position.x=ssrg_beam_center(pressed[i])
			else: age+=delta
			ssrg_beam_release[i]=age
			var alpha=SsrgCurves.beam_alpha(age) if game.mode=="play" and game.countdown<=0 else 0.0
			beam.material_override.set_shader_parameter("release_alpha",alpha)
			for parameter in ["tint","intensity"]: beam.material_override.set_shader_parameter(parameter,ssrg_finger_beam_material.get_shader_parameter(parameter))
			beam.visible=alpha>0.0
			continue
		beam.visible=i<touches.size()
		if beam.visible:
			var lane=SynkCapture.lane(touches[i].position.x)
			beam.position.x=ssrg_beam_center(ssrg_beam_lane(lane)) if ssrg else clampf(lane_world_x(roundf(lane)),-BEAM_MAX_X,BEAM_MAX_X)

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
	if source_long_visuals():
		set_trail_clip(notes[key].node,1000.0)
		for mesh in notes[key].node.get_children():
			if not mesh is GeometryInstance3D: continue
			var mat=own_material(mesh)
			if mat is ShaderMaterial:
				var successful_head=mesh.get_meta("ssrg_long_start",false) and notes[key].get("head_hit",false)
				mat.set_shader_parameter("source_tint",Color.WHITE if successful_head else SsrgNotes.MISSED_TINT)
				mat.set_shader_parameter("desaturate",0.0);mat.set_shader_parameter("ghost_fade",1.0)
		return
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
	if game.uses_ssrg_gameplay():
		if miss_shake_remaining<=0:miss_shake_remaining=.3
	else:miss_shake_remaining = .22

func animate_miss_shake(delta: float) -> void:
	if game.mode=="paused": return
	if game.uses_ssrg_gameplay():
		if game.mode!="play" or game.countdown>0 or (game.stage_intro and game.stage_intro.running()):miss_shake_remaining=0
		if miss_shake_remaining>0:
			ssrg_shake_x=(1.0 if ssrg_shake_x<0 else -1.0)*20.0*SSRG_UNIT*(miss_shake_remaining/.3)
			miss_shake_remaining=maxf(0,miss_shake_remaining-delta)
		else:ssrg_shake_x=0
		apply_camera(Vector3(-ssrg_shake_x,0,0));return
	ssrg_shake_x=0
	if game.mode!="play" or (game.stage_intro and game.stage_intro.running()): miss_shake_remaining=0
	miss_shake_remaining=maxf(0,miss_shake_remaining-delta)
	var strength=miss_shake_remaining/.22
	var phase=(.22-miss_shake_remaining)*90.0
	# The loading card fades away over a stationary highway. No entrance zoom.
	apply_camera(Vector3(sin(phase)*.065,sin(phase*1.3)*.025,0)*strength)

# A completed hold or slide is judged slightly before its tail is drawn at the line (early
# release, and the render clock trails the judgment clock), so keep drawing it until then.
func finishing_sustain(entry: Dictionary) -> bool:
	return entry.done and entry.started and entry.note.kind in ["hold","slide"] and not entry.has("missed_at") and render_time()<float(entry.note.time)+float(entry.note.duration)

# A missed sustain remains visible until its tail exits, even after judgment retires it.
func first_visible_play_index() -> int:
	while play_render_cursor<game.live.size():
		var entry: Dictionary=game.live[play_render_cursor]
		if not entry.done: break
		if entry.note.kind in ["hold","slide"] and entry.has("missed_at"):
			if (render_time()-float(entry.note.time)-float(entry.note.duration))*travel_speed()<=5: break
		if finishing_sustain(entry): break
		play_render_cursor+=1
	return play_render_cursor

var shown_keys: Dictionary = {}
var ssrg_animation_frame=-1
func animate_ssrg_notes() -> void:
	if not source_long_visuals(): ssrg_animation_frame=-1;return
	var beat=fposmod((render_time()-game.chart_offset())*game.chart_bpm()/60.0,1.0)
	var frame=SsrgNotes.frame_index(beat)
	if frame==ssrg_animation_frame: return
	ssrg_animation_frame=frame
	var alive: Array = []
	for ref in ssrg_note_materials:
		var mat=ref.get_ref()
		if mat==null: continue
		alive.append(ref)
		if mat.has_meta("ssrg_special") and game.ssrg_presentation:
			mat.set_shader_parameter("artwork",game.ssrg_presentation.special_art(int(mat.get_meta("ssrg_special")),int(mat.get_meta("ssrg_item",0)),beat))
		elif mat.has_meta("ssrg_palette"):
			var palette=int(mat.get_meta("ssrg_palette"))
			mat.set_shader_parameter("artwork",ssrg_cap_artwork(palette,bool(mat.get_meta("ssrg_tail")),beat,bool(mat.get_meta("ssrg_old_ui",false))))
	ssrg_note_materials=alive

# Lights the recorder's channel under each finger that is drawing a note, then fades it.
func update_recorder_channels(delta: float, recording_now: bool) -> void:
	if recorder_channels == null: return
	recorder_channels.visible = recording_now
	if lane_markers: lane_markers.visible = not recording_now
	if not recording_now: return
	if recorder_lit.size() != SynkChart.LANES: recorder_lit.resize(SynkChart.LANES)
	var held: Dictionary = {}
	if game.capture:
		for g in game.capture.gestures.values():
			var lane = clampf(SynkCapture.lane(g.position.x)+float(g.get("lane_shift",0)),0,SynkChart.MAX_LANE)
			held[roundi(lane*12.0/SynkChart.MAX_LANE)] = true
	if game.get("flash") != null and float(game.flash) > .6 and game.get("flash_lane") != null:
		held[clampi(int(game.flash_lane),0,12)] = true
	for i in SynkChart.LANES:
		recorder_lit[i] = 1.0 if held.has(i) else maxf(0.0, recorder_lit[i]-delta*4.0)
	recorder_channel_material.set_shader_parameter("lit",recorder_lit)

func _process(delta: float) -> void:
	if game==null: return
	step_prebuild()
	if rail_atmosphere:
		if uses_projected_highway(): rail_atmosphere.visible = false
		else: rail_atmosphere.update(delta)
	var in_play = game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play")
	var recording_now = game.mode=="record" or (game.mode=="paused" and game.paused_mode=="record")
	recorder_guides.visible = recording_now or (in_play and bool(extras_setting("lane_hints", true)) and not (ssrg_theme and ssrg_theme.active) and not (concept_theme and concept_theme.active))
	if guide_material: guide_material.set_shader_parameter("color",Color(Color("f4f1ea"),.10) if recording_now else Color(Color("777bd5"),.3))
	update_recorder_channels(delta,recording_now)
	update_play_aids(delta)
	update_multiplier_wave(delta)
	animate_miss_shake(delta)
	update_cover_backdrop()
	laser_streaks.update()
	animate_effects(delta)
	var visible_keys = {}
	for beam in active_beams: beam.visible = false
	update_finger_beams(delta)
	if (game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play")) and game.countdown<=0:
		for i in range(first_visible_play_index(),game.live.size()):
			if game.live[i].note.time>render_time()+game.note_travel_seconds(): break
			if not game.live[i].done:
				var held = game.live[i].started and game.live[i].note.kind in ["hold","slide"]
				sync_note(game.live[i].key,game.live[i].note,visible_keys,false,-1.0,held)
				if game.live[i].started and game.live[i].note.kind=="slide" and not game.uses_ssrg_gameplay():
					var lane = SynkChart.lane_at(game.live[i].note,render_time())
					var beam = active_beams[clampi(roundi(lane),0,SynkChart.MAX_LANE)]
					beam.position=touch_hit_position(lane,int(game.live[i].pointer))+Vector3(0,.045,0); beam.visible = true
					var pulse = .5+.5*sin(animation_time*TAU*3.0)
					beam.get_child(0).scale = Vector3(1+pulse*.12,.9+pulse*.25,1)
					beam.get_child(0).material_override.set_shader_parameter("opacity",.45+pulse*.3)
			elif finishing_sustain(game.live[i]):
				sync_note(game.live[i].key,game.live[i].note,visible_keys,false,-1.0,true)
			elif game.live[i].note.kind in ["hold","slide"] and game.live[i].has("missed_at"):
				# A missed hold or slide turns gray and keeps travelling down the highway until it leaves.
				var key: String=game.live[i].key
				sync_note(key,game.live[i].note,visible_keys)
				if notes.has(key) and visible_keys.has(key):
					fade_missed_slide(key,maxf(0,game.song_time-float(game.live[i].missed_at)),false)
	animate_ssrg_notes()
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
