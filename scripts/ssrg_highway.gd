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
# burst of sparks flung straight up from the bar (tall and narrow) so the impact reads as an
# explosive splash in the flick's up direction.
var flick_sparks: Array = []
const FLICK_SPARK_LIFE = .46
const FLICK_SPARK_COUNT = 18
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
		h.material.set_shader_parameter("tint", Color.from_string(world.game.hit_color, Color.WHITE) if world.game.hit_color != "" else Color.WHITE)
		h.material.set_shader_parameter("recolor", world.game.hit_color != "")
	h.node.visible = true; hits.append(h)
	if kind == "flick": spawn_flick_sparks(h.x)

# The flick splash: sparks launched up from the judgment bar. They travel far up (tall) and
# spread out sideways as well, arcing back under gravity, so the burst reads as a wide upward
# spray. Coloured to match the hit flash (white, or the player's chosen hit colour).
func spawn_flick_sparks(x: float) -> void:
	var up = world.camera.basis.y.normalized()
	var sidev = world.camera.basis.x.normalized()
	var origin = flash_point(x)
	var tint = Color.from_string(world.game.hit_color, Color.WHITE) if world.game.hit_color != "" else Color.WHITE
	var parent: Node3D = hit_layer if hit_layer != null else self
	for i in FLICK_SPARK_COUNT:
		var mesh = QuadMesh.new()
		mesh.size = Vector2.ONE * (1.05 + randf() * 0.7) * world.FIT
		var mat = ShaderMaterial.new(); mat.shader = FLICK_SPARK_SHADER; mat.render_priority = 9
		mat.set_shader_parameter("tint", tint)
		var node = world.mesh_node(mesh, parent, mat)
		node.rotation = world.camera.rotation
		node.position = origin
		# Up (tall) with a wide sideways spread, so the spray fans out as it rises.
		var up_speed = (15.0 + randf() * 9.0) * world.FIT
		var side_speed = (randf() - 0.5) * 9.0 * world.FIT
		var vel = up * up_speed + sidev * side_speed
		flick_sparks.append({"node": node, "material": mat, "age": 0.0, "base": origin, "vel": vel})

func advance_flick_sparks(delta: float, playing: bool) -> void:
	var up = world.camera.basis.y.normalized()
	var opacity = world.game.features.effect("Hit flashes")
	for i in range(flick_sparks.size() - 1, -1, -1):
		var f: Dictionary = flick_sparks[i]
		if playing: f.age += delta
		var a: float = f.age
		if a >= FLICK_SPARK_LIFE:
			f.node.queue_free(); flick_sparks.remove_at(i); continue
		var base: Vector3 = f.base
		var vel: Vector3 = f.vel
		# Ballistic arc: fast up, pulled back down so the column peaks tall then falls.
		f.node.position = base + vel * a - up * (18.0 * world.FIT * a * a)
		f.node.rotation = world.camera.rotation
		var k = a / FLICK_SPARK_LIFE
		f.node.scale = Vector3.ONE * (1.0 - 0.7 * k)          # sparks shrink as they fly
		f.material.set_shader_parameter("opacity", opacity * (1.0 - k))

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
