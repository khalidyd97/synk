extends SceneTree
# Space close chords: notes played together keep at least one empty lane between them.
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func x_for(lane: int) -> float: return (float(lane)+.5)/SynkChart.LANES*.86+.07
func chord(lanes: Array,gap: float) -> Array:
	var c=SynkCapture.new(); c.minimum_lane_gap=gap
	for i in lanes.size(): c.begin(i,1.0,Vector2(x_for(lanes[i]),.8))
	for i in lanes.size(): c.end(i,1.05,Vector2(x_for(lanes[i]),.8))
	var result=c.notes.map(func(n): return int(n.lane)); result.sort(); return result
func run() -> void:
	check(chord([2,3],2.0)==[2,4],"Lanes 2 and 3 become 2 and 4")
	check(chord([6,5],2.0)==[4,6] or chord([6,5],2.0)==[6,8] or chord([6,5],2.0)==[3,5] or chord([6,5],2.0)==[5,7],"Any adjacent pair is pulled one lane apart")
	check(chord([2,3,4],2.0)==[2,4,6],"Three neighbours spread to every other lane")
	var edge=chord([11,12],2.0)
	check(edge.size()==2 and edge[1]-edge[0]>=2 and edge[1]<=12,"At the edge the chord still gets its gap inside the lanes")
	check(chord([2,4],2.0)==[2,4],"A chord that already has a gap stays put")
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false)
	check(game.space_close_chords and game.chord_lane_gap()>=2.0,"Space close chords is on by default")
	var before=game.space_close_chords
	game.toggle_space_close_chords()
	check(not game.space_close_chords and is_equal_approx(game.chord_lane_gap(),game.authoring_lane_gap()) and game.space_chords_button.text.ends_with("off"),"Turning it off goes back to body-width spacing")
	game.toggle_space_close_chords()
	check(game.space_close_chords==before,"The option toggles back on")
	print("Space close chords: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free(); await process_frame; quit(failures)
