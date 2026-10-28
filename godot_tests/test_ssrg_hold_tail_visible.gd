extends SceneTree
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.stage_intro_enabled=false; game.note_speed=1; game.note_size=1.0; game.recorder_note_speed=1
	var hold=SynkChart.note(3,4,"hold"); hold.duration=1.0
	game.start_game([hold],true)
	game.countdown=0
	var world=game.field.world
	var entry:Dictionary=game.live[0]
	check(game.uses_ssrg_gameplay(),"Normal play uses SSRG gameplay")
	# Completed a little before the tail reaches the line (early release or render lag).
	game.song_time=3.9; entry.started=true; entry.done=true
	world._process(0.0)
	check(world.notes.has(entry.key) and world.notes[entry.key].node.visible,"Completed hold keeps drawing until its tail reaches the line")
	game.song_time=4.05
	world._process(0.0)
	check(not (world.notes.has(entry.key) and world.notes[entry.key].node.visible),"Completed hold hides once its tail has passed")
	game.queue_free(); await process_frame
	if failures==0: print("SSRG hold tail visibility: PASS")
	quit(failures)
