extends Node3D
# Rail notes (prototype). The two rails beside the road are a second place to play: a bar
# rides down a rail and is hit by touching the screen outside the road on that side, while
# the other hand keeps playing the lanes. A rail hold is kept down until its strip runs out.
#
# These notes are not in the chart. They are made up for each run from the song's beat
# (make_notes), so any chart can be tried with them. They are judged and scored like taps:
# a rail tap is one judgment, a rail hold is two (its start and its end).
const UNIT = 9.75/512.0
const RAIL_AT = 566.0*UNIT          # the note's centre, just outside the road's edge (512 units)
const NOTE_SIZE = Vector2(300.0,100.0)*UNIT   # the quad; the bar fills about a third of it
const STRIP_WIDTH = 132.0*UNIT
const TOUCH_FROM = 500.0*UNIT       # a touch this far from the road's middle is on the rail
const TAP_EVERY = 2.0               # beats between rail notes
const HOLD_BEATS = 2.0
const SIDE_BARS = 2                 # bars a side keeps the rail notes before they change side
const BUSY = .15                    # a lane note this close in time keeps that hand busy
const HOLD_GRACE = .2               # a rail hold may be let go this early
const COLOR = Color(.62,.91,1.0)

var world: Node3D
var game: Control
var items: Array = []               # {side, time, duration, head, strip, started, done, pointer, error}
var holding: Dictionary = {}        # pointer id -> item
var targets: Array = []
var target_flash = [0.0,0.0]
var shader = preload("res://scripts/rail_note.gdshader")

func enabled() -> bool:
	# Asked at the start of a run too, before the game is in play mode.
	return game != null and game.rail_notes_on and (game.ssrg_playable_run or game.highway_style in ["ssrg","synk"])

func piece(shape: int, mesh_size: Vector2, depth_steps: int = 0) -> MeshInstance3D:
	var node=MeshInstance3D.new(); var mesh=PlaneMesh.new(); mesh.size=mesh_size; mesh.subdivide_depth=depth_steps
	node.mesh=mesh
	var material=ShaderMaterial.new(); material.shader=shader; material.render_priority=5
	material.set_shader_parameter("shape",shape); material.set_shader_parameter("color",COLOR)
	node.material_override=material; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin=400.0; node.visible=false
	add_child(node)
	return node

func clear() -> void:
	for item in items:
		item.head.queue_free()
		if item.strip: item.strip.queue_free()
	items.clear(); holding.clear()

func total() -> int:
	var count=0
	for item in items: count+=2 if item.duration>0 else 1
	return count

func half_busy(notes: Array, side: int, from: float, to: float) -> bool:
	for n in notes:
		var start=float(n.time); var stop=start+float(n.get("duration",0.0))
		if stop<from-BUSY: continue
		if start>to+BUSY: break
		var lanes=[float(n.lane),float(n.get("end_lane",n.lane))]
		for point in n.get("path",[]): lanes.append(float(point.lane))
		for lane in lanes:
			if (side<0 and lane<SynkChart.MAX_LANE*.5+.5) or (side>0 and lane>SynkChart.MAX_LANE*.5-.5): return true
	return false

# Makes this run's rail notes: one every TAP_EVERY beats on the side whose hand is free, the
# last of every fourth bar a hold, changing side every SIDE_BARS bars.
func start(notes: Array, range_from: float, range_to: float) -> void:
	clear()
	if not enabled() or notes.is_empty(): return
	var beat=60.0/maxf(30.0,game.chart_bpm())
	var offset=float(game.chart_config().get("beat_offset",0.0))
	var first=maxf(float(notes[0].time),range_from)+beat*4.0
	var last=minf(float(notes[-1].time),range_to)
	var index=ceili((first-offset)/(beat*TAP_EVERY))
	var hold_until=-INF
	while true:
		var at=offset+index*beat*TAP_EVERY
		if at>last: break
		var bar=floori(index*TAP_EVERY/4.0)
		var side=-1 if (bar/SIDE_BARS)%2==0 else 1
		var wants_hold=bar%4==3 and int(index*TAP_EVERY)%4==0
		index+=1
		if at<hold_until+beat*.5: continue
		var length=HOLD_BEATS*beat if wants_hold else 0.0
		if half_busy(notes,side,at,at+length):
			side=-side
			if half_busy(notes,side,at,at+length):
				if length==0.0 or half_busy(notes,side,at,at): continue
				length=0.0
		var item={"side":side,"time":at,"duration":length,"started":false,"done":false,"missed":false,"pointer":-999,"error":0.0,
			"head":piece(0,NOTE_SIZE),"strip":piece(1,Vector2(STRIP_WIDTH,1.0),40) if length>0 else null}
		items.append(item)
		if length>0: hold_until=at+length
	if targets.is_empty():
		for side in [-1,1]:
			var mark=piece(2,NOTE_SIZE); mark.position=Vector3(side*RAIL_AT,.2,0); targets.append(mark)

