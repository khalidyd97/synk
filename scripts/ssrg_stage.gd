extends Node3D
var receptors: Array = []
var press: MeshInstance3D
var rails: Array = []
var old_rails: Array = []
var old_rail_glows: Array = []
var old_rail_dots: Array = []
var entrance_shadow: MeshInstance3D
var feedback_marks:Array=[]
var feedback_states:Dictionary={}
const TRACK_REACH = 1500.0
const RECORDER_BAND = Color(.957,.945,.918,.2)
const OLD_RAIL_TOP=Vector2(0,280)
const OLD_RAIL_BOTTOM_Y=-400.0
const OLD_RAIL_BOTTOM_X=663.0
func _init() -> void :
	name = "SSRGStage"
	# Direct original UI canvas: world Z = -(UI y + 234) * UNIT.
	const UNIT = 9.75/512.0
	# A stationary veil over the distant entrance lets notes emerge gradually.
	entrance_shadow=MeshInstance3D.new();entrance_shadow.name="HighwayEntranceShadow"
	var shadow_plane=PlaneMesh.new();shadow_plane.size=Vector2(1440,600)*UNIT
	entrance_shadow.mesh=shadow_plane
	entrance_shadow.position=Vector3(0,.3,-214*UNIT)
	entrance_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow_material=ShaderMaterial.new()
	shadow_material.shader=preload("res://scripts/ssrg_entrance_shadow.gdshader")
	shadow_material.set_shader_parameter("rail_art",preload("res://assets/ssrg/imported/rail_original.png"))
	shadow_material.render_priority=3
	entrance_shadow.material_override=shadow_material;add_child(entrance_shadow)
	for side in [-1,1]:
		# Original BottomRight-pivot sprite at (0,-320), mirrored on the right.
		var rail=MeshInstance3D.new(); var quad=QuadMesh.new()
		quad.size=Vector2(720,578)*UNIT; rail.mesh=quad
		rail.position=Vector3(side*360*UNIT,.09,-203*UNIT)
		rail.rotation_degrees.x=-90
		if side>0: rail.scale.x=-1
		var mat=ShaderMaterial.new(); mat.shader=preload("res://scripts/ssrg_stage.gdshader")
		mat.render_priority=-8
		mat.set_shader_parameter("artwork",preload("res://assets/ssrg/imported/rail_original.png"))
		mat.set_shader_parameter("along_rail",false)
		rail.material_override=mat; add_child(rail); rails.append(rail)
		var old_rail=make_old_rail(side,UNIT)
		add_child(old_rail);old_rails.append(old_rail)
		var old_glow=make_old_rail_glow(side,UNIT)
		add_child(old_glow);old_rail_glows.append(old_glow)
		var old_dot=make_old_rail_dot(side,UNIT)
		add_child(old_dot);old_rail_dots.append(old_dot)
	press=MeshInstance3D.new(); var plane=PlaneMesh.new()
	plane.size=Vector2(1156,130)*UNIT; press.mesh=plane
	press.position=Vector3(-5*UNIT,.035,16*UNIT)
	var mat=ShaderMaterial.new(); mat.shader=preload("res://scripts/ssrg_press.gdshader")
	mat.set_shader_parameter("artwork",preload("res://assets/ssrg/imported/judgment_Main_black_BG3.png"))
	mat.set_shader_parameter("base_color",Color8(255,220,65,149)); mat.render_priority=-7
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
		var feedback=ring.duplicate() as MeshInstance3D
		feedback.name="TouchFeedback"+str(lane)
		feedback.material_override=material.duplicate();feedback.material_override.render_priority=5
		add_child(feedback);feedback_marks.append(feedback)

func make_old_rail(side:int, unit:float) -> MeshInstance3D:
	# The 2014 rail is a broad silver strip with a narrow red line on its
	# highway-facing edge. Its center follows the recovered 2D rail boundary.
	var start=OLD_RAIL_TOP;var finish=Vector2(side*OLD_RAIL_BOTTOM_X,OLD_RAIL_BOTTOM_Y)
	var direction=(finish-start).normalized()
	var normal=Vector2(-direction.y,direction.x)
	var points=[start-normal*2.5,start+normal*2.5,finish-normal*30.0,finish+normal*30.0]
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,1,2,2,1,3]:
		var point:Vector2=points[index]
		surface.set_uv(Vector2(0.0 if index<2 else 1.0,0.0 if index%2==0 else 1.0))
		surface.add_vertex(Vector3(point.x*unit,.11,-(point.y+234.0)*unit))
	var rail=MeshInstance3D.new();rail.mesh=surface.commit()
	rail.name="OldRailLeft" if side<0 else "OldRailRight"
	var material=ShaderMaterial.new();material.shader=preload("res://scripts/ssrg_old_rail.gdshader")
	material.render_priority=-6
	material.set_shader_parameter("inner_at_high_uv",side<0)
	rail.material_override=material
	rail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rail.visible=false
	return rail

