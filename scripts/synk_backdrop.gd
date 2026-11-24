extends Node
# SYNK mode's stage: one of five backdrops drawn on the screen-filling quad behind the
# highway, in place of the song artwork and SSRG's stage effects. The player picks one in
# Settings > Highway (prefs "highway"/"synk_stage").
#   aura:    veils of amber light curling out from the rails, on black (synk_stage_aura)
#   waves:   a sea of sound waves that sync on the beat (synk_stage.gdshader)
#   worlds:  two mirrored worlds that drift apart and snap together (synk_stage_worlds)
#   stars:   a constellation drawn by the player's hits (synk_stage_stars)
#   strings: harp strings along the rails, plucked by hits (synk_stage_strings)
const STAGES = ["aura", "waves", "worlds", "stars", "strings"]
const LABELS = {"aura": "AURA", "waves": "WAVES", "worlds": "WORLDS", "stars": "STARS", "strings": "STRINGS"}
const SHADERS = {
	"aura": preload("res://scripts/synk_stage_aura.gdshader"),
	"waves": preload("res://scripts/synk_stage.gdshader"),
	"worlds": preload("res://scripts/synk_stage_worlds.gdshader"),
	"stars": preload("res://scripts/synk_stage_stars.gdshader"),
	"strings": preload("res://scripts/synk_stage_strings.gdshader"),
}
const MAX_STARS = 400
const STRINGS_PER_SIDE = 8
var world: Node3D
var material: ShaderMaterial
# Recent note hits, newest first: {"at": screen position 0..1, "age", "kind", "color"}.
var hits: Array = []
var vanish = Vector2(.5, .1)
var energy = 0.0
# Worlds: how far the two worlds have been knocked apart by misses (0..1).
var drift = 0.0
var misses_seen = 0
# Stars: the constellation and the viewport it is painted into.
var sky: SubViewport
var constellation: Node2D
var gap_pending = false
var rng = RandomNumberGenerator.new()

static func stage_of(game: Node) -> String:
	var value = str(game.prefs.get_value("highway", "synk_stage", "aura"))
	return value if value in STAGES else "aura"

func _ready() -> void:
	sky = SubViewport.new(); sky.size = Vector2i(1280, 720); sky.transparent_bg = true
	sky.disable_3d = true; sky.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sky)
	constellation = preload("res://scripts/synk_constellation.gd").new(); sky.add_child(constellation)

func reset() -> void:
	hits.clear(); drift = 0.0; misses_seen = 0; gap_pending = false
	if constellation and not constellation.stars.is_empty():
		constellation.stars.clear(); repaint_sky()

func repaint_sky() -> void:
	constellation.queue_redraw()
	sky.render_target_update_mode = SubViewport.UPDATE_ONCE

# A note was hit at world position `at`.
func hit(at: Vector3, kind: String, color: Color) -> void:
	var view: Vector2 = world.get_viewport().get_visible_rect().size
	if view.y <= 0: return
	var point: Vector2 = world.camera.unproject_position(at) / view
	hits.push_front({"at": point, "age": 0.0, "kind": kind, "color": color})
	if hits.size() > 8: hits.resize(8)
	# Painting the constellation costs a viewport redraw per hit: only on its own stage.
	if stage_of(world.game) == "stars": add_star(point, color)

# A new star, in the sky on the hit's side of the highway, near the star before it.
func add_star(point: Vector2, color: Color) -> void:
	var stars: Array = constellation.stars
	if stars.size() >= MAX_STARS: return
	var left = point.x < vanish.x if absf(point.x - vanish.x) > .04 else rng.randf() < .5
	var y = rng.randf_range(vanish.y + .05, .72)
	if not stars.is_empty() and (stars[-1].at.x < vanish.x) == left:
		y = clampf(stars[-1].at.y + rng.randf_range(-.16, .16), vanish.y + .05, .72)
	# Keep clear of the highway, whose edge spreads out below the horizon.
	var edge = .56 * (y - vanish.y) + .04
	var x = rng.randf_range(.02, maxf(.03, vanish.x - edge)) if left else rng.randf_range(minf(.97, vanish.x + edge), .98)
	stars.append({"at": Vector2(x, y), "color": color, "gap": gap_pending})
	gap_pending = false
	repaint_sky()

