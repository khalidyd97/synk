extends Node3D
# Shared gameplay stage using the recovered SSRG artwork and 2D projection.
#   - the song's photo at full brightness behind a see-through track with solid white rails
#   - grey target rings on the chart's lanes that turn white as a note arrives
#   - a thin light line up each lane while a finger holds it
#   - ordinary hits use the original 11-frame A sequence at 33 frames per second
# Play and the recorder share this visual surface; the recorder still owns its
# capture, correction, take, and history behavior.
# Packaged NoteCoolbomb / NoteCoolbomb_Star: Current 0..11 at 33 frames/s.
# Frame 11 is the terminal hide boundary, not a twelfth image.
const HIT_FPS = 33.0
const HIT_LIFE = 11.0/HIT_FPS
const HOLD_RETRIGGER = HIT_LIFE*.3
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
# A flick's hit is the ordinary Effect_A flash, kept on the judgment bar like a tap, plus a
# spray of short spark streaks flung up and out from the bar so the impact reads as an
# explosive splash in the flick's up direction.
var flick_sparks: Array = []
const FLICK_SPARK_LIFE = .3   # the longest a spark lives; each one picks its own, shorter or equal
const FLICK_SPARK_COUNT = 26
const FLICK_SPARK_SHADER = preload("res://scripts/flick_spark.gdshader")
var active = false
var countdown_sweep_number = -1
var countdown_sweep_step = -1
var countdown_sweep_tail = 0.0
var countdown_sweep_hue = -1.0
var countdown_sweep_color = Color.WHITE
var original_stage: Node3D
var source_background: Node3D
var background_bank:Array=[]
var imported_frames: Array[Texture2D] = []
var special_frames: Array[Texture2D] = []

func _ready() -> void:
	for index in range(1,12):
		var path="res://assets/ssrg/imported/Effect_A_%02d.png" % index
		if ResourceLoader.exists(path): imported_frames.append(load(path))
		var special_path="res://assets/ssrg/imported/Effect_B_%02d.png" % index
		if ResourceLoader.exists(special_path): special_frames.append(load(special_path))
	original_stage=preload("res://scripts/ssrg_stage.gd").new(); add_child(original_stage)
	source_background=preload("res://scripts/ssrg_background.gd").new();add_child(source_background);source_background.configure(0)
	background_bank.append(source_background)
	for profile in range(1,4):
		var background=preload("res://scripts/ssrg_background.gd").new();add_child(background);background.configure(profile);background.hide();background_bank.append(background)
	var w = world
	var half = w.FRAME_HALF_WIDTH
	floor_node = shaded_plane(Vector2(half * 2.0, 62.0), preload("res://scripts/ssrg_floor.gdshader"), Vector3(0, .026, -30.5), -7)
	floor_node.material_override.set_shader_parameter("opacity", .32)
	for side in [-1, 1]:
		var rail = shaded_plane(Vector2(.95, 64.0), preload("res://scripts/ssrg_rail.gdshader"), Vector3(side * (half + .35), .08, -31.0), 2)
		if side > 0: rail.rotation_degrees.y = 180
	var band_mesh = QuadMesh.new(); band_mesh.size = Vector2(half * 2.0 + 1.2, w.JUDGMENT_DEPTH * 1.25)
	var band_mat = ShaderMaterial.new(); band_mat.shader = preload("res://scripts/reference_note.gdshader")
	band_mat.set_shader_parameter("note_brightness_applies", false)
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
		line.material_override.set_shader_parameter("tint", Color(.75, .9, 1.0)); line.material_override.set_shader_parameter("strength", .5)
		line.visible = false; press_lines.append(line)
	refresh()

func shaded_plane(size: Vector2, shader: Shader, at: Vector3, priority: int) -> MeshInstance3D:
	var mesh = PlaneMesh.new(); mesh.size = size
	var mat = ShaderMaterial.new(); mat.shader = shader; mat.render_priority = priority
	var node = world.mesh_node(mesh, self, mat); node.position = at
	return node

func refresh() -> void:
	active = world.game.uses_skd_stage()
	visible = active
	if original_stage:
		original_stage.configure(world)
		for child in get_children():
			if child != original_stage and child != source_background: child.visible=false
	if source_background:source_background.visible=active and world.game.countdown<=0
	if world.cover_material: world.cover_material.set_shader_parameter("photo", active)

