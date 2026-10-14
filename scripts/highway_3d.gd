extends Node3D

# All note positions are in world units. Camera perspective supplies the depth.
const LANE_WIDTH = 1.50
const TRACK_LENGTH = 60.0
# Palette indices represent note types: tap, sustained (hold/slide), flick.
const COLORS = [Color("38baff"), Color("a36aff"), Color("ffd447")]
var game: Control
var camera: Camera3D
var notes: Dictionary = {}
var note_meshes: Array = []
var materials: Array = []
var effects: Node3D
var recorder_guides: Node3D
var active_beams: Array = []
var animation_time = 0.0
var animated_materials: Array = []
var bursts: Array = []
var spark_mesh: SphereMesh
var miss_shake_remaining = 0.0
const CAMERA_POSITION = Vector3(0,10,10)

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

func lane_x(lane: float) -> float: return (lane-6.0)*LANE_WIDTH
func travel_speed() -> float: return TRACK_LENGTH / game.note_travel_seconds()
func render_time() -> float:
	return game.visual_song_time if game.audio.playing and game.mode in ["play","record"] and game.countdown<=0 and game.resume_countdown<=0 else game.song_time
func note_position(lane: float, chart_time: float) -> Vector3:
	return Vector3(lane_x(lane), .13, (render_time()-chart_time)*travel_speed())

func _ready() -> void:
	camera = Camera3D.new(); add_child(camera); camera.current = true
	camera.position = CAMERA_POSITION; camera.rotation_degrees.x = -28.0
	camera.fov = 45; camera.near = .1; camera.far = 180
	var environment = WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("06091e")
	var sky_shader = Shader.new()
	sky_shader.code = """shader_type sky;
	float star_hash(vec2 cell) {
		return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	}
	void sky() {
		float horizon = exp(-abs(EYEDIR.y + 0.08) * 5.0);
		vec3 color = mix(vec3(0.014, 0.016, 0.06), vec3(0.13, 0.045, 0.22), horizon);
		float drift = EYEDIR.x * 11.0 + TIME * 0.13;
		float aurora = sin(drift + sin(EYEDIR.y * 13.0 + TIME * 0.08) * 1.5);
		aurora = pow(max(aurora, 0.0), 4.0) * exp(-abs(EYEDIR.y - 0.05) * 4.0);
		color += vec3(0.07, 0.04, 0.15) * aurora;
		vec2 star_cell = floor(vec2(EYEDIR.x, EYEDIR.y) * 145.0);
		vec2 star_center = fract(vec2(EYEDIR.x, EYEDIR.y) * 145.0) - 0.5;
		float star = step(0.997, star_hash(star_cell)) * exp(-dot(star_center, star_center) * 80.0);
		float twinkle = 0.62 + 0.38 * sin(TIME * 1.7 + star_hash(star_cell + 9.0) * 6.283);
		color += vec3(0.11, 0.10, 0.20) * star * twinkle;
		COLOR = color;
	}"""
	var sky_material = ShaderMaterial.new(); sky_material.shader = sky_shader
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

func build_track() -> void:
	box(self,Vector3(0,-.15,-28),Vector3(19.65,.25,64),material(Color("080b25")))
	var surface = PlaneMesh.new(); surface.size = Vector2(19.50,60)
	var rail = mesh_node(surface,self,material(Color("0b1030"))); rail.position = Vector3(0,.008,-30)
	# Recording-only guides make lane targets readable without adding lines to gameplay.
	recorder_guides = Node3D.new(); recorder_guides.name = "RecorderGuides"; add_child(recorder_guides)
	var guide_material = material(Color("777bd5"),.38)
	for boundary in range(1,13):
		var guide_mesh = PlaneMesh.new(); guide_mesh.size = Vector2(.035,60)
		var guide = mesh_node(guide_mesh,recorder_guides,guide_material)
		guide.position = Vector3((boundary-6.5)*LANE_WIDTH,.048,-30)
	var marker_material = material(Color("8be8ff"),.72)
	for lane in 13:
		var marker_mesh = PlaneMesh.new(); marker_mesh.size = Vector2(.22,.62)
		var marker = mesh_node(marker_mesh,recorder_guides,marker_material)
		marker.position = Vector3(lane_x(lane),.052,-.03)
	recorder_guides.visible = false
	for side in [-1,1]:
		var edge_mesh = PlaneMesh.new(); edge_mesh.size = Vector2(.28,64)
		var edge_material = ShaderMaterial.new(); edge_material.shader = preload("res://scripts/rail_edge.gdshader")
		edge_material.set_shader_parameter("tint",COLORS[1] if side==1 else COLORS[0])
		animated_materials.append(weakref(edge_material))
		var edge = mesh_node(edge_mesh,self,edge_material)
		edge.position = Vector3(side*9.72,.035,-28)
	# Match the visible note face, excluding the texture's surrounding glow.
	var judgment_mesh = QuadMesh.new(); judgment_mesh.size = Vector2(19.50,1.0)
	var judgment_material = ShaderMaterial.new(); judgment_material.shader = preload("res://scripts/judgment_bar.gdshader")
	animated_materials.append(weakref(judgment_material))
	var judgment_bar = mesh_node(judgment_mesh,self,judgment_material)
	judgment_bar.position = Vector3(0,.035,0); judgment_bar.rotation_degrees.x = -90
	for edge in [-1,1]:
		var edge_mesh = QuadMesh.new(); edge_mesh.size = Vector2(19.50,.025)
		var border = mesh_node(edge_mesh,judgment_bar,material(Color("ead6ff")))
		border.position = Vector3(0,edge*.5,.005)