func make_old_rail_glow(side:int, unit:float) -> MeshInstance3D:
	var centers=old_rail_light_centers(side)
	var top_center:Vector2=centers[0];var bottom_center:Vector2=centers[1]
	var normal=Vector2(-(bottom_center-top_center).normalized().y,(bottom_center-top_center).normalized().x)
	var points=[top_center-normal*.5,top_center+normal*.5,bottom_center-normal*4.2,bottom_center+normal*4.2]
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,1,2,2,1,3]:
		var point:Vector2=points[index]
		surface.set_uv(Vector2(0.0 if index<2 else 1.0,0.0 if index%2==0 else 1.0))
		surface.add_vertex(Vector3(point.x*unit,.12,-(point.y+234.0)*unit))
	var glow=MeshInstance3D.new();glow.mesh=surface.commit()
	glow.name="OldRailGlowLeft" if side<0 else "OldRailGlowRight"
	var material=ShaderMaterial.new();material.shader=preload("res://scripts/ssrg_old_rail_glow.gdshader")
	material.render_priority=-5
	material.set_shader_parameter("artwork",preload("res://assets/ssrg/old_ui/track/Main_side line_01.png"))
	glow.material_override=material
	glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visible=false
	return glow

func old_rail_light_centers(side:int) -> Array:
	var start=OLD_RAIL_TOP;var finish=Vector2(side*OLD_RAIL_BOTTOM_X,OLD_RAIL_BOTTOM_Y)
	var normal=Vector2(-(finish-start).normalized().y,(finish-start).normalized().x)
	# In the 2014 close-up the colored line lies toward the outside third of
	# the silver rail, leaving the wider pale band on the highway-facing side.
	var inward=1.0 if side<0 else -1.0
	var top_center=start-normal*inward*.95
	var bottom_center=finish-normal*inward*11.4
	return [top_center,bottom_center]

func make_old_rail_dot(side:int, unit:float) -> MeshInstance3D:
	var dot=MeshInstance3D.new();var quad=QuadMesh.new()
	quad.size=Vector2(255,255)*unit;dot.mesh=quad
	dot.name="OldRailDotLeft" if side<0 else "OldRailDotRight"
	var material=ShaderMaterial.new();material.shader=preload("res://scripts/ssrg_old_rail_dot.gdshader")
	material.render_priority=-4
	material.set_shader_parameter("artwork",preload("res://assets/ssrg/old_ui/side_light/Main_side light_R.png"))
	var start=OLD_RAIL_TOP;var finish=Vector2(side*OLD_RAIL_BOTTOM_X,OLD_RAIL_BOTTOM_Y)
	material.set_shader_parameter("rail_start",Vector2(start.x*unit,-(start.y+234.0)*unit))
	material.set_shader_parameter("rail_end",Vector2(finish.x*unit,-(finish.y+234.0)*unit))
	material.set_shader_parameter("rail_half_widths",Vector2(2.5,30.0)*unit)
	dot.material_override=material
	dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.visible=false
	return dot


# SSRG's bottom bar is 130 of 640 screen units tall, centred 250 units below the middle
# (79% to 99% down the screen). Cover that same screen band on the floor, whatever the view.
const BAND_TOP = .5 + 185.0/640.0
const BAND_BOTTOM = .5 + 315.0/640.0
func update(world: Node3D) -> void :
	if not visible: return
	if world.game.old_ssrg_ui():
		var presentation=world.game.ssrg_presentation
		var rave_color:Color=presentation.beam_color if presentation and presentation.active else Color8(255,67,88)
		var chosen=world.custom_color("rail_color")
		if chosen!=null:rave_color=chosen
		for rail in old_rail_glows:
			rail.material_override.set_shader_parameter("accent",rave_color)
			rail.material_override.set_shader_parameter("motion_time",world.game.hud_motion_time)
		var travel=.5+.45*sin(world.game.hud_motion_time*1.5)
		for index in old_rail_dots.size():
			var dot:MeshInstance3D=old_rail_dots[index]
			var centers=old_rail_light_centers(-1 if index==0 else 1)
			var point:Vector2=centers[0].lerp(centers[1],travel)
			dot.position=Vector3(point.x*(9.75/512.0),.16,-(point.y+234.0)*(9.75/512.0))
			dot.rotation=world.camera.rotation
			dot.material_override.set_shader_parameter("accent",rave_color)
	for receptor in receptors: receptor.hide()
	for mark in feedback_marks:mark.hide()
	var game = world.game
	if game.countdown>0 or not (game.mode == "play" or (game.mode == "paused" and game.paused_mode == "play")): return
	var now: float = world.render_time()
	update_touch_feedback(world)
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