# --- Hit effects ---------------------------------------------------------------------
func spawn(lane: float, kind: String, sustain_entry: Dictionary, pointer_id: int, direction: int = -1) -> void:
	var h: Dictionary = hit_pool.pop_back() if not hit_pool.is_empty() else make_hit()
	style_hit(h)
	# B belongs to source special event/item notes. Ordinary taps and sustains use A.
	var frames=special_frames if kind=="special" else imported_frames
	h.frames=frames
	if not frames.is_empty(): h.material.set_shader_parameter("atlas", frames[0])
	h.age = 0.0; h.sustain_entry = sustain_entry; h.pointer_id = pointer_id; h.kind = kind
	# Sustains follow their owned physical contact across the judgment line.
	var x=world.note_x(lane)
	if world.game.ssrg_playable_run and not sustain_entry.is_empty():x=sustain_finger_x(sustain_entry,world.game.pointers,x)
	h.x = lane_flash_x(x); h.placed = false; h.glide_left = GLIDE_AFTER
	# Keep the physical lane occupied by this sustain.  SKD starts another Effect_A
	# instance whenever the finger enters a different lane; the older instances keep
	# playing, which makes a fast slide read as a continuous chain of impacts.
	h.last_cross_lane = flash_lane_index(x)
	h.node.position = flash_point(h.x)
	h.node.rotation = world.camera.rotation
	h.material.set_shader_parameter("opacity", world.game.features.effect("Hit flashes"))
	h.material.set_shader_parameter("frame", 0.0)
	if h.style == "lumen":
		h.material.set_shader_parameter("tint", lumen_tint(kind))
		h.material.set_shader_parameter("direction", float(direction) if kind == "flick" else -1.0)
		h.material.set_shader_parameter("seed", randf() * 100.0)
		h.material.set_shader_parameter("particles", world.game.features.effect("Particles"))
	# Hit effects page: size, and an optional colour over the source art.
	h.node.scale = Vector3.ONE * world.game.hit_size * (1.0 if world.game.uses_ssrg_gameplay() else SYNK_HIGHWAY_SCALE)
	h.node.rotation = world.camera.rotation
	if h.style == "ssrg":
		# A colour picked on the Hit effects page wins; by default each flash takes its note's
		# colour (blue taps, gold holds and slides, pink flicks). Special notes keep Effect_B.
		var recolor = world.game.hit_color != "" or NOTE_HIT_KEYS.has(kind)
		h.material.set_shader_parameter("tint", hit_tint(kind) if recolor else Color.WHITE)
		h.material.set_shader_parameter("recolor", recolor)
	h.node.visible = true; hits.append(h)
	if kind == "flick":
		spawn_flick_sparks(h.x, h.node.scale.x)
		# Special item flicks keep their static puck art, so only animated flicks are sliced.
		var note: Dictionary = sustain_entry.get("note", {})
		if not world.game.uses_recorder_colors() and not note.has("ssrg_special"): spawn_flick_slice(lane, flick_swipe_angle(pointer_id))

# The flick splash: short spark streaks sprayed up and out from the judgment bar, like the
# streaky shards of the Effect_A hit flash. They fan across a wide arc (mostly up, some almost
# sideways), arc back under gravity, and each is turned along its flight.
func spawn_flick_sparks(x: float, flash_scale: float = 1.0) -> void:
	var up = world.camera.basis.y.normalized()
	var sidev = world.camera.basis.x.normalized()
	var origin = flash_point(x)
	var tint = Color.from_string(world.game.hit_color, Color.WHITE) if world.game.hit_color != "" else Color.WHITE
	var parent: Node3D = hit_layer if hit_layer != null else self
	# Match the Effect_A flash: its cyan while hot, its deeper blue as it dies (or the colour
	# picked on the Hit effects page).
	# The flash's colour: the picked hit colour, or the flick note's own.
	var glow = hit_tint("flick")
	var deep = glow.darkened(.35)
	# Sparks rise out of the flash's bright disc, not from one point at its centre.
	var disc = Vector2(620, 372) * world.SSRG_UNIT * HIT_SCALE * flash_scale * Vector2(.1, .04)
	# Shrink the whole splash's travel so even the tallest spark stops at the middle of the screen.
	var reach = flick_splash_reach(origin, up)
	var fit = clampf((reach - FLICK_SPARK_MAX_LENGTH * .5 * world.FIT) / (flick_spark_max_rise() * world.FIT), 0.0, 1.0)
	for i in FLICK_SPARK_COUNT:
		var mesh = QuadMesh.new()
		mesh.size = Vector2(0.38, FLICK_SPARK_MAX_LENGTH / 1.3) * (0.7 + randf() * 0.6) * world.FIT
		var mat = ShaderMaterial.new(); mat.shader = FLICK_SPARK_SHADER; mat.render_priority = 9
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("glow", glow)
		mat.set_shader_parameter("deep", deep)
		mat.set_shader_parameter("seed", randf() * 100.0)
		var node = world.mesh_node(mesh, parent, mat)
		var spot = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0)
		var base = origin + sidev * (spot.x * absf(spot.x) * disc.x) + up * (spot.y * disc.y)
		node.position = base
		node.visible = false
		# Mostly up: the sum of two randoms clusters angles near vertical, and none goes
		# wider than FLICK_SPARK_SPREAD either side, so the spray leans the flick's way.
		var angle = (randf() + randf() - 1.0) * deg_to_rad(FLICK_SPARK_SPREAD)
		# Faster the closer to vertical, so the tallest sparks shoot straight up.
		var speed = (FLICK_SPARK_MIN_SPEED + randf() * FLICK_SPARK_EXTRA_SPEED) * world.FIT * (1.0 + 0.45 * cos(angle * 1.8)) * fit
		var up_speed = cos(angle) * speed
		var side_speed = sin(angle) * speed
		# Each spark dies at its own random time, so the spray thins out gradually.
		var life = FLICK_SPARK_LIFE * (0.6 + randf() * 0.4)
		flick_sparks.append({"node": node, "material": mat, "age": -randf_range(FLICK_SPARK_DELAY.x, FLICK_SPARK_DELAY.y), "life": life, "base": base, "up_speed": up_speed, "side_speed": side_speed, "gravity": FLICK_SPARK_GRAVITY * world.FIT * fit})
		orient_flick_spark(node, side_speed, up_speed)
	spawn_flick_flare(origin, up, tint, parent, minf(reach, FLICK_FLARE_SIZE.y * world.FIT))