func build_effects() -> void:
	spark_mesh = SphereMesh.new(); spark_mesh.radius = .065; spark_mesh.height = .13
	for lane in 13:
		var beam = Node3D.new(); add_child(beam); beam.position = Vector3(lane_x(lane),.08,0)
		artwork(beam,"Hit_Effect_Pink",1,Vector3(0,1.35,0),Vector2(4.4,3.3),Vector4(0,0,1,1),.75)
		beam.visible = false; active_beams.append(beam)

func asset_material(name: String, palette: int, region = Vector4(0,0,1,1), opacity = 1.0) -> ShaderMaterial:
	var mat = ShaderMaterial.new(); mat.shader = load("res://scripts/neon_asset.gdshader")
	mat.set_shader_parameter("artwork",load("res://assets/neon/"+name+".png"))
	mat.set_shader_parameter("region",region); mat.set_shader_parameter("opacity",opacity)
	# Blue tap artwork keeps its gradient; sustained and flick art takes its type color.
	mat.set_shader_parameter("recolor",palette!=0); mat.set_shader_parameter("tint",COLORS[palette])
	mat.set_shader_parameter("motion",.7 if name.begins_with("Hold_") else (.35 if name.begins_with("Flick_") else .12))
	if name.begins_with("Tap_") or name.begins_with("Hold_") or name.begins_with("Flick_") or name.begins_with("Slide_"):
		mat.set_shader_parameter("glow_pulse",.18)
	animated_materials.append(weakref(mat))
	return mat

