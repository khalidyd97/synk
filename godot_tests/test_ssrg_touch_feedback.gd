extends SceneTree
var game
func _initialize():run.call_deferred()
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.set_mode("play");game.countdown=0;game.song_time=2;game.hud_motion_time=1
	var world=game.field.world;var stage=world.ssrg_theme.original_stage
	var note=SynkChart.note(1,4,"hold");note.duration=3
	var entry={"key":"feedback","note":note,"started":true,"done":false,"ssrg_contact":true}
	game.live=[entry];game.live_cursor=0
	stage.update(world)
	assert(stage.feedback_marks.all(func(mark):return not mark.visible))
	entry.ssrg_contact=false;stage.update(world)
	assert(stage.feedback_marks[0].visible)
	assert(stage.feedback_marks[0].material_override.get_shader_parameter("tint")==Color("ffc76b"))
	entry.ssrg_contact=true;game.hud_motion_time=1.2;stage.update(world)
	assert(stage.feedback_marks[0].visible)
	assert(stage.feedback_marks[0].material_override.get_shader_parameter("tint")==Color("70edff"))
	game.set_mode("paused");stage.update(world)
	assert(stage.feedback_marks[0].visible,"Pause freezes re-grab feedback")
	game.hud_motion_time=1.5;stage.update(world)
	assert(not stage.feedback_marks[0].visible)
	entry.ssrg_contact=false;stage.update(world);entry.done=true;stage.update(world)
	assert(not stage.feedback_marks[0].visible and stage.feedback_states.is_empty(),"Miss/completion retires recoverable marker")
	stage.clear_touch_feedback();assert(stage.feedback_states.is_empty())
	print("SSRG hold loss/re-grab feedback, lifetime, pause and cleanup passed")
	game.queue_free();await process_frame;quit()