# The slice: a blade streak sweeps diagonally up through the flick note, and the note falls
# apart along the cut. The top half flies up with the flick, the bottom half drops, and both
# fade with a hot glowing edge where they were cut.
const FLICK_SLICE_LIFE = .36
const FLICK_SLASH_LIFE = .24
const FLICK_SLASH_SWEEP = .045   # seconds for the blade to cross the note
# With no finger to follow (autoplay), the cut runs up, tilted at most this many degrees.
const FLICK_SLICE_AUTO_TILT = 15.0
# The swipe's angle on screen (radians from the right, counter-clockwise: PI/2 is straight
# up), from where the finger went down to where it is now, so the cut follows the swipe.
func flick_swipe_angle(pointer_id: int) -> float:
	var touch: Dictionary = world.game.pointers.get(pointer_id, {})
	if touch.has("start") and touch.has("position"):
		var move: Vector2 = (touch.position - touch.start) * world.game.size   # to pixels
		if move.length() > 1.0: return atan2(-move.y, move.x)
	return PI * .5 + deg_to_rad(randf_range(-FLICK_SLICE_AUTO_TILT, FLICK_SLICE_AUTO_TILT))
const FLICK_SLICE_SHADER = preload("res://scripts/flick_slice.gdshader")
var flick_slices: Array = []
func spawn_flick_slice(lane: float, angle: float) -> void:
	var parent: Node3D = hit_layer if hit_layer != null else self
	var cam: Camera3D = world.camera
	var right = cam.basis.x.normalized(); var up = cam.basis.y.normalized()
	var width: float = world.flick_note_width()
	var centre = Vector3(world.note_x(lane), .38 * world.game.gameplay_note_size(), 0.0)
	var along = right * cos(angle) + up * sin(angle)       # the cut, along the swipe
	var normal = -right * sin(angle) + up * cos(angle)     # across the cut
	var mesh = QuadMesh.new(); mesh.size = Vector2(width, width)
	mesh.center_offset.y = width * (553.0 / 768.0 - 0.5)  # the disc centre sits on the node
	var tint = hit_tint("flick")
	var edge = tint.lerp(Color.WHITE, .6)
	for side in [-1.0, 1.0]:
		var mat = ShaderMaterial.new(); mat.shader = FLICK_SLICE_SHADER; mat.render_priority = 7
		mat.set_shader_parameter("artwork", world.flick_frames()[0])
		mat.set_shader_parameter("cut_point", Vector2(.5, 553.0 / 768.0))
		mat.set_shader_parameter("cut_angle", -angle)
		mat.set_shader_parameter("side", side)
		mat.set_shader_parameter("edge_color", edge)
		var node = world.mesh_node(mesh, parent, mat)
		# side -1 keeps the half on the `normal` side of the cut. The halves spring apart
		# across the cut and are carried on along the swipe, each turning away from it.
		var drift = (normal * -side * .55 + along * .6) * width * .8
		flick_slices.append({"node": node, "material": mat, "age": 0.0, "base": centre, "drift": drift, "spin": -side * .3, "kind": "half"})
	# The blade: a thin hot streak whose head runs along the cut in the swipe's direction.
	var length = width * 2.3
	var blade = QuadMesh.new(); blade.size = Vector2(width * .32, length)
	var blade_mat = ShaderMaterial.new(); blade_mat.shader = FLICK_SPARK_SHADER; blade_mat.render_priority = 10
	blade_mat.set_shader_parameter("tint", Color.WHITE); blade_mat.set_shader_parameter("glow", tint)
	blade_mat.set_shader_parameter("bend", 0.0); blade_mat.set_shader_parameter("sharpness", 22.0)
	var blade_node = world.mesh_node(blade, parent, blade_mat)
	flick_slices.append({"node": blade_node, "material": blade_mat, "age": 0.0, "base": centre - along * length * .5, "along": along, "length": length, "angle": angle, "kind": "blade"})
	advance_flick_slices(0.0, false)

