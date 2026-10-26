extends Node3D
# SSRG highway style (Settings > Highway style > SSRG): a Superstar-inspired stage drawn with
# SYNK's own art (assets/ssrg, made by tools/ssrg_art/generate.py).
#   - the song's photo at full brightness behind a see-through track with solid white rails
#   - grey target rings on the chart's lanes that turn white as a note arrives
#   - a thin light line up each lane while a finger holds it
#   - hit effects played from an 11-frame flash sheet (gold star sheet on PERFECT)
# Only in play; the recorder keeps its own look.
const HIT_LIFE = .42
const LOOKAHEAD = .55
var world: Node3D
var floor_node: MeshInstance3D
var band: MeshInstance3D
# Lanes the current chart uses (rings show only there); rebuilt when a new run starts.
var used_lanes: Dictionary = {}
var used_for_size = -1
var rings: Array = []
var ring_materials: Array = []
var press_lines: Array = []
var hit_pool: Array = []
var hits: Array = []
var active = false
var original_stage: Node3D
var imported_frames: Array[Texture2D] = []

func _ready() -> void:
	for index in range(1,12):
		var path="res://assets/ssrg/imported/Effect_A_%02d.png" % index
		if ResourceLoader.exists(path): imported_frames.append(load(path))
	original_stage=preload("res://scripts/ssrg_stage.gd").new(); add_child(original_stage)
	var w = world
	var half = w.FRAME_HALF_WIDTH
	floor_node = shaded_plane(Vector2(half * 2.0, 62.0), preload("res://scripts/ssrg_floor.gdshader"), Vector3(0, .026, -30.5), -7)
	floor_node.material_override.set_shader_parameter("opacity", .32)
	for side in [-1, 1]:
		var rail = shaded_plane(Vector2(.95, 64.0), preload("res://scripts/ssrg_rail.gdshader"), Vector3(side * (half + .35), .08, -31.0), 2)
		if side > 0: rail.rotation_degrees.y = 180
	var band_mesh = QuadMesh.new(); band_mesh.size = Vector2(half * 2.0 + 1.2, w.JUDGMENT_DEPTH * 1.25)
	var band_mat = ShaderMaterial.new(); band_mat.shader = preload("res://scripts/reference_note.gdshader")
	band_mat.set_shader_parameter("artwork", preload("res://assets/ssrg/judgment.png")); band_mat.render_priority = -5
	band = w.mesh_node(band_mesh, self, band_mat); band.position = Vector3(0, .04, 0); band.rotation_degrees.x = -90
	band.visible = false   # the reference stage has no band; the rings mark the line
	for lane in SynkChart.LANES:
		var ring_mesh = QuadMesh.new(); ring_mesh.size = Vector2(w.LANE_WIDTH * 1.6, w.LANE_WIDTH * 1.6)
		var ring_mat = ShaderMaterial.new(); ring_mat.shader = preload("res://scripts/ssrg_ring.gdshader"); ring_mat.render_priority = 3
		var ring = w.mesh_node(ring_mesh, self, ring_mat)
		ring.position = Vector3(w.lane_x(lane), .06, 0); ring.rotation_degrees.x = -90
		ring.scale = Vector3(1, .55, 1)   # flattened onto the floor
		rings.append(ring); ring_materials.append(ring_mat)
	for i in 10:
		var line = shaded_plane(Vector2(.5, 60.0), preload("res://scripts/ssrg_line.gdshader"), Vector3(0, .055, -30.0), 2)
		line.material_override.set_shader_parameter("tint", Color(.75, .9, 1.0)); line.material_override.set_shader_parameter("strength", .7)
		line.visible = false; press_lines.append(line)
	refresh()

func shaded_plane(size: Vector2, shader: Shader, at: Vector3, priority: int) -> MeshInstance3D:
	var mesh = PlaneMesh.new(); mesh.size = size
	var mat = ShaderMaterial.new(); mat.shader = shader; mat.render_priority = priority
	var node = world.mesh_node(mesh, self, mat); node.position = at
	return node

func refresh() -> void:
	active = world.game.ssrg_playable_run and not world.game.uses_recorder_colors()
	visible = active
	if original_stage:
		original_stage.configure(world)
		for child in get_children():
			if child != original_stage: child.visible=false
	if world.cover_material: world.cover_material.set_shader_parameter("photo", active)

