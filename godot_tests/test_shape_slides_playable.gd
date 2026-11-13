extends SceneTree
# Hold shapes are playable by a person: every shape, from short and long holds, is played
# through the real SSRG judge by a simulated finger that trails the slide by 60 ms and
# moves at most 45 lanes a second. No head or end may be missed.
var game
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func lane_point(lane:float) -> Vector2:
	var world=game.field.world
	return world.camera.unproject_position(Vector3(world.note_x(lane),.035,0))/Vector2(game.field.viewport.size)
func _initialize():run.call_deferred()
func play(notes:Array,lag:float,cap:float) -> Dictionary:
	game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.judged=0
	game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0};game.field.world.clear_hit_effects();game.pending_end_hits.clear()
	game.live=[]
	for i in notes.size(): game.live.append({"note":notes[i],"key":"s%d"%i,"started":false,"done":false,"pointer":-999,"error":0.0})
	var fingers={}
	var t=float(notes[0].time)-.1; var dt=1.0/60.0
	var finish=0.0
	for n in notes: finish=maxf(finish,float(n.time)+float(n.duration))
	while t<finish+.5:
		game.song_time=t
		for i in notes.size():
			var n=notes[i]; var id=40+i
			var start=float(n.time); var end=start+float(n.duration)
			if not fingers.has(i) and t>=start-.01:
				fingers[i]={"lane":float(n.lane),"up":false}
				game.pointer_event(id,lane_point(float(n.lane)),true,false,false)
			elif fingers.has(i) and not fingers[i].up:
				var f=fingers[i]
				f.lane=move_toward(f.lane,SynkChart.lane_at(n,clampf(t-lag,start,end)),cap*dt)
				if t>=end+.03: f.up=true; game.pointer_event(id,lane_point(f.lane),false,true,false)
				else: game.pointer_event(id,lane_point(f.lane),false,false,false)
		game.update_game()
		t+=dt
	var result=game.judgment_counts.duplicate(); result.judged=game.judged
	return result
func run():
	root.size=Vector2i(1600,740)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.auto_play=false;game.set_mode("play");game.countdown=0
	game.field.sync_projection_style();game.field.world.apply_camera()
	var Glyphs=preload("res://scripts/slide_glyphs.gd")
	var bad=[]
	for duration in [.4,.8,1.5]:
		for lane in [2,6,10]:
			for c in Glyphs.SHAPE_ORDER:
				var notes=Glyphs.shape_notes(c,1.0,duration,lane)
				var r=play(notes,.06,45.0)
				if r.MISS>0 or r.judged<notes.size()*2: bad.append("%s %.1fs lane %d"%[c,duration,lane])
	check(bad.is_empty(),"A person can play every hold shape: "+", ".join(bad))
	print("Shape slides playable: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free();await process_frame;quit(failures)