func advance_flick_slices(delta: float, playing: bool) -> void:
	var opacity = world.game.features.effect("Hit flashes")
	for i in range(flick_slices.size() - 1, -1, -1):
		var f: Dictionary = flick_slices[i]
		if playing: f.age += delta
		var life = FLICK_SLASH_LIFE if f.kind == "blade" else FLICK_SLICE_LIFE
		var k = f.age / life
		if k >= 1.0:
			f.node.queue_free(); flick_slices.remove_at(i); continue
		if f.kind == "blade":
			# Head races across the note, tail anchored where the cut began, then it fades.
			var sweep = clampf(f.age / FLICK_SLASH_SWEEP, 0.0, 1.0)
			sweep = 1.0 - pow(1.0 - sweep, 2.0)
			face_camera(f.node, f.angle - PI * .5, Vector3(1.0 - .5 * k, maxf(sweep, .01), 1.0))
			f.node.position = f.base + f.along * (f.length * sweep * .5)
			f.material.set_shader_parameter("opacity", opacity * (1.0 - k * k))
		else:
			# The halves part fast, then coast, turning a little, while the cut cools and fades.
			var move = 1.0 - pow(1.0 - k, 3.0)
			f.node.position = f.base + f.drift * move
			face_camera(f.node, f.spin * move)
			f.material.set_shader_parameter("heat", 1.0 - k)
			f.material.set_shader_parameter("opacity", opacity * pow(1.0 - k, 1.5))

# How far up (in world units, along the camera's up) the splash may reach from `origin`
# before it would pass the middle of the screen.
func flick_splash_reach(origin: Vector3, up: Vector3) -> float:
	var cam: Camera3D = world.camera
	var middle = cam.get_viewport().get_visible_rect().size.y * FLICK_SPLASH_TOP
	var from = cam.unproject_position(origin)
	var pixels_per_unit = from.y - cam.unproject_position(origin + up).y
	if pixels_per_unit <= 0.0: return INF
	return maxf(0.0, from.y - middle) / pixels_per_unit * FLICK_SPLASH_HEIGHT_SCALE

# The highest rise (in FIT units) the fastest, straight-up spark reaches before it dies.
func flick_spark_max_rise() -> float:
	var top_speed = (FLICK_SPARK_MIN_SPEED + FLICK_SPARK_EXTRA_SPEED) * 1.45
	var t = minf(top_speed / (2.0 * FLICK_SPARK_GRAVITY), FLICK_SPARK_LIFE)
	return top_speed * t - FLICK_SPARK_GRAVITY * t * t

# The upward flare: one tall straight streak that shoots up from the hit and fades fast,
# drawn with the spark shader so it shares the white-core, cyan-glow look.
const FLICK_FLARE_LIFE = .22
const FLICK_FLARE_SIZE = Vector2(3.2, 11.0)
var flick_flares: Array = []
func spawn_flick_flare(origin: Vector3, up: Vector3, tint: Color, parent: Node3D, height: float) -> void:
	var mesh = QuadMesh.new(); mesh.size = Vector2(FLICK_FLARE_SIZE.x * world.FIT, height)
	var mat = ShaderMaterial.new(); mat.shader = FLICK_SPARK_SHADER; mat.render_priority = 9
	mat.set_shader_parameter("tint", tint); mat.set_shader_parameter("glow", hit_tint("flick")); mat.set_shader_parameter("bend", 0.0); mat.set_shader_parameter("sharpness", 10.0)
	var node = world.mesh_node(mesh, parent, mat)
	node.rotation = world.camera.rotation
	flick_flares.append({"node": node, "material": mat, "age": 0.0, "base": origin, "up": up, "height": height})
	advance_flick_flares(0.0, false)

func advance_flick_flares(delta: float, playing: bool) -> void:
	var opacity = world.game.features.effect("Hit flashes")
	for i in range(flick_flares.size() - 1, -1, -1):
		var f: Dictionary = flick_flares[i]
		if playing: f.age += delta
		var k = f.age / FLICK_FLARE_LIFE
		if k >= 1.0:
			f.node.queue_free(); flick_flares.remove_at(i); continue
		# Shoots up fast (eased), stretching tall, while it fades.
		var grow = 1.0 - pow(1.0 - k, 3.0)
		var length = lerpf(.35, 1.0, grow)
		f.node.scale = Vector3(lerpf(1.0, .55, k), length, 1.0)
		f.node.position = f.base + f.up * (f.height * length * .5)
		f.node.rotation = world.camera.rotation
		f.material.set_shader_parameter("opacity", opacity * (1.0 - k) * (1.0 - k))