# --- Hit effects ---------------------------------------------------------------------
func spawn(lane: float, kind: String, sustain_entry: Dictionary, pointer_id: int) -> void:
	if hits.size() >= 24: release(hits.pop_front())
	var h: Dictionary = hit_pool.pop_back() if not hit_pool.is_empty() else make_hit()
	var perfect = str(world.game.judgement) == "PERFECT"
	if not imported_frames.is_empty(): h.material.set_shader_parameter("atlas", imported_frames[0])
	h.age = 0.0; h.sustain_entry = sustain_entry; h.pointer_id = pointer_id; h.kind = kind
	# SSRG flashes sit on the note itself (not where the finger landed) and face the
	# current camera, which ANGLE/LENS may have changed since the pool was made.
	h.node.position = Vector3(world.note_x(lane), .9, 0)
	h.node.rotation = world.camera.rotation
	h.material.set_shader_parameter("opacity", 1.0)
	h.node.visible = true; hits.append(h)

func make_hit() -> Dictionary:
	var mesh = QuadMesh.new(); mesh.size = Vector2(9.0, 5.4)
	var mat = ShaderMaterial.new(); mat.shader = preload("res://scripts/ssrg_hit.gdshader"); mat.render_priority = 6
	var node = world.mesh_node(mesh, self, mat); node.rotation = world.camera.rotation; node.visible = false
	return {"node": node, "material": mat, "age": 0.0, "sustain_entry": {}, "pointer_id": -999, "kind": "tap"}

func release(h: Dictionary) -> void:
	h.node.visible = false; hit_pool.append(h)

func prefill(count: int = 16) -> void:
	while hit_pool.size() + hits.size() < count: hit_pool.append(make_hit())

func _process(delta: float) -> void:
	if not active: return
	original_stage.update(world)
	var game = world.game
	var playing = game.mode == "play"
	# Hits: play the sheet once; held notes loop the middle frames and follow the finger.
	for i in range(hits.size() - 1, -1, -1):
		var h: Dictionary = hits[i]
		var held = not h.sustain_entry.is_empty() and not h.sustain_entry.done
		if playing: h.age += delta
		if held and h.age > HIT_LIFE * .55: h.age = HIT_LIFE * .25
		if (not held and h.age >= HIT_LIFE) or game.mode not in ["play", "paused"]:
			hits.remove_at(i); release(h); continue
		if held: h.node.position.x = world.note_x(SynkChart.lane_at(h.sustain_entry.note, game.song_time))
		if not imported_frames.is_empty(): h.material.set_shader_parameter("atlas",imported_frames[mini(imported_frames.size()-1,int(h.age/HIT_LIFE*imported_frames.size()))])
	return
	if game.live.size() != used_for_size:
		used_for_size = game.live.size(); used_lanes.clear()
		for entry in game.live: used_lanes[clampi(roundi(float(entry.note.lane)), 0, SynkChart.MAX_LANE)] = true
	# Target rings: brighten on a lane as its next note approaches the line.
	var strengths: Array = []; strengths.resize(SynkChart.LANES); strengths.fill(0.0)
	if game.mode in ["play", "paused"]:
		var now = world.render_time()
		for index in range(game.first_live_index(), game.live.size()):
			var entry: Dictionary = game.live[index]
			var t = float(entry.note.time) - now
			if t > LOOKAHEAD: break
			if entry.done or entry.started or t < -.1: continue
			var lane = clampi(roundi(float(entry.note.lane)), 0, SynkChart.MAX_LANE)
			strengths[lane] = maxf(strengths[lane], clampf(1.0 - t / LOOKAHEAD, 0.0, 1.0))
	for lane in SynkChart.LANES:
		ring_materials[lane].set_shader_parameter("strength", float(strengths[lane]))
		rings[lane].visible = used_lanes.has(lane) or strengths[lane] > 0.0
		rings[lane].position.x = world.note_x(lane)
	# Press lines: one thin light up the lane under each finger.
	var touches: Array = game.pointers.values() if playing else []
	for i in press_lines.size():
		var line: MeshInstance3D = press_lines[i]
		line.visible = i < touches.size()
		if line.visible: line.position.x = world.lane_x(roundi(SynkCapture.lane(touches[i].position.x)))
