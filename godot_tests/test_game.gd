extends SceneTree

var failures=0
func check(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await process_frame; await process_frame
	check(game.mode=="menu" and game.lobby.visible and not game.modal.visible,"Main scene boots to the lobby")
	check(game.lobby.play_button.visible and game.lobby.play_button.art.texture!=null and game.lobby.play_button.art.material is ShaderMaterial,"Lobby PLAY uses the animated reference artwork")
	check(game.lobby.guide_button.backdrop.material is ShaderMaterial and game.lobby.guide_button.caption.text=="NOTE GUIDE","Other lobby buttons share the animated neon treatment")
	check(game.lobby.get_child(3).anchor_left<.05,"Lobby cover uses the space previously occupied by the left button rail")
	game.lobby.play_button.animate_hover(1.0)
	await create_timer(.24).timeout
	check(game.lobby.play_button.art_material.get_shader_parameter("hover_amount")>.9,"PLAY glow animates on hover")
	game.lobby.play_button.animate_hover(0.0)
	check(game.waveform.size()==512,"Waveform samples decoded")
	game.lobby.guide_button.pressed.emit()
	check(game.mode=="guide" and game.guide_back.visible and not game.modal.visible,"Note guide opens from the menu")
	game.guide_back.pressed.emit()
	check(game.mode=="menu" and game.lobby.visible,"Note guide returns to the lobby")
	game.open_lobby_settings()
	check(game.modal.visible and game.primary.text=="DONE","Lobby settings open in their own panel")
	check(game.settings_panel.visible and game.bluetooth_toggle!=null and game.bluetooth_latency_input!=null,"Settings expose Bluetooth sync controls")
	var initial_bluetooth_mode=game.bluetooth_mode
	var initial_bluetooth_latency=game.bluetooth_latency_ms
	game.bluetooth_latency_input.value=215
	game.bluetooth_toggle.button_pressed=true
	check(game.bluetooth_latency_input.editable and is_equal_approx(game.effective_timing_ms(),game.timing_ms-215),"Bluetooth mode delays the chart timeline by the configured latency")
	game.bluetooth_toggle.button_pressed=false
	check(is_equal_approx(game.effective_timing_ms(),game.timing_ms) and not game.bluetooth_latency_input.editable,"Disabling Bluetooth mode restores regular timing")
	game.bluetooth_latency_input.value=initial_bluetooth_latency
	game.bluetooth_toggle.button_pressed=initial_bluetooth_mode
	game.primary.pressed.emit()
	check(not game.modal.visible and game.lobby.visible,"Lobby settings close back to the lobby")
	game.start_game([SynkChart.note(1,6)])
	game.toggle_pause()
	await create_timer(.03).timeout
	check(game.pause_home.visible and game.pause_restart.visible and game.primary.text=="RESUME","Pause offers Resume, Restart and Home")
	check(game.primary.caption.text=="RESUME","Animated pause button updates its visible label")
	check(not game.settings_panel.visible,"Pause menu contains no settings controls")
	check(game.modal.scale.x<1.0 and game.pause_backdrop.visible,"Pause menu begins its entrance animation")
	game.primary.pressed.emit()
	check(game.mode=="play" and game.resume_countdown==3.0 and not game.audio.playing,"Resume freezes play for a fresh countdown")
	game._process(1.01); check(game.countdown_label.visible and game.countdown_label.text=="2","Resume shows two")
	game._process(1.01); check(game.countdown_label.text=="1","Resume shows one")
	game._process(1.01); check(game.resume_countdown==0 and game.audio.playing and not game.audio.stream_paused,"Resume starts playback after countdown")
	game.toggle_pause()
	game.pause_restart.pressed.emit()
	check(game.mode=="play" and game.countdown>0 and game.score==0,"Restart begins the chart again")
	game.toggle_pause()
	game.pause_home.pressed.emit()
	check(game.mode=="menu" and not game.audio.playing and not game.audio.stream_paused and game.live.is_empty(),"Home stops the run and returns to the menu")
	check(not game.pause_home.visible,"Home option is hidden outside pause")
	game.start_game([SynkChart.note(8,6)]); game.countdown=0; game.audio.play(4); game.song_time=4
	game.toggle_pause()
	check(game.pause_had_audio and game.audio.stream_paused,"Pausing remembers active playback")
	var previous_bluetooth_mode=game.bluetooth_mode
	var previous_bluetooth_latency=game.bluetooth_latency_ms
	game.change_bluetooth_mode(false); game.change_bluetooth_latency(200)
	var time_before_headset=game.song_time
	game.change_bluetooth_mode(true)
	check(is_equal_approx(game.song_time,time_before_headset-.2),"Changing Bluetooth delay while paused realigns the chart immediately")
	game.change_bluetooth_mode(false); game.change_bluetooth_latency(previous_bluetooth_latency); game.change_bluetooth_mode(previous_bluetooth_mode)
	game.toggle_pause()
	check(not game.resume_start_audio and game.resume_countdown==3,"Resume countdown retains active playback")
	game._process(3.1)
	check(game.audio.playing and not game.audio.stream_paused,"Active song resumes after the countdown")
	game.audio.stop()
	game.visual_clock_ready=false; game.smooth_visual_time(5.0,.016); game.smooth_visual_time(5.02,.016)
	var previous_visual=game.visual_song_time
	game.smooth_visual_time(5.01,.016)
	check(game.visual_song_time>=previous_visual,"Audio-clock jitter does not move falling notes backward")
	game.smooth_visual_time(5.3,.016)
	check(is_equal_approx(game.visual_song_time,5.3),"A real seek resets the visual note clock")
	var auto_tap=SynkChart.note(1,6)
	var auto_hold=SynkChart.note(2,4,"hold"); auto_hold.duration=1.0
	var auto_slide=SynkChart.note(2.5,7,"slide"); auto_slide.duration=.7; auto_slide.end_lane=9
	var auto_flick=SynkChart.note(4,6,"flick"); auto_flick.direction=1
	game.start_game([auto_tap,auto_hold,auto_slide,auto_flick],true); game.countdown=0
	check(game.auto_play and game.auto_play_hud.visible,"Auto Play is clearly marked as a preview")
	game.song_time=1; game.update_autoplay()
	check(game.live[0].done and game.score==200000,"Auto Play hits tap notes")
	game._process(.016)
	check(game.displayed_score>0 and game.displayed_score<game.score,"Score rolls toward the earned value after a hit")
	game.pointer_event(1,Vector2(.5,.765),true,false,false)
	check(game.pointers.is_empty(),"Manual touches do not change Auto Play")
	game.song_time=2; game.update_autoplay()
	check(game.live[1].started and not game.live[1].done,"Auto Play starts holds without removing the trail")
	game.song_time=2.5; game.update_autoplay()
	check(game.live[2].started and not game.live[2].done,"Auto Play follows slides to their end")
	game.song_time=3.2; game.update_autoplay()
	game.song_time=4; game.update_autoplay()
	check(game.live.all(func(entry): return entry.done) and game.judged==5 and game.score==1000000,"Auto Play completes every note type and both hold endpoints")
	game._audio_finished()
	check(game.mode=="results" and game.modal_body.text.contains("PREVIEW COMPLETE"),"Auto Play results are identified as a preview")
	game.start_game([auto_tap,auto_hold,auto_slide,auto_flick],true)
	game.toggle_pause(); game.pause_restart.pressed.emit()
	check(game.auto_play and game.mode=="play" and game.countdown>0,"Restart keeps Auto Play active")
	game.earned=.8; game.judged=1; game._process(0)
	check(game.rank_hud.text=="B" and game.rank_pulse>0,"Rank change triggers a short HUD accent")
	game.field.world.animate_effects(.7)
	var highway = game.field
	var world = highway.world
	check(world.camera is Camera3D and world.note_meshes.size()==3,"Highway uses a real 3D camera and three note meshes")
	var original_speed = game.note_speed
	game.note_speed = 1.0
	var hold_length = 0.0
	for song_time in [0.0, 1.0, 1.5, 2.0]:
		game.song_time = song_time
		var head = world.note_position(6,1.0)
		var tail = world.note_position(6,3.0)
		if song_time == 0.0: hold_length = head.z-tail.z
		check(is_equal_approx(head.z-tail.z,hold_length),"3D hold length stays constant before and after the hit line")
	for speed in [.5, 1.0, 2.0, 3.0]:
		game.note_speed = speed
		check(is_equal_approx(game.note_travel_seconds()*speed,2.6),"Note travel time scales with speed")
		for song_time in [0.0, 1.5, 2.0]:
			game.song_time = song_time
			var head = world.note_position(6,1.0)
			var tail = world.note_position(6,3.0)
			check(is_equal_approx(head.z-tail.z,hold_length*speed),"3D hold length matches speed throughout its fall")
	check(game.audio.pitch_scale==1.0,"Note speed leaves music playback speed unchanged")
	game.note_speed = original_speed
	for lane in 13:
		var screen_point = highway.project(lane,0)/highway.size
		var mapped = highway.input_position(screen_point)
		check(absf(SynkCapture.lane(mapped.x)-lane)<.01,"3D projection maps back to lane "+str(lane))
	var hold = SynkChart.note(2,4,"hold"); hold.duration=1.0
	game.mode="record"; game.overdub=false; game.capture.notes=[SynkChart.note(2,6)]
	game.song_time=2.1; world._process(0)
	check(world.notes.has("captured0"),"Released recorded notes remain visible")
	var recorded_node=world.notes["captured0"].node
	var recorded_y=world.camera.unproject_position(recorded_node.global_position).y
	game.song_time=2.4; world._process(0)
	check(world.camera.unproject_position(recorded_node.global_position).y<recorded_y,"Recorded notes fly upward along the stage")
	game.song_time=2+game.note_travel_seconds()+.1; world._process(0)
	check(not world.notes.has("captured0"),"Recorded notes leave the preview after traveling upstage")
	game.capture.notes.clear()
	var type_notes=[SynkChart.note(2,0),SynkChart.note(2,1,"hold"),SynkChart.note(2,2,"slide"),SynkChart.note(2,3,"flick")]
	type_notes[1].duration=1.0; type_notes[2].duration=1.0
	game.start_game(type_notes); game.song_time=1; world._process(0)
	for i in type_notes.size():
		var note_art=world.notes["play"+str(i)].node.get_child(0).material_override as ShaderMaterial
		var palette=0 if i==0 else (2 if i==3 else 1)
		check(note_art.get_shader_parameter("tint")==world.COLORS[palette],"Note color follows its type in every lane")
		check(note_art.get_shader_parameter("recolor")==bool(i>0),"Purple and yellow note art is recolored")
	var flick_arrow=world.notes["play3"].node.get_child(1).material_override as ShaderMaterial
	check(flick_arrow.get_shader_parameter("tint")==world.COLORS[2],"Flick direction arrow is yellow")
	var slide = SynkChart.note(2,6,"slide"); slide.duration=1.0; slide.end_lane=9
	game.start_game([hold,slide]); game.song_time=1.0
	world._process(0)
	check(world.notes.size()==2,"3D hold and slide geometry is created")
	var hold_node = world.notes["play0"].node
	game.song_time=1.25; world._process(0)
	check(world.notes["play0"].node==hold_node,"Falling notes reuse their 3D meshes")
	game.live[0].done=true; world._process(0)
	check(not world.notes.has("play0"),"Judged 3D notes leave the playfield")
	world.spawn_hit(6,"tap"); world.animate_effects(.45)
	var impact=world.bursts[0]
	var flash_bottom=world.camera.unproject_position(impact.flash.global_transform * Vector3(0,-2,0)).y
	var ring_front=world.camera.unproject_position(impact.node.global_position+Vector3(0,0,impact.ring.scale.x*.97)).y
	check(flash_bottom<highway.viewport.size.y*.98 and ring_front<highway.viewport.size.y*.98,"Hit flash and ring remain above the screen bottom")
	world.animate_effects(.25)
	world.spawn_hit(2,"tap"); world.spawn_hit(8,"flick",1)
	check(world.bursts.size()==2,"Simultaneous hits retain independent animations")
	check(world.bursts[0].fill is MeshInstance3D and world.bursts[1].fill is MeshInstance3D,"Hit effects have filled centers")
	check(world.bursts[0].fill.material_override.get_shader_parameter("tint")==world.COLORS[0] and world.bursts[1].fill.material_override.get_shader_parameter("tint")==world.COLORS[2],"Hit effects use tap blue and flick yellow")
	world.animate_effects(.1)
	var burst_age = world.bursts[0].age
	var spark_position = world.bursts[1].particles[0].node.position
	check(spark_position.length()>0,"Hit particles move away from the impact")
	game.mode="paused"; world.animate_effects(.2)
	check(world.bursts[0].age==burst_age,"Pause freezes hit animations")
	game.mode="play"; world.animate_effects(.7)
	check(world.bursts.is_empty(),"Finished hit effects are cleaned up")
	for direction in 4:
		world.spawn_hit(6,"flick",direction)
		var flick_burst = world.bursts.back()
		var origin = world.camera.unproject_position(flick_burst.flash.global_position)
		world.animate_effects(.1)
		var movement = world.camera.unproject_position(flick_burst.flash.global_position)-origin
		var expected = [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][direction]
		check(movement.dot(expected)>0,"Flick flash moves in direction "+str(direction))
		for spark in flick_burst.particles:
			check(spark.velocity.dot(flick_burst.flick_axis)>0,"Flick sparks follow the arrow")
		world.animate_effects(.7)
	game.start_game([SynkChart.note(1,6)])
	game.judge(game.live[0],-1)
	world.animate_miss_shake(.04)
	check(world.camera.position.distance_to(world.CAMERA_POSITION)>.001,"Missing a note shakes the stage")
	check(world.camera.position.distance_to(world.CAMERA_POSITION)<.08,"Miss shake stays subtle")
	world.animate_miss_shake(.3)
	check(world.camera.position.is_equal_approx(world.CAMERA_POSITION),"Stage returns to rest after the miss shake")
	game.start_game([SynkChart.note(1,6)])
	game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false)
	check(game.score==1000000 and game.combo==1,"Perfect tap scores correctly")
	game._process(0.0)
	check(game.combo_art_value==1 and game.combo_hud.get_child_count()==1 and game.combo_pulse>0,"Counter uses the digit art and pulses on a hit")
	check(game.combo_digit_textures.size()==10 and game.combo_hud.get_child(0).texture==game.combo_digit_textures[1],"Combo uses the generated sprite atlas")
	check(game.combo_digit_textures[0]==game.COMBO_ZERO and game.combo_digit_textures[9] is AtlasTexture,"Generated zero completes the supplied 1–9 sprite sheet")
	check(game.hit_art.visible and game.hit_art.texture!=null,"Hit judgement uses the supplied art")
	var highway_center=(game.ui.get_global_transform_with_canvas().affine_inverse()*(game.field.get_global_transform_with_canvas()*game.field.project(6,0))).x
	check(absf(game.combo_hud.position.x+game.combo_hud.size.x*.5-highway_center)<.5 and absf(game.hit_art.position.x+game.hit_art.size.x*.5-highway_center)<.5,"Combo and judgement art align with the projected highway center")
	game.flash=0; game._process(0.0)
	check(game.hit_art.visible and is_equal_approx(game.hit_art.modulate.a,1.0),"Last hit judgement remains visible after its pulse")
	game.pointer_event(1,Vector2(.5,.765),false,true,false)
	var hold_judgement=SynkChart.note(1,6,"hold"); hold_judgement.duration=1.0
	game.start_game([hold_judgement]); game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false)
	check(game.judged==1 and not game.live[0].done and game.score==500000,"Hold start is judged independently")
	var held_impact=world.bursts.back()
	check(held_impact.sustain_entry==game.live[0],"Hold start keeps its own hit artwork alive")
	world.animate_effects(.9)
	check(world.bursts.any(func(burst): return burst.node==held_impact.node) and held_impact.flash.material_override.get_shader_parameter("opacity")>.4,"Hold hit continues animating beyond an ordinary hit burst")
	game.combo_pulse=0; game._process(.1)
	var first_hold_scale=game.combo_hud.scale.x
	game._process(.1)
	check(game.has_active_hold() and game.combo_hud.scale.x!=first_hold_scale and game.hit_art.scale.is_equal_approx(Vector2.ONE),"Active hold pulses only the combo")
	game.song_time=1.5; game.pointers[1].position=Vector2(.9,.3); game.update_game()
	check(not game.live[0].done and game.judged==1,"Hold trail drift is not judged")
	game.song_time=2; game.update_game()
	check(game.live[0].done and game.judged==2 and game.score==1000000,"Held tail receives its own judgement")
	world.animate_effects(.25)
	check(not world.bursts.any(func(burst): return burst.node==held_impact.node),"Sustained hit fades after the hold ends")
	game.start_game([hold_judgement]); game.countdown=0; game.song_time=1
	game.pointer_event(2,Vector2(.5,.765),true,false,false)
	game.song_time=1.5; game.pointer_event(2,Vector2(.5,.765),false,true,false)
	check(game.live[0].done and game.judged==2 and game.score==500000,"Early hold release misses only the tail")
	var flick=SynkChart.note(1,6,"flick"); flick.direction=1
	game.start_game([flick]); game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false); game.pointer_event(1,Vector2(.6,.765),false,true,false)
	check(game.score==1000000,"Final flick motion judges on release")
	var forgiving_slide=SynkChart.note(2,6,"slide")
	forgiving_slide.duration=1.0; forgiving_slide.end_lane=9
	game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.5
	game.live[0].started=true; game.live[0].pointer=7; game.live[0].error=.04
	game.pointers[7]={"start":Vector2(.5,.765),"position":Vector2(.07+((9.2+.5)/13.0)*.86,.765)}
	game.update_game()
	check(not game.live[0].done,"Brief slide drift stays active")
	game.song_time=2.64; game.pointers[7].position=Vector2(.07+((8.0+.5)/13.0)*.86,.765)
	game.update_game()
	check(not game.live[0].done,"Returning to the slide path remains active")
	game.song_time=2.98; game.update_game()
	check(game.live[0].done and game.score==1000000,"Recovered slide scores at the end")
	var early_slide=SynkChart.note(2,6,"slide")
	early_slide.duration=1.0; early_slide.end_lane=6
	game.start_game([early_slide]); game.countdown=0; game.song_time=2.9
	game.live[0].started=true; game.live[0].pointer=8; game.live[0].error=.05
	game.pointers[8]={"start":Vector2(.5,.765),"position":Vector2(.5,.765)}
	game.pointer_event(8,Vector2(.5,.765),false,true,false)
	check(game.live[0].done and game.score>0,"Slide release shortly before the tail can score")
	game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.3
	game.live[0].started=true; game.live[0].pointer=9; game.live[0].error=.04
	game.pointers[9]={"start":Vector2(.5,.765),"position":Vector2(.9,.765)}
	game.update_game(); game.song_time=2.55; game.update_game()
	check(not game.live[0].done,"A slide is not judged along its trail")
	game.song_time=3.21; game.update_game()
	check(game.live[0].done and game.score==0,"A slide still misses when its end is not reached")
	world._process(0)
	check(world.notes.has("play0"),"Missed slide remains on the stage as a ghost")
	var missed_slide_node=world.notes["play0"].node
	var missed_slide_position=missed_slide_node.position
	game.song_time=3.41; world._process(.2)
	var missed_slide_art=missed_slide_node.get_child(0).material_override as ShaderMaterial
	check(missed_slide_node.position.is_equal_approx(missed_slide_position) and missed_slide_art.get_shader_parameter("desaturate")>.9,"Missed slide freezes and turns gray")
	game.song_time=4.12; world._process(.71)
	check(not world.notes.has("play0"),"Gray slide fades out after its miss is readable")
	game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.3
	game.update_game(); world._process(0)
	check(game.live[0].done and world.notes.has("play0"),"Unstarted slide also remains visible when missed")
	game.start_game([SynkChart.note(1,6)]); game.countdown=0; game.song_time=1
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=game.size*Vector2(.5,.765)
	root.push_input(click,true)
	check(game.score==1000000,"Viewport mouse input reaches the highway")
	click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false; click.position=game.size*Vector2(.5,.765); root.push_input(click,true)
	game.open_editor(); game.document.load_notes([]); game.document.add(12,6); game.cursor=10
	game.record_here(); check(game.mode=="record" and game.start_position==10,"Recording seeks to selected section")
	world._process(0)
	check(world.recorder_guides.visible and world.recorder_guides.get_child_count()==25,"Recorder shows lane divisions and tap targets")
	game.countdown=0; game.song_time=11
	var arranged_note=SynkChart.note(10.8,6)
	game.capture.notes.append(arranged_note)
	game.toggle_arrange()
	await create_timer(.03).timeout
	check(game.arranging and game.arrange_button.text=="RECORD","Arrange mode freezes recording for editing")
	check(game.kind_buttons[0].caption.text=="DELETE","Animated recorder controls update their visible labels")
	world._process(0); check(world.recorder_guides.visible,"Lane guides stay visible while arranging notes")
	check(game.outside_highway(Vector2(.03,.2)) and not game.outside_highway(Vector2(.5,.5)),"Arrange scrolling is limited to the outer rail area")
	game.arrange_pointer_event(5,Vector2(.03,.2),true,false,false)
	game.arrange_pointer_event(5,Vector2(.03,.1),false,false,false)
	game.arrange_pointer_event(5,Vector2(.03,.1),false,true,false)
	check(game.song_time>11,"Swiping empty stage space scrolls the recording")
	var note_position=Vector3(game.field.world.lane_x(6),.2,(arranged_note.time-game.song_time)*game.field.world.travel_speed())
	var note_screen=game.field.world.camera.unproject_position(note_position)/Vector2(game.field.viewport.size)
	game.arrange_pointer_event(6,note_screen,true,false,false)
	game.arrange_pointer_event(6,note_screen+Vector2(.08,-.06),false,false,false)
	game.arrange_pointer_event(6,note_screen+Vector2(.08,-.06),false,true,false)
	check(arranged_note.lane!=6 and arranged_note.time<10.8,"Dragging a recorded note changes its lane and timing")
	check(not game.arrange_selection.is_empty() and not game.kind_buttons[0].disabled and game.record_help.text.contains("SELECTED"),"Selecting a note enables the arrange actions")
	var time_before_inside_swipe=game.song_time
	game.arrange_pointer_event(7,Vector2(.5,.5),true,false,false)
	game.arrange_pointer_event(7,Vector2(.5,.35),false,false,false)
	game.arrange_pointer_event(7,Vector2(.5,.35),false,true,false)
	check(is_equal_approx(game.song_time,time_before_inside_swipe),"Gestures within the highway never scroll the chart")
	game.arrange_selection={"note":arranged_note,"document":false,"index":0}; game.refresh_arrange_controls()
	game.kind_buttons[3].pressed.emit()
	check(arranged_note.kind=="slide" and arranged_note.duration>0,"A recorded note can be changed to a slide")
	game.kind_buttons[4].pressed.emit()
	check(arranged_note.kind=="flick" and arranged_note.duration==0,"A recorded note can be changed to a flick")
	game.kind_buttons[0].pressed.emit()
	check(game.capture.notes.is_empty() and game.arrange_selection.is_empty(),"Arrange DELETE removes the selected recorded note")
	game.song_time=12.2
	var existing_note=game.document.notes[0]
	var existing_position=Vector3(game.field.world.lane_x(float(existing_note.lane)),.2,(float(existing_note.time)-game.song_time)*game.field.world.travel_speed())
	var existing_screen=game.field.world.camera.unproject_position(existing_position)/Vector2(game.field.viewport.size)
	game.arrange_pointer_event(8,existing_screen,true,false,false)
	game.arrange_pointer_event(8,existing_screen,false,true,false)
	check(not game.arrange_selection.is_empty() and game.arrange_selection.document,"Arrange mode can select an existing chart note")
	game.change_arrange_note_type("hold")
	check(game.document.notes[0].kind=="hold" and game.document.dirty,"Type changes to existing notes are part of the chart edit history")
	game.delete_arrange_note()
	check(game.document.notes.is_empty(),"Arrange DELETE removes an existing chart note")
	game.document.undo()
	check(game.document.notes.size()==1,"An existing note deleted in arrange mode can be undone")
	game.toggle_arrange()
	check(not game.arranging and game.arrange_button.text=="ARRANGE","Record mode resumes after arranging")
	game.capture.notes.clear()
	game.song_time=11
	game.pointer_event(2,Vector2(.4,.765),true,false,false); game.song_time=11.08; game.pointer_event(2,Vector2(.4,.765),false,true,false)
	game.stop_take(); check(game.mode=="editor" and game.document.notes.size()==2,"Overdub keeps previous notes")
	game.document.undo(); check(game.document.notes.size()==1,"Undo removes entire take")
	game.document.selected=0; game.document.convert("flick",.5,game.length()); game.refresh_editor()
	check(game.info.text.contains("FLICK"),"Inspector updates after note conversion")
	game.document.dirty=false; game.close_editor()
	check(game.mode=="library" and game.chart_library.visible,"Studio returns to chart library")
	check(game.chart_library.chart_cards.size()==game.library.songs.size()+1,"Chart library shows one cover card per song")
	var original_song=game.song
	var custom_song={"id":"a".repeat(64),"title":"My Test Track","file":"test_selection.wav","bpm":128.0}
	var selection_stream=AudioStreamWAV.new(); selection_stream.format=AudioStreamWAV.FORMAT_16_BITS; selection_stream.mix_rate=8000
	var selection_samples=PackedByteArray(); selection_samples.resize(16000); selection_stream.data=selection_samples
	var selection_path="user://songs/test_selection.wav"
	check(selection_stream.save_to_wav(selection_path)==OK,"Selection fixture audio is available")
	check(game.library.save_chart(str(custom_song.id),[SynkChart.note(.5,6)])==OK,"Selection fixture chart is available")
	game.library.songs.append(custom_song); game.chart_library.refresh()
	check(game.chart_library.chart_cards.size()==2 and game.chart_library.chart_cards[1].get_child(1).text=="My Test Track","Imported charts appear by cover and title")
	game.queue_song_metadata()
	var metadata_deadline=Time.get_ticks_msec()+10000
	while not game.song_metadata.has(str(custom_song.id)) and Time.get_ticks_msec()<metadata_deadline: await process_frame
	check(game.song_metadata.has(str(custom_song.id)) and game.song_metadata[str(custom_song.id)].get("note_count",-1)==1 and game.song_metadata[str(custom_song.id)].get("waveform",PackedFloat32Array()).size()==512,"Song duration, chart and waveform load before selection")
	check((game.chart_library.chart_cards[1].get_child(2) as Label).text.contains("1 NOTES"),"Library card uses prepared chart metadata")
	game.open_chart(1)
	check(game.mode=="library" and game.loading_song_index==1,"Selecting a song queues audio loading without blocking the UI")
	var selection_deadline=Time.get_ticks_msec()+10000
	while game.loading_song_index>=0 and Time.get_ticks_msec()<selection_deadline: await process_frame
	check(game.mode=="editor" and game.song.id==custom_song.id and game.document.notes.size()==1 and game.waveform.size()==512,"Prepared song opens automatically when audio is ready")
	var art=Image.create_empty(64,64,false,Image.FORMAT_RGBA8); art.fill(Color.RED)
	var art_path="user://cover_fixture.png"; art.save_png(art_path)
	game.song=custom_song; game.import_cover(art_path)
	check(game.has_custom_cover(str(custom_song.id)) and game.cover_texture_for_id(str(custom_song.id)) is ImageTexture,"Imported chart cover art is saved and cached")
	DirAccess.remove_absolute(art_path); DirAccess.remove_absolute(game.cover_path(str(custom_song.id)))
	game.document.dirty=false; game.select_song(0)
	game.library.songs.pop_back(); game.song_metadata.erase(str(custom_song.id)); game.chart_library.refresh()
	DirAccess.remove_absolute(selection_path)
	DirAccess.remove_absolute("user://charts/"+str(custom_song.id)+".json")
	DirAccess.remove_absolute("user://charts/"+str(custom_song.id)+".json.bak")
	game.set_mode("menu")
	if DisplayServer.get_name()!="headless":
		await create_timer(.4).timeout
		root.get_texture().get_image().save_png("res://.tools/godot-menu.png")
		game.open_lobby_settings(); await create_timer(.2).timeout
		root.get_texture().get_image().save_png("res://.tools/godot-settings.png")
		game.close_lobby_settings()
		game.start_game(SynkChart.demo()); game.countdown=0; game.audio.play(20)
		await process_frame; await process_frame
		root.get_texture().get_image().save_png("res://.tools/godot-highway.png")
		game.mode="paused"; game.combo=123; game._process(0); await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/godot-combo-atlas.png")
		game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.3; game.update_game()
		game.song_time=2.5; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/godot-missed-slide.png")
		game.open_editor(); await create_timer(.4).timeout
		root.get_texture().get_image().save_png("res://.tools/godot-library.png")
		game.open_chart(0); game.document.load_notes(SynkChart.demo()); game.cursor=12; game.refresh_editor(); await create_timer(.4).timeout
		root.get_texture().get_image().save_png("res://.tools/godot-studio.png")
		game.record_here(); game.countdown=0; game.song_time=12
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/godot-recorder-guides.png")
	print("Scene integration: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free(); await process_frame; quit(0 if failures==0 else 1)