func spawn_hit(lane: float, kind: String, direction: int = 0, sustain_entry: Dictionary = {}) -> void:
	if bursts.size() >= 32:
		bursts.pop_front().node.queue_free()
	var palette = palette_for_kind(kind)
	var node = Node3D.new(); add_child(node); node.position = Vector3(lane_x(lane),.1,0)
	var flash: MeshInstance3D
	if kind=="flick":
		var slash_mesh = QuadMesh.new(); slash_mesh.size = Vector2(2.8,4.6)
		var slash_material = ShaderMaterial.new(); slash_material.shader = preload("res://scripts/flick_hit.gdshader")
		slash_material.set_shader_parameter("tint",COLORS[palette])
		flash = mesh_node(slash_mesh,node,slash_material)
		flash.position = Vector3(0,2.25,0); flash.rotation = camera.rotation
	else:
		flash = artwork(node,"Hit_Effect_Blue" if palette==0 else "Hit_Effect_Pink",palette,Vector3(0,2.25,0),Vector2(5.8,4.0))
	var fill_mesh = QuadMesh.new(); fill_mesh.size = Vector2(4.9,3.5)
	var fill_material = ShaderMaterial.new(); fill_material.shader = preload("res://scripts/hit_fill.gdshader")
	fill_material.set_shader_parameter("tint",COLORS[palette])
	var fill = mesh_node(fill_mesh,node,fill_material)
	fill.position = Vector3(0,2.25,0); fill.rotation = camera.rotation
	var flick_axis = camera.basis * [Vector3.UP,Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT][clampi(direction,0,3)]
	if kind=="flick": flash.rotate_object_local(Vector3.FORWARD,float(direction)*PI*.5)
	var ring_mesh = TorusMesh.new(); ring_mesh.inner_radius=.9; ring_mesh.outer_radius=.97; ring_mesh.rings=32; ring_mesh.ring_segments=6
	var ring = mesh_node(ring_mesh,node,material(COLORS[palette],.8))
	ring.visible = kind!="flick"
	var particles: Array = []
	for i in 12:
		var particle=mesh_node(spark_mesh,node,materials[palette])
		var angle=i*TAU/12.0
		var velocity=Vector3(cos(angle)*3.5,3.0+float(i%4)*.9,sin(angle)*1.4-.8)
		if kind=="flick":
			var sideways = camera.basis * [Vector3.RIGHT,Vector3.DOWN,Vector3.LEFT,Vector3.UP][clampi(direction,0,3)]
			velocity = flick_axis*(5.0+float(i%4)*.8)+sideways*sin(angle)*1.4
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
		var fade = pow(1.0-t,2)
		var attack = minf(1.0,burst.age/.035)
		var hold_wave = .5+.5*sin(animation_time*TAU*2.8)
		var hold_blend = smoothstep(0.0,.18,burst.age) if sustained else 0.0
		burst.flash.material_override.set_shader_parameter("opacity",lerpf(attack*fade,.60+hold_wave*.26,hold_blend))
		burst.fill.material_override.set_shader_parameter("opacity",lerpf(attack*fade*(.8 if burst.kind=="flick" else 1.0),.55+hold_wave*.22,hold_blend))
		burst.fill.scale = Vector3(1.0+t*.7,1.0+t*.35,1).lerp(Vector3(1.18+hold_wave*.15,1.05+hold_wave*.14,1),hold_blend)
		burst.flash.scale = Vector3(1.0+t*.6,1.0+t*(1.3 if burst.kind=="flick" else .25),1).lerp(Vector3(1.14+hold_wave*.12,1.0+hold_wave*.12,1),hold_blend)
		if burst.kind=="flick":
			burst.flash.material_override.set_shader_parameter("progress",t)
			burst.flash.scale = Vector3(1.0-t*.45,.65+sin(minf(t*2.0,1.0)*PI*.5)*.65,1)
			burst.flash.position = Vector3(0,2.25,0)+burst.flick_axis*(1.0-pow(1.0-t,2))*2.2
			burst.fill.position = burst.flash.position
		burst.ring.scale = Vector3.ONE*lerpf(.8+t*.75,1.12+hold_wave*.22,hold_blend)
		burst.ring.material_override.albedo_color.a = lerpf(fade*.8,.15+hold_wave*.25,hold_blend)
		for particle in burst.particles:
			particle.node.position = particle.velocity*burst.age
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

func make_cap(parent: Node3D, lane: float, offset: float, palette: int, recording = false) -> void:
	var position_value = Vector3(lane_x(lane),.2,offset*travel_speed()*(1 if recording else -1))
	artwork(parent,"Tap_Note_Blue" if palette==0 else "Tap_Note_Pink",palette,position_value,Vector2(3.1,1.25))

func make_flick(parent: Node3D, note: Dictionary, palette: int) -> void:
	make_cap(parent,float(note.lane),0,palette)
	var arrow = artwork(parent,"Flick_Up_Pink",palette,Vector3(lane_x(note.lane),.48,.08),Vector2(1.8,1.15),Vector4(0,0,1,.96))
	arrow.material_override.set_shader_parameter("recolor",palette!=0)
	arrow.rotate_object_local(Vector3.FORWARD,float(note.direction)*PI*.5)

func make_ribbon(parent: Node3D, note: Dictionary, palette: int, recording = false) -> void:
	var duration = float(note.duration)
	var count = clampi(ceili(duration*32),16,256)
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge = SurfaceTool.new(); edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var t0 = duration*i/count; var t1 = duration*(i+1)/count
		var a = Vector3(lane_x(SynkChart.lane_at(note,note.time+t0)),.09,-t0*travel_speed())
		var b = Vector3(lane_x(SynkChart.lane_at(note,note.time+t1)),.09,-t1*travel_speed())
		if recording: a.z=-a.z; b.z=-b.z
		for index in [0,1,2,0,2,3]:
			st.set_uv([Vector2(0,float(i)/count),Vector2(0,float(i+1)/count),Vector2(1,float(i+1)/count),Vector2(1,float(i)/count)][index])
			st.add_vertex([a+Vector3(-.8,0,0),b+Vector3(-.8,0,0),b+Vector3(.8,0,0),a+Vector3(.8,0,0)][index])
		for side in [-1,1]:
			for index in [0,1,2,0,2,3]:
				edge.add_vertex([a+Vector3(side*.8-.012,.01,0),b+Vector3(side*.8-.012,.01,0),b+Vector3(side*.8+.012,.01,0),a+Vector3(side*.8+.012,.01,0)][index])
	st.set_material(asset_material("Hold_Note_Pink",palette,Vector4(.12,.27,.53,.43),.85)); mesh_node(st.commit(),parent)
	edge.set_material(material(COLORS[palette].lightened(.4))); mesh_node(edge.commit(),parent)
	make_cap(parent,SynkChart.lane_at(note,note.time+duration),duration,palette,recording)