func update(on: bool, delta: float) -> void:
	var backdrop: MeshInstance3D = world.cover_backdrop
	if backdrop == null: return
	if not on:
		if material != null and backdrop.material_override == material: backdrop.material_override = world.cover_material
		return
	var game = world.game
	if material == null:
		material = ShaderMaterial.new(); material.render_priority = -20
	var stage = stage_of(game)
	if material.shader != SHADERS[stage]:
		material.shader = SHADERS[stage]
		# Chosen mid-run: the sky starts empty and fills from here.
		if stage != "stars" and not constellation.stars.is_empty(): constellation.stars.clear()
	if backdrop.material_override != material: backdrop.material_override = material
	backdrop.visible = true
	var view: Vector2 = world.get_viewport().get_visible_rect().size
	if view.y <= 0: return
	# A new run starts with a clean stage.
	if int(game.judged) == 0 and (not constellation.stars.is_empty() or drift > 0.0): reset()
	var playing = game.mode == "play" and game.countdown <= 0 and game.resume_countdown <= 0
	# The highway's far end on screen: every stage is built around it.
	vanish = world.camera.unproject_position(Vector3(0, 0, -492.0 * world.SSRG_UNIT)) / view
	var beats = (world.render_time() - game.chart_offset()) * game.chart_bpm() / 60.0
	# Energy: SYNK mode has no rave, so the stage builds with the combo and drops on a miss.
	var target = clampf(float(game.combo) / 120.0, 0.0, 1.0)
	energy = lerpf(energy, target, 1.0 - exp(-delta * 3.0))
	material.set_shader_parameter("vanish", vanish)
	# The rails' lines on screen, so no stage draws under the highway between them.
	for side in [-1, 1]:
		var far: Vector2 = world.camera.unproject_position(Vector3(side * 27.0 * world.SSRG_UNIT, 0, -492.0 * world.SSRG_UNIT)) / view
		var near: Vector2 = world.camera.unproject_position(Vector3(side * 607.5 * world.SSRG_UNIT, 0, 86.0 * world.SSRG_UNIT)) / view
		material.set_shader_parameter("road_left" if side < 0 else "road_right", Vector4(far.x, far.y, near.x, near.y))
	material.set_shader_parameter("aspect", view.x / view.y)
	material.set_shader_parameter("beat", fposmod(beats, 1.0))
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("brightness", game.features.effect("Background brightness"))
	# Misses break the constellation's line and knock the two worlds apart.
	var misses = int(game.judgment_counts.get("MISS", 0))
	if misses > misses_seen:
		drift = minf(1.0, drift + .45 * (misses - misses_seen)); gap_pending = true
	misses_seen = misses
	if playing:
		for h in hits: h.age += delta
		drift = maxf(0.0, drift - delta * .22 * (1.0 + float(game.combo) / 40.0))
	match stage:
		"waves":
			material.set_shader_parameter("beats", beats)
			var ripples = PackedVector3Array()
			for i in 4:
				var live = i < hits.size() and hits[i].age < .7
				ripples.append(Vector3(hits[i].at.x, hits[i].at.y, hits[i].age) if live else Vector3(0, 0, -1))
			material.set_shader_parameter("hits", ripples)
		"worlds":
			material.set_shader_parameter("drift", drift)
		"stars":
			material.set_shader_parameter("sky", sky.get_texture())
			var stars: Array = constellation.stars
			var fresh = not stars.is_empty() and not hits.is_empty()
			material.set_shader_parameter("newest", Vector3(stars[-1].at.x, stars[-1].at.y, hits[0].age) if fresh else Vector3(0, 0, -1))
			if fresh: material.set_shader_parameter("newest_color", stars[-1].color)
		"strings":
			update_strings()

# Each hit plucks the row of strings on its side (both rows for a hit near the middle, and
# for every flick); the pluck reaches the far strings a moment later and rings out.
func update_strings() -> void:
	var pluck = PackedFloat32Array(); pluck.resize(STRINGS_PER_SIDE * 2)
	var tint = PackedColorArray(); tint.resize(STRINGS_PER_SIDE * 2)
	var loudest = PackedFloat32Array(); loudest.resize(STRINGS_PER_SIDE * 2)
	for h in hits:
		var flick = h.kind == "flick"
		var offset: float = h.at.x - vanish.x
		for k in STRINGS_PER_SIDE * 2:
			var left = k < STRINGS_PER_SIDE
			if not flick and absf(offset) > .05 and (offset < 0.0) != left: continue
			var j = k % STRINGS_PER_SIDE
			var since: float = h.age - j * .035
			if since < 0.0: continue
			var power = (1.0 if flick else .8 * exp(-j * .22)) * exp(-since * 3.2)
			pluck[k] = minf(1.2, pluck[k] + power)
			if power > loudest[k]:
				loudest[k] = power; tint[k] = h.color
	material.set_shader_parameter("pluck", pluck)
	material.set_shader_parameter("tint", tint)