const FLICK_SPARK_GRAVITY = 10.0
# Sparks burst out as the flash reaches full size (its frames 2-3 at 33 fps), in seconds.
const FLICK_SPARK_DELAY = Vector2(.03, .09)
const FLICK_SPARK_SPREAD = 14.0  # widest angle from straight up, in degrees
const FLICK_SPARK_MIN_SPEED = 32.0
const FLICK_SPARK_EXTRA_SPEED = 20.0
const FLICK_SPARK_MAX_LENGTH = 4.5  # longest spark streak, in FIT units
# The splash never rises past this fraction of the screen height from the top (.5 = the middle).
const FLICK_SPLASH_TOP = .5
# Then stretched past that by this much (1.2 = 20% higher than the middle of the screen).
const FLICK_SPLASH_HEIGHT_SCALE = 1.2
# Face the camera, then turn the strand so its head points along its current flight.
func orient_flick_spark(node: Node3D, side_speed: float, up_speed: float, size: Vector3 = Vector3.ONE) -> void:
	face_camera(node, atan2(-side_speed, up_speed), size)

# Face the camera, turned `angle` in the screen plane, then sized. Built in one basis: turning
# a node that is already squashed (rotate_object_local) skews it instead of turning it.
func face_camera(node: Node3D, angle: float, size: Vector3 = Vector3.ONE) -> void:
	node.basis = Basis.from_euler(world.camera.rotation) * Basis(Vector3.BACK, angle) * Basis.from_scale(size)

func advance_flick_sparks(delta: float, playing: bool) -> void:
	var up = world.camera.basis.y.normalized()
	var sidev = world.camera.basis.x.normalized()
	var opacity = world.game.features.effect("Hit flashes")
	for i in range(flick_sparks.size() - 1, -1, -1):
		var f: Dictionary = flick_sparks[i]
		if playing: f.age += delta
		var a: float = f.age
		if a >= f.life:
			f.node.queue_free(); flick_sparks.remove_at(i); continue
		# Waiting for the flash to bloom before bursting out of it.
		f.node.visible = a >= 0.0
		if a < 0.0: continue
		var gravity: float = f.gravity
		# Ballistic arc: fast up, pulled back down so the column peaks tall then falls.
		f.node.position = f.base + up * (f.up_speed * a - gravity * a * a) + sidev * (f.side_speed * a)
		var k = a / f.life
		# Streaks shorten to small specks as they cool, like the shards the flash leaves behind.
		orient_flick_spark(f.node, f.side_speed, f.up_speed - 2.0 * gravity * a, Vector3(1.0 - 0.35 * k, 1.0 - 0.75 * k, 1.0))
		f.material.set_shader_parameter("age", k)
		f.material.set_shader_parameter("opacity", opacity * (1.0 - k * k))

# How fast a flash crosses lanes, and how long it may keep going after its note has ended.
const GLIDE_LANES_PER_SECOND = 30.0
const GLIDE_AFTER = .3
func glide_speed() -> float:
	return GLIDE_LANES_PER_SECOND*absf(world.note_x(1.0)-world.note_x(0.0))

# A flash sits on one of the chart's lanes, as in SKD: the lane nearest the finger, and never
# outside the first and last one, however far the finger strays.
func lane_flash_x(x: float) -> float:
	return world.note_x(flash_lane_value(flash_lane_index(x)))

func flash_lane_step() -> float:
	var last = float(SynkChart.MAX_LANE)
	# 13 keys use every lane, 7 keys every second one, 4 keys every fourth.
	return last / float(maxi(1, world.game.gameplay_lane_count() - 1))

func flash_lane_index(x: float) -> int:
	var last = float(SynkChart.MAX_LANE)
	var step = flash_lane_step()
	var lane = clampf(world.world_lane(x), 0.0, last)
	return clampi(int(roundf(lane / step)),0,world.game.gameplay_lane_count()-1)

func flash_lane_value(index: int) -> float:
	return clampf(float(index)*flash_lane_step(),0.0,float(SynkChart.MAX_LANE))

func emit_crossed_lane_hits(h: Dictionary, x: float) -> void:
	var current=flash_lane_index(x)
	var previous=int(h.get("last_cross_lane",current))
	if current==previous:return
	var direction=1 if current>previous else -1
	# Emit every intermediate lane even if a fast move crosses several between
	# rendered frames. Revisiting a lane emits again, just like a new finger entry.
	for index in range(previous+direction,current+direction,direction):
		spawn(flash_lane_value(index),"slide",{},-999)
	h.last_cross_lane=current

