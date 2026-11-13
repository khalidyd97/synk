extends SceneTree
# Pressing Play must not draw the whole stage for the first time in one frame. Behind the
# loading card the camera draws one small stand-in per shader, a frame apiece, including the
# pieces that only show later in the song; the stage appears once they are all prepared.
var failures=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func shader_key(world,material:Material,instanced:String="-") -> String:
	return "%s:%s" % [world.warm_program(material),instanced]
func run() -> void:
	root.size=Vector2i(1440,640)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	for child in game.get_children():
		if child is CanvasLayer and child.layer>=100:child.hide()
	game.highway_style="ssrg";game.hit_style="ssrg";game.stage_intro_enabled=true;game.auto_play=true
	var world=game.field.world
	var normal_mask=world.camera.cull_mask
	var notes=[SynkChart.note(4.0,3),SynkChart.note(4.5,9)]
	var hold=SynkChart.note(5.0,6,"hold");hold.duration=1.0;notes.append(hold)
	var slide=SynkChart.note(6.5,2,"slide");slide.duration=1.0;slide.end_lane=8
	slide.path=[{"offset":0.0,"lane":2.0},{"offset":1.0,"lane":8.0}];notes.append(slide)
	game.start_game(notes,true)
	check(world.warming and world.camera.cull_mask==world.WARM_LAYER,"The stage is held back when a song starts from a menu")
	check(game.stage_intro.visible and game.stage_intro.build_progress()<1.0,"The loading card waits for the shaders")
	var frames=0;var most_at_once=0;var covered=true
	while world.warming and frames<900:
		await process_frame;frames+=1
		var shown=0
		for child in world.camera.get_children():
			if child is GeometryInstance3D and child.layers==world.WARM_LAYER and not child.is_queued_for_deletion():shown+=1
		most_at_once=maxi(most_at_once,shown)
		if world.warming and not game.stage_intro.visible:covered=false
	check(not world.warming and frames<900,"The warm-up finishes")
	check(covered,"The loading card stays up for the whole warm-up")
	check(most_at_once==1,"One stand-in is drawn per frame")
	check(world.camera.cull_mask==normal_mask,"The stage is drawn normally afterwards")
	check(not is_instance_valid(world.warm_stand_in),"No stand-in is left behind")
	check(world.warm_total>=6 and frames>=world.warm_total,"Each shader gets its own frame (%d shaders, %d frames)" % [world.warm_total,frames])
	var stage=world.ssrg_theme.original_stage
	check(world.warm_seen.has(shader_key(world,stage.receptors[0].material_override)),"Lane guides are prepared before they first appear")
	check(world.warm_seen.has(shader_key(world,world.ssrg_finger_beam_material)),"Touch beams are prepared before the first touch")
	var background:MultiMeshInstance3D=world.ssrg_theme.source_background.find_children("*","MultiMeshInstance3D",true,false)[0]
	check(world.warm_seen.has(shader_key(world,background.material_override,"%d%d%d" % [background.multimesh.transform_format,int(background.multimesh.use_colors),int(background.multimesh.use_custom_data)])),"Background particles are prepared before the countdown ends")
	check(world.warm_seen.has(shader_key(world,world.ssrg_theme.hit_pool[0].material)),"Hit flashes are prepared before the first hit")
	check(is_equal_approx(game.stage_intro.build_progress(),world.prebuild_progress()),"The loading bar is free to finish")
	# A later song has nothing new to prepare.
	var known=world.warm_seen.size()
	game.set_mode("menu");await process_frame
	game.start_game(notes,true)
	frames=0
	while world.warming and frames<900:
		await process_frame;frames+=1
	check(not world.warming and world.warm_total==0 and world.warm_seen.size()==known,"A second song prepares nothing again")
	# Leaving during the loading card gives the camera back.
	game.set_mode("menu");await process_frame
	game.start_game(notes,true)
	check(world.warming,"Held back again for the next song")
	game.set_mode("menu");await process_frame;await process_frame
	check(not world.warming and world.camera.cull_mask==normal_mask,"Leaving the loading card restores the camera")
	# The Lumen hit style on SYNK's own look is prepared too.
	game.highway_style="gold";game.hit_style="lumen";world.refresh_highway_look()
	game.start_game(notes,true)
	frames=0
	while world.warming and frames<900:
		await process_frame;frames+=1
	check(not world.warming and world.camera.cull_mask==normal_mask,"The Lumen look warms up and finishes (%d shaders)" % world.warm_total)
	check(world.ssrg_theme.hit_pool[0].style=="lumen" and world.warm_seen.has(shader_key(world,world.ssrg_theme.hit_pool[0].material)),"Lumen flashes are prepared before the first hit")
	var plain=StandardMaterial3D.new();var same=StandardMaterial3D.new();same.albedo_color=Color.RED
	var other=StandardMaterial3D.new();other.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	check(world.warm_program(plain)==world.warm_program(same) and world.warm_program(plain)!=world.warm_program(other),"Built-in materials are told apart by their switches, not their colours")
	game.set_mode("menu");await process_frame;await process_frame
	# Restarting mid-song has no loading card, so nothing is held back.
	game.stage_intro_enabled=false
	game.start_game(notes,true)
	check(not world.warming and world.camera.cull_mask==normal_mask,"Without a loading card the stage shows at once")
	print("First-draw warm-up failures: %d" % failures)
	game.queue_free();await process_frame
	quit(failures)