func sync_note(key: String, note: Dictionary, visible_keys: Dictionary, recording = false, freeze_time: float = -1.0) -> void:
	var tail = float(note.time)+float(note.duration)
	var visible_time=freeze_time if freeze_time>=0 else render_time()
	if freeze_time<0:
		if recording:
			if note.time>visible_time or visible_time-tail>game.note_travel_seconds(): return
		elif note.time-visible_time > game.note_travel_seconds() or (visible_time-tail)*travel_speed()>5: return
	visible_keys[key] = true
	var signature = hash(note)^hash(game.note_speed)
	if notes.has(key) and notes[key].signature != signature:
		notes[key].node.queue_free(); notes.erase(key)
	if not notes.has(key):
		var node = Node3D.new(); add_child(node)
		var palette = palette_for_kind(str(note.kind))
		if note.kind=="flick": make_flick(node,note,palette)
		else: make_cap(node,float(note.lane),0,palette,recording)
		if note.kind in ["hold","slide"]: make_ribbon(node,note,palette,recording)
		notes[key] = {"node":node,"signature":signature}
	notes[key].node.position.z = (visible_time-float(note.time))*travel_speed()
	if recording: notes[key].node.position.z *= -1

func fade_missed_slide(key: String, age: float) -> void:
	var gray=clampf(age/.16,0,1)
	var fade=1.0-smoothstep(.40,.9,age)
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

func shake_on_miss() -> void:
	# Repeated misses refresh the short shake without increasing its strength.
	miss_shake_remaining = .22

func animate_miss_shake(delta: float) -> void:
	if game.mode=="paused": return
	if game.mode!="play": miss_shake_remaining=0
	miss_shake_remaining=maxf(0,miss_shake_remaining-delta)
	var strength=miss_shake_remaining/.22
	var phase=(.22-miss_shake_remaining)*90.0
	camera.position=CAMERA_POSITION+Vector3(sin(phase)*.065,sin(phase*1.3)*.025,0)*strength

func _process(delta: float) -> void:
	if game==null: return
	recorder_guides.visible = game.mode=="record" or (game.mode=="paused" and game.paused_mode=="record")
	animate_miss_shake(delta)
	animate_effects(delta)
	var visible_keys = {}
	for beam in active_beams: beam.visible = false
	if game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play"):
		for i in game.live.size():
			if game.live[i].note.time>render_time()+game.note_travel_seconds(): break
			if not game.live[i].done:
				sync_note("play"+str(i),game.live[i].note,visible_keys)
				if game.live[i].started and game.live[i].note.kind=="slide":
					var lane = SynkChart.lane_at(game.live[i].note,render_time())
					var beam = active_beams[clampi(roundi(lane),0,12)]
					beam.position.x = lane_x(lane); beam.visible = true
					var pulse = .5+.5*sin(animation_time*TAU*3.0)
					beam.get_child(0).scale = Vector3(1+pulse*.12,.9+pulse*.25,1)
					beam.get_child(0).material_override.set_shader_parameter("opacity",.45+pulse*.3)
			elif game.live[i].note.kind=="slide" and game.live[i].has("missed_at"):
				var age=maxf(0,game.song_time-float(game.live[i].missed_at))
				if age<.9:
					var key="play"+str(i)
					sync_note(key,game.live[i].note,visible_keys,false,float(game.live[i].missed_visual_time))
					fade_missed_slide(key,age)
	if game.mode=="record" or (game.mode=="paused" and game.paused_mode=="record"):
		if game.overdub:
			for i in game.document.notes.size(): sync_note("record"+str(i),game.document.notes[i],visible_keys,true)
		for i in game.capture.notes.size(): sync_note("captured"+str(i),game.capture.notes[i],visible_keys,true)
		for id in game.capture.gestures: sync_note("gesture"+str(id),game.capture.gestures[id].note,visible_keys,true)
	for key in notes.keys():
		if not visible_keys.has(key): notes[key].node.queue_free(); notes.erase(key)