# Countdown reveal: every number carries one empty slide gesture. Three and one
# travel left-to-right; two travels right-to-left. These have no gameplay entry.
func update_countdown_sweep(remaining:float) -> void:
	if remaining<=0.0:
		countdown_sweep_number=-1
		countdown_sweep_step=-1
		return
	var number=clampi(ceili(remaining),1,3)
	if number!=countdown_sweep_number:
		countdown_sweep_number=number
		countdown_sweep_step=-1
		countdown_sweep_hue=randf() if countdown_sweep_hue<0.0 else fmod(countdown_sweep_hue+randf_range(.22,.78),1.0)
		countdown_sweep_color=Color.from_hsv(countdown_sweep_hue,.78,1.0)
	var fraction=remaining-floorf(remaining)
	var progress=0.0 if is_zero_approx(fraction) else 1.0-fraction
	var last=world.game.gameplay_lane_count()-1
	# Divide the second into one slot per lane so the final lane fires before the
	# number changes, rather than requiring an unreachable exact progress of 1.
	var target=clampi(floori(progress*float(last+1)),0,last)
	for step in range(countdown_sweep_step+1,target+1):
		var index=step if number in [3,1] else last-step
		spawn(flash_lane_value(index),"slide",{},-999)
		var hit:Dictionary=hits[-1]
		hit.material.set_shader_parameter("tint",countdown_sweep_color)
		if hit.style=="ssrg":hit.material.set_shader_parameter("recolor",true)
		countdown_sweep_tail=HIT_LIFE
	countdown_sweep_step=maxi(countdown_sweep_step,target)

# Where a flash goes: the note's point on the judgement line, pulled toward the camera along
# the line of sight. It shows exactly on that point on screen (lifting it instead made outer
# flashes drift off the line and look tilted) and draws in front of the track.
const FLASH_PULL = 3.0
func flash_point(x: float) -> Vector3:
	var on_line = Vector3(x, .035, 0)
	return on_line + Vector3.UP*FLASH_PULL if world.game.uses_ssrg_gameplay() else on_line + (world.camera.global_position - on_line).normalized() * FLASH_PULL

# The recording confirms the packaged def_c_trans 2x footprint is used at full size.
const HIT_SCALE = 1.0
var hit_layer: Node3D
# On SYNK's wider perspective lanes the source art is drawn a little larger.
const SYNK_HIGHWAY_SCALE = 1.25
func make_hit() -> Dictionary:
	# Source centered 310x186 sprite under def_c_trans scale (2,2,1).
	var mesh = QuadMesh.new(); mesh.size = Vector2(620,372)*world.SSRG_UNIT*HIT_SCALE
	var mat = ShaderMaterial.new(); mat.render_priority = 6
	# Hits live on their own layer, so they also show when the SSRG stage itself is hidden.
	if hit_layer == null:
		hit_layer = Node3D.new(); hit_layer.name = "SSRGHitLayer"; world.add_child.call_deferred(hit_layer)
	var node = world.mesh_node(mesh, hit_layer, mat); node.rotation = world.camera.rotation; node.visible = false
	var h = {"node": node, "material": mat, "age": 0.0, "sustain_entry": {}, "pointer_id": -999, "kind": "tap", "style": ""}
	style_hit(h)
	return h

# Two hit styles share everything above: the sprite, its place on the lanes, the 33 fps frame
# clock, the lifetime and the sustain re-triggers. Only the picture differs.
#   SKD:   the source flash artwork.
#   Lumen: SYNK's own flash, drawn by lumen_hit.gdshader, coloured by note type.
const STYLE_SHADERS = {"ssrg": preload("res://scripts/ssrg_hit.gdshader"), "lumen": preload("res://scripts/lumen_hit.gdshader")}
func hit_style() -> String:
	# SSRG playback always uses the packaged Effect_A sequence seen in SKD.
	# Other SYNK highways keep the player's SKD/Lumen preference.
	if world.game.uses_ssrg_gameplay(): return "ssrg"
	return "lumen" if world.game.hit_style == "lumen" else "ssrg"

func style_hit(h: Dictionary) -> void:
	var style = hit_style()
	if h.get("style", "") == style: return
	h.style = style; h.material.shader = STYLE_SHADERS[style]

