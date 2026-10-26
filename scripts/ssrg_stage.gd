extends Node3D
var receptors: Array = []
var press: MeshInstance3D
var rails: Array = []
func _init() -> void :
	name = "SSRGStage"
	# Continue beneath the judgment line and beyond the camera's lower edge.
	var floor_node=MeshInstance3D.new(); var floor_mesh=PlaneMesh.new()
	floor_mesh.size=Vector2(19.5,72.0); floor_node.mesh=floor_mesh
	floor_node.position=Vector3(0,.026,-24.0)
	var floor_mat=ShaderMaterial.new(); floor_mat.shader=preload("res://scripts/ssrg_floor.gdshader")
	floor_mat.set_shader_parameter("opacity",.32); floor_mat.render_priority=-7
	floor_node.material_override=floor_mat; add_child(floor_node)
	for side in [-1, 1]:
		var rail = MeshInstance3D.new(); var plane = PlaneMesh.new()
		plane.size = Vector2(0.55, 72.0);rail.mesh = plane
		rail.position = Vector3(side * 9.75, 0.09, -24.0)
		var mat = ShaderMaterial.new();mat.shader = preload("res://scripts/ssrg_stage.gdshader")
		mat.set_shader_parameter("artwork", preload("res://assets/ssrg/rail.png"))
		mat.set_shader_parameter("tint", Color("fff9e7"))
		rail.material_override = mat;rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(rail);rails.append(rail)
	press = MeshInstance3D.new(); var plane = PlaneMesh.new();plane.size = Vector2(19.5, 2.0);press.mesh = plane
	press.position = Vector3(0, 0.035, - 0.15)
	var mat = ShaderMaterial.new();mat.shader = preload("res://scripts/ssrg_press.gdshader")
	mat.render_priority = -3
	press.material_override = mat;press.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(press)
	for lane in 13:
		var ring = MeshInstance3D.new(); var disc = QuadMesh.new();disc.size = Vector2(212.0, 116.0)*9.75/512.0   # SSRG guide sprite size;ring.mesh = disc
		ring.name = "Receptor" + str(receptors.size() + 1);ring.position = Vector3(0, 0.2, 0);ring.visible = false
		var material = ShaderMaterial.new();material.shader = preload("res://scripts/ssrg_receptor.gdshader")
		material.render_priority = -2
		ring.material_override = material;ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring);receptors.append(ring)


# SSRG's bottom bar is 130 of 640 screen units tall, centred 250 units below the middle
# (79% to 99% down the screen). Cover that same screen band on the floor, whatever the view.
const BAND_TOP = .5 + 185.0/640.0
const BAND_BOTTOM = .5 + 315.0/640.0
func fit_band(world: Node3D) -> void:
	var camera: Camera3D = world.camera
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var floor_plane = Plane(Vector3.UP, .035)
	var ends: Array = []
	for fraction in [BAND_TOP, BAND_BOTTOM]:
		var point = Vector2(size.x*.5, size.y*fraction)
		var hit = floor_plane.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
		if hit == null: return
		ends.append(hit.z)
	(press.mesh as PlaneMesh).size = Vector2(19.5, maxf(.5, ends[1]-ends[0]))
	press.position.z = (ends[0]+ends[1])*.5

func update(world: Node3D) -> void :
	if not visible: return
	fit_band(world)
	for receptor in receptors: receptor.hide()
	var game = world.game
	if not (game.mode == "play" or (game.mode == "paused" and game.paused_mode == "play")): return
	var now: float = world.render_time()
	var travel: float = game.note_travel_seconds()
	var targets: Dictionary = {}
	var indexed = false
	var candidates: Variant = range(game.first_live_index(), game.live.size())
	for index in candidates:
		var entry: Dictionary = game.live[index]
		if entry.done: continue
		var note: Dictionary = entry.note
		if float(note.time) > now + travel:
			if not indexed: break
			continue
		var at = float(note.time)
		var span = travel
		var lane = float(note.lane)
		if entry.get("started", false):
			if note.kind not in ["hold", "slide"]: continue
			var checks: Array = note.get("checkpoints", [])
			var next = int(entry.get("checks_done", 0))
			at = float(note.time) + (float(checks[next]) if next < checks.size() else float(note.duration))
			var previous = float(note.time) + (float(checks[next - 1]) if next > 0 else 0.0)
			span = minf(travel, maxf(0.001, at - previous))
			lane = SynkChart.lane_at(note, at)
		if at - now > span: continue
		var slot = clampi(roundi(lane / float(SynkChart.MAX_LANE) * (game.ssrg_lane_count-1)), 0, game.ssrg_lane_count-1)
		if targets.has(slot) and targets[slot].at <= at: continue
		targets[slot] = {"at": at, "lane": lane, "progress": clampf(1.0 - (at - now) / span, 0.0, 1.0)}
	for slot in targets:
		var target: Dictionary = targets[slot]
		var receptor: MeshInstance3D = receptors[slot]
		receptor.position.x = world.note_x(target.lane)
		receptor.rotation = world.camera.rotation
		receptor.material_override.set_shader_parameter("progress", target.progress)
		receptor.show()

func warmup(world: Node3D) -> void :
	if not visible: return
	var receptor: MeshInstance3D = receptors[0]
	receptor.position.x = 0;receptor.rotation = world.camera.rotation
	receptor.material_override.set_shader_parameter("progress", 1.0);receptor.show()

func configure(world: Node3D) -> void :
	var stock_road = true
	press.visible = stock_road
	var band = Color("c7a520")

	var stock_band = Color("c7a520")
	var tint = Color(0.58, 0.45, 0.12) if band.is_equal_approx(stock_band) else band
	press.material_override.set_shader_parameter("base_color", tint)
	var rail_tint = world.custom_color("rail_color")
	if rail_tint == null: rail_tint = band.lerp(Color.WHITE, 0.55)
	for rail in rails:
		rail.visible = stock_road
		rail.material_override.set_shader_parameter("tint", rail_tint)