func clear_touch_feedback() -> void:
	feedback_states.clear()
	for mark in feedback_marks:mark.hide()

func update_touch_feedback(world:Node3D) -> void:
	var game=world.game
	if not game.ssrg_playable_run:return
	var retained:Dictionary={};var index=0
	var intensity=clampf(game.features.effect("Hit flashes"),0.0,1.0)
	for i in range(game.first_live_index(),game.live.size()):
		var entry:Dictionary=game.live[i]
		if float(entry.note.time)>game.song_time+.3:break
		if entry.done or not entry.started or entry.note.kind not in ["hold","slide"]:continue
		var contact=bool(entry.get("ssrg_contact",true))
		var state:Dictionary=feedback_states.get(entry.key,{"contact":true,"regrab_at":-INF})
		if contact and not state.contact:state.regrab_at=game.hud_motion_time
		state.contact=contact;retained[entry.key]=state
		var age=game.hud_motion_time-float(state.regrab_at)
		if contact and age>=.22:continue
		if index>=feedback_marks.size():break
		var mark:MeshInstance3D=feedback_marks[index];index+=1
		mark.position=Vector3(world.note_x(SynkChart.lane_at(entry.note,game.song_time)),.25,0)
		mark.rotation=world.camera.rotation
		var pop=clampf(age/.22,0.0,1.0) if contact else 0.0
		mark.scale=Vector3.ONE*(1.0+pop*.18)
		mark.material_override.set_shader_parameter("tint",Color("70edff") if contact else Color("ffc76b"))
		mark.material_override.set_shader_parameter("progress",intensity*((1.0-pop) if contact else .45))
		mark.visible=intensity>0
	feedback_states=retained

func warmup(world: Node3D) -> void :
	if not visible: return
	var receptor: MeshInstance3D = receptors[0]
	receptor.position.x = 0;receptor.rotation = world.camera.rotation
	receptor.material_override.set_shader_parameter("progress", 1.0);receptor.show()

func configure(world: Node3D) -> void :
	var stock_road = true
	var old_ui=world.game.old_ssrg_ui()
	press.visible = stock_road
	press.material_override.set_shader_parameter("artwork",preload("res://assets/ssrg/old_ui/track/Main_black BG3.png") if old_ui else preload("res://assets/ssrg/imported/judgment_Main_black_BG3.png"))
	entrance_shadow.visible=not old_ui
	for ring in receptors:ring.material_override.set_shader_parameter("artwork",preload("res://assets/ssrg/old_ui/track/note_guide 01.png") if old_ui else preload("res://assets/ssrg/imported/guide_original.png"))
	for mark in feedback_marks:mark.material_override.set_shader_parameter("artwork",preload("res://assets/ssrg/old_ui/track/note_guide 01.png") if old_ui else preload("res://assets/ssrg/imported/guide_original.png"))
	# Source gold tier, unless the player picked a judgment band color.
	var band = world.custom_color("band_color")
	press.material_override.set_shader_parameter("base_color",(Color(band,.82) if band != null else Color8(255,75,91,210)) if old_ui else Color8(255,220,65,149))
	# The recorder keeps the line readable without the loud gold: a faint cream strip.
	if world.game.uses_skd_recorder_surface(): press.material_override.set_shader_parameter("base_color",RECORDER_BAND)
	var rail_tint = world.custom_color("rail_color")
	if rail_tint == null: rail_tint = Color.WHITE
	for rail in rails:
		rail.visible = stock_road and not old_ui
		rail.material_override.set_shader_parameter("tint", rail_tint)
		rail.material_override.set_shader_parameter("floor_opacity",clampf(float(world.game.highway_opacity),.3,1.6))
		rail.material_override.set_shader_parameter("floor_tint",world.element_color("track",Color.BLACK))
	for rail in old_rails:
		rail.visible=stock_road and old_ui
	for rail in old_rail_glows:
		rail.visible=stock_road and old_ui
	for dot in old_rail_dots:
		dot.visible=stock_road and old_ui