# Lumen's colours follow the notes: blue taps, gold holds and slides (their connectors are
# gold), pink flicks. A colour chosen on the Hit effects page replaces them.
# The note colour a default-coloured hit flash takes, by note kind.
const NOTE_HIT_KEYS = {"tap": "tap", "hold": "hold", "slide": "slide", "flick": "flick"}
# SSRG notes are drawn from their own art, so the flash matches that art's colour
# (sampled from tap.png, hold.png and the flick puck) rather than the theme palette.
const SSRG_NOTE_COLORS = {"tap": Color("19acf5"), "hold": Color("ebb521"), "slide": Color("ebb521"), "flick": Color("fa1068")}
# SYNK mode's note colours (assets/synk_mode): coral taps, amber holds and slides; flicks keep their pink.
const SYNK_NOTE_COLORS = {"tap": Color("ff6b3d"), "hold": Color("ffc36b"), "slide": Color("ffc36b"), "flick": Color("ff2d7a")}
func hit_tint(kind: String) -> Color:
	if world.game.hit_color != "": return Color.from_string(world.game.hit_color, Color.WHITE)
	if world.game.synk_mode(): return SYNK_NOTE_COLORS.get(kind, SYNK_NOTE_COLORS.tap)
	if world.game.uses_ssrg_gameplay(): return SSRG_NOTE_COLORS.get(kind, SSRG_NOTE_COLORS.tap)
	return world.element_color(NOTE_HIT_KEYS.get(kind, "tap"), LUMEN_COLORS.get(kind, LUMEN_COLORS.tap))

const LUMEN_COLORS = {"tap": Color("4fd2ff"), "hold": Color("ffc94a"), "slide": Color("ffc94a"), "flick": Color("ff6fb5"), "special": Color("b993ff")}
func lumen_tint(kind: String) -> Color:
	if world.game.hit_color != "": return Color.from_string(world.game.hit_color, Color.WHITE)
	return world.element_color("hits", LUMEN_COLORS.get(kind, LUMEN_COLORS.tap))

func release(h: Dictionary) -> void:
	h.node.visible = false; hit_pool.append(h)

func resume_sustain(entry:Dictionary) -> void:
	for hit in hits:
		if hit.sustain_entry.get("key","")==entry.get("key",""):return
	spawn(SynkChart.lane_at(entry.note,world.game.song_time),str(entry.note.kind),entry,int(entry.pointer))

func clear_hits() -> void:
	if original_stage:original_stage.clear_touch_feedback()
	for hit in hits+hit_pool:
		hit.node.hide();hit.node.queue_free()
	hits.clear();hit_pool.clear()
	for f in flick_sparks: f.node.queue_free()
	flick_sparks.clear()
	for f in flick_flares: f.node.queue_free()
	flick_flares.clear()
	for f in flick_slices: f.node.queue_free()
	flick_slices.clear()
	for background in background_bank:
		background.particles.clear();background.elapsed=0.0;background.frame_credit=0.0;background.momentum=0.0; background.hide()
	if world.cover_material:
		world.cover_material.set_shader_parameter("ssrg_fever_weights",Vector4.ZERO)
		world.cover_material.set_shader_parameter("ssrg_fever_dark",0.0)

# Hidden when a song starts and shown during it: lane guides, touch marks, the background
# particles with their fever versions, and the pooled hit flashes.
func late_pieces() -> Array:
	var pieces: Array = []
	if original_stage: pieces.append_array(original_stage.receptors + original_stage.feedback_marks)
	for root in [source_background, hit_layer] + background_bank:
		if is_instance_valid(root): pieces.append_array(root.find_children("*", "GeometryInstance3D", true, false))
	return pieces

func prefill(count: int = 16) -> void:
	while hit_pool.size() + hits.size() < count: hit_pool.append(make_hit())
	# Pooled flashes take the style in use now, so the warm-up prepares the right picture.
	for h in hit_pool: style_hit(h)

static func sustain_effect_active(entry:Dictionary,at:float,ssrg:bool) -> bool:
	if entry.is_empty():return false
	if not ssrg:return not entry.done
	# Recoverable contact gaps do not end the linked connector effect. A tail
	# may score early, but its light must still reach the physical last connector.
	return not entry.done or at<=float(entry.get("ssrg_effect_until",-INF))

static func sustain_finger_x(entry:Dictionary,contacts:Dictionary,fallback:float) -> float:
	var owner=int(entry.get("sustain_last_pointer",entry.get("pointer",-999)))
	if contacts.has(owner):
		var contact:Dictionary=contacts[owner]
		# A reused Android finger index belongs to a new contact, not this chain.
		if int(contact.get("ssrg_identity",0))==int(entry.get("sustain_last_identity",-1)):
			entry.ssrg_effect_x=float(contact.world.x)
	# Keep the last finger position during a recoverable gap or early tail lift.
	return float(entry.get("ssrg_effect_x",fallback))

