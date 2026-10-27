extends Node3D
var receptors: Array = []
var press: MeshInstance3D
var rails: Array = []
const TRACK_REACH = 1500.0
func _init() -> void :
	name = "SSRGStage"
	# Direct original UI canvas: world Z = -(UI y + 234) * UNIT.
	const UNIT = 9.75/512.0
	for side in [-1,1]:
		# Original BottomRight-pivot sprite at (0,-320), mirrored on the right.
		var rail=MeshInstance3D.new(); var quad=QuadMesh.new()
		quad.size=Vector2(720,578)*UNIT; rail.mesh=quad
		rail.position=Vector3(side*360*UNIT,.09,-203*UNIT)
		rail.rotation_degrees.x=-90
		if side>0: rail.scale.x=-1
		var mat=ShaderMaterial.new(); mat.shader=preload("res://scripts/ssrg_stage.gdshader")
		mat.render_priority=-7
		mat.set_shader_parameter("artwork",preload("res://assets/ssrg/imported/rail_original.png"))
		mat.set_shader_parameter("along_rail",false)
		rail.material_override=mat; add_child(rail); rails.append(rail)
	press=MeshInstance3D.new(); var plane=PlaneMesh.new()
	plane.size=Vector2(1156,130)*UNIT; press.mesh=plane
	press.position=Vector3(-5*UNIT,.035,16*UNIT)
	var mat=ShaderMaterial.new(); mat.shader=preload("res://scripts/ssrg_press.gdshader")
	mat.set_shader_parameter("base_color",Color(.08,.08,.09)); mat.render_priority=-8
	press.material_override=mat; add_child(press)
	for lane in 13:
		var ring = MeshInstance3D.new(); var disc = QuadMesh.new();disc.size = Vector2(212.0, 116.0)*9.75/512.0   # SSRG guide sprite size
		ring.mesh = disc
		ring.name = "Receptor" + str(receptors.size() + 1);ring.position = Vector3(0, 0.2, 0);ring.visible = false
		var material = ShaderMaterial.new();material.shader = preload("res://scripts/ssrg_receptor.gdshader")
		material.set_shader_parameter("artwork",preload("res://assets/ssrg/imported/guide_original.png"))
		material.render_priority = -5
		ring.material_override = material;ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring);receptors.append(ring)


# SSRG's bottom bar is 130 of 640 screen units tall, centred 250 units below the middle
# (79% to 99% down the screen). Cover that same screen band on the floor, whatever the view.
const BAND_TOP = .5 + 185.0/640.0
const BAND_BOTTOM = .5 + 315.0/640.0
func update(world: Node3D) -> void :
	if not visible: return
	for receptor in receptors: receptor.hide()
	var game = world.game
	if game.countdown>0 or not (game.mode == "play" or (game.mode == "paused" and game.paused_mode == "play")): return
	var now: float = world.render_time()
	var travel: float = game.note_travel_seconds()
	# Original RenderNoteGuide: fade starts at projected q=.3 and is complete
	# by q=.8. Sprite padding, not an offset hit line, places the visible ellipse.
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
		if entry.get("started", false): continue
		var at = float(note.time)
		var lane = float(note.lane)
		# Where the note is drawn: progress p from the vanishing point (0) to the line (1).
		var p: float = world.ssrg_approach(-(at-now)/travel*world.TRACK_LENGTH)
		if p < .3 or p > 1.0: continue
		var slot = clampi(roundi(lane / float(SynkChart.MAX_LANE) * (game.gameplay_lane_count()-1)), 0, game.gameplay_lane_count()-1)
		if targets.has(slot) and targets[slot].at <= at: continue
		targets[slot] = {"at": at, "lane": lane, "progress": clampf(2.0*(minf(p,.8)-.3),0.0,1.0)}
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
	# SSRG colours: a dark grey glass judgement bar and white-silver rails (a rail colour picked
	# in Settings still wins).
	press.material_override.set_shader_parameter("base_color", Color(0.16, 0.17, 0.21))
	var rail_tint = world.custom_color("rail_color")
	if rail_tint == null: rail_tint = Color.WHITE
	for rail in rails:
		rail.visible = stock_road
		rail.material_override.set_shader_parameter("tint", rail_tint)
		rail.material_override.set_shader_parameter("floor_opacity",clampf(float(world.game.highway_opacity),.3,1.6))
		rail.material_override.set_shader_parameter("floor_tint",world.element_color("track",Color.BLACK))