func judge_item(item: Dictionary, at: float, error: float) -> void:
	var note=SynkChart.note(at,0 if item.side<0 else SynkChart.MAX_LANE,"tap")
	var entry={"note":note,"key":"rail","started":true,"done":false,"pointer":item.pointer,"error":maxf(error,0.0),"timing_error":game.song_time-at}
	game.judge(entry,error,true,"",false)
	if error>=0: target_flash[0 if item.side<0 else 1]=1.0

func press(item: Dictionary, id: int, error: float) -> void:
	item.started=true; item.pointer=id; item.error=error
	judge_item(item,float(item.time),error)
	if item.duration>0: holding[id]=item
	else: item.done=true

func finish(item: Dictionary, kept: bool) -> void:
	if item.done: return
	item.done=true
	if not kept: item.missed=true
	judge_item(item,float(item.time)+float(item.duration),minf(float(item.error),game.extras.great_window()) if kept else -1.0)
	holding.erase(item.pointer)

# A finger event during play. Returns true when the touch belongs to a rail (the lanes then
# never see it).
func pointer(id: int, point: Vector3, began: bool, ended: bool, at: float) -> bool:
	if items.is_empty(): return false
	if holding.has(id):
		if ended:
			var item: Dictionary=holding[id]
			finish(item,at>=float(item.time)+float(item.duration)-HOLD_GRACE)
		return true
	if not began or absf(point.x)<TOUCH_FROM: return false
	var side=-1 if point.x<0 else 1
	var best: Dictionary={}; var best_error=game.hit_good_window("tap")
	for item in items:
		if float(item.time)>at+best_error: break
		if item.started or item.done or item.side!=side: continue
		var error=absf(at-float(item.time))
		if error<=best_error: best_error=error; best=item
	if best.is_empty(): return false
	press(best,id,best_error)
	return true

# Once a frame during play: notes nobody touched are missed, holds kept to their end are
# completed, and auto play hits everything on time.
func judge_frame(now: float, automated: bool) -> void:
	if items.is_empty(): return
	var window=game.hit_good_window("tap")
	for item in items:
		if float(item.time)>now+.001: break
		if item.done: continue
		if not item.started:
			if automated: press(item,-999,0.0)
			elif now>float(item.time)+window:
				item.started=true; item.pointer=-999; item.missed=true
				judge_item(item,float(item.time),-1.0)
				if item.duration>0: finish(item,false)
				else: item.done=true
		elif item.duration>0 and now>=float(item.time)+float(item.duration):
			finish(item,true)

func draw(delta: float) -> void:
	var playing=enabled() and game.mode in ["play","paused"] and not items.is_empty()
	visible=playing
	if not playing:
		if not items.is_empty() and game.mode not in ["play","paused"]: clear()
		return
	var now: float=world.render_time(); var speed: float=world.travel_speed(); var far: float=-world.TRACK_LENGTH
	for index in targets.size():
		target_flash[index]=maxf(0.0,target_flash[index]-delta*4.0)
		targets[index].visible=true
		targets[index].material_override.set_shader_parameter("strength",.55+target_flash[index]*2.4)
	for item in items:
		var head_z=(now-float(item.time))*speed
		var tail_z=(now-float(item.time)-float(item.duration))*speed
		var head: MeshInstance3D=item.head
		# Gone: not yet on the road, well past the line, or played. A missed note runs on, dimmed.
		if head_z<far or tail_z>4.0 or (item.started and not item.missed and (item.done or item.duration==0.0)):
			head.visible=false
			if item.strip: item.strip.visible=false
			continue
		var held: bool=item.started and not item.done and not item.missed
		var light=1.5 if held else (.35 if item.missed else 1.0)
		# A held note's bar waits on the judgment line while its strip runs into it.
		head.visible=held or head_z<=4.0
		head.position=Vector3(item.side*RAIL_AT,.2,0.0 if held else head_z)
		head.material_override.set_shader_parameter("strength",light)
		if item.strip:
			var strip: MeshInstance3D=item.strip
			var near=minf(head_z,0.0) if held else head_z
			var back=maxf(tail_z,far)
			strip.visible=near>back+.01
			strip.position=Vector3(item.side*RAIL_AT,.19,(near+back)*.5); strip.scale=Vector3(1,1,maxf(.01,near-back))
			strip.material_override.set_shader_parameter("strength",light)