func _process(delta: float) -> void:
	if not active:
		# The "SSRG" hit style on SYNK's Gold and Neon highways: only the hit art runs.
		var game = world.game
		advance_hits(delta,(game.mode == "play" and game.countdown<=0 and game.resume_countdown<=0) or game.highway_preview)
		return
	original_stage.update(world)
	var game = world.game
	var playing = (game.mode == "play" and game.countdown<=0 and game.resume_countdown<=0) or game.highway_preview
	countdown_sweep_tail=maxf(0.0,countdown_sweep_tail-delta)
	var hit_playing=playing or countdown_sweep_tail>0.0
	var presentation=game.ssrg_presentation
	var using_state=presentation and presentation.active
	var weights=presentation.weights if using_state else [1.0,0.0,0.0,0.0]
	var custom=world.custom_color("lasers")
	for index in background_bank.size():
		var background=background_bank[index]
		background.intensity=game.features.effect("Lasers")*float(weights[index])
		background.tint=custom if custom!=null else Color.WHITE
		background.visible=game.mode in ["play","paused"] and game.countdown<=0 and not game.finishing and background.intensity>0
		if background.visible:background.advance(delta,not playing or game.resume_countdown>0)
	if world.cover_material:
		var dark=0.0
		if using_state:
			for index in 6:dark+=float(presentation.phase_weights[index])*float(presentation.DATA.PROFILES[index].background_alpha)
		world.cover_material.set_shader_parameter("ssrg_fever_weights",Vector4(weights[0],weights[1],weights[2],weights[3]) if using_state else Vector4.ZERO)
		world.cover_material.set_shader_parameter("ssrg_fever_dark",dark)
	if using_state:
		world.ssrg_finger_beam_material.set_shader_parameter("tint",world.element_color("beams",presentation.beam_color))
	advance_hits(delta,hit_playing)

# Source RenderLongCoolbombTouch rewinds after normalized time > .3.
# Independent tap instances intentionally preserve SYNK's uninterrupted dense-hit flow.
func advance_hits(delta: float, playing: bool) -> void:
	advance_flick_sparks(delta, playing)
	advance_flick_slices(delta, playing)
	advance_flick_flares(delta, playing)
	var game = world.game
	for i in range(hits.size() - 1, -1, -1):
		var h: Dictionary = hits[i]
		var held = sustain_effect_active(h.sustain_entry,world.render_time(),game.ssrg_playable_run)
		# A slide too quick for the flash to keep up: once it ends, the flash finishes its way to
		# the last connector for a moment instead of stopping short.
		var finishing = false
		if not held and playing and not h.sustain_entry.is_empty() and h.get("placed",false) and not h.sustain_entry.has("missed_at") and float(h.get("glide_left",0.0)) > 0.0:
			var last: Dictionary = h.sustain_entry.note
			var end_x = lane_flash_x(world.note_x(SynkChart.lane_at(last, float(last.time)+float(last.duration))))
			if absf(end_x-float(h.x)) > .001:
				finishing = true; h.glide_left = float(h.glide_left)-delta
				h.x = move_toward(float(h.x), end_x, maxf(glide_speed(), absf(end_x-float(h.x))/maxf(float(h.glide_left),.016))*delta)
				h.node.position = flash_point(h.x); h.age = fmod(h.age, HOLD_RETRIGGER)
		held = held or finishing
		if playing: h.age += delta
		if playing and held and h.age > HOLD_RETRIGGER: h.age = fmod(h.age,HOLD_RETRIGGER)
		if (not held and h.age >= HIT_LIFE) or (game.mode not in ["play", "paused"] and not game.highway_preview):
			hits.remove_at(i); release(h); continue
		if held:
			var x=world.note_x(SynkChart.lane_at(h.sustain_entry.note, world.render_time()))
			if game.ssrg_playable_run:x=sustain_finger_x(h.sustain_entry,game.pointers,x)
			if game.ssrg_playable_run and h.kind=="slide" and not finishing:emit_crossed_lane_hits(h,x)
			# The flash rests on lanes and glides between them, so it visibly passes every
			# connector of a slide rather than jumping from one to the next.
			if not finishing:
				var target = lane_flash_x(x)
				h.x = move_toward(float(h.x), target, glide_speed()*delta) if h.get("placed",false) else target
				h.placed = true
				h.node.position = flash_point(h.x)
		var frames: Array=h.get("frames",imported_frames)
		var frame_index = int(h.age*HIT_FPS)
		if h.style == "lumen":
			h.material.set_shader_parameter("frame", float(mini(10, frame_index)))
			h.material.set_shader_parameter("particles", game.features.effect("Particles"))
		elif not frames.is_empty(): h.material.set_shader_parameter("atlas",frames[mini(frames.size()-1,frame_index)])
		h.material.set_shader_parameter("opacity",game.features.effect("Hit flashes"))
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
