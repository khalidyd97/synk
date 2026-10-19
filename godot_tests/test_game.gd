extends SceneTree

var failures=0
func check(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await process_frame; await process_frame
	# Song intro: loading card first, then the stage entrance holds the countdown until it lands.
	game.start_game([SynkChart.note(5,5)])
	check(game.stage_intro.running() and game.stage_intro.entrance()==0.0 and game.stage_intro.card_art.texture!=null,"Song intro opens with the cover loading card")
	var held_countdown=game.countdown
	game._process(.5)
	check(game.countdown==held_countdown and not game.pause_button.visible,"Countdown waits while the intro plays")
	for step in 24: game.stage_intro._process(.1); game._process(.1)
	check(not game.stage_intro.running() and game.countdown<held_countdown and game.pause_button.visible,"Countdown starts once the stage has entered")
	game.toggle_pause(); game.restart_from_pause()
	check(game.stage_intro.running() and game.stage_intro.load_time==0.0,"Restart replays only the stage entrance")
	game.stage_intro.skip(); game.set_mode("menu")
	game.stage_intro_enabled=false
	check(game.format_score(0)=="0" and game.format_score(12480)=="12,480" and game.format_score(1000000)=="1,000,000","Scores use thousands separators and start at 0")
	# Song sections: marks set in memory only, restored afterwards.
	var saved_marks={"verse2":game.song.get("verse2"),"bridge":game.song.get("bridge")}
	game.song.verse2=4.0; game.song.bridge=8.0
	check(game.section_available("verse1") and game.section_range("verse1")==Vector2(0,4) and game.section_range("verse2")==Vector2(4,8) and game.section_range("bridge")==Vector2(8,INF),"Verse 2 and Bridge marks define the play sections")
	game.set_play_mode("verse2")
	game.start_game([SynkChart.note(2,5),SynkChart.note(5,5),SynkChart.note(9,5)])
	check(game.live.size()==1 and game.start_position==0.0 and game.song_time<4.0 and game.play_finish_time>=8.0 and game.last_section=="verse2","Section play uses only that section's notes, with as much lead-in as the song allows")
	game.song.verse2=12.0; game.song.bridge=24.0
	game.start_game([SynkChart.note(2,5),SynkChart.note(14,5),SynkChart.note(26,5)],false,"verse2")
	check(game.live.size()==1 and is_equal_approx(game.start_position,7.0),"Sections start the music 5 seconds before their mark")
	check(game.live.all(func(e): return float(e.note.time)>=12.0),"No notes appear before the section mark")
	game.countdown=0; game.song_time=7.0
	check(game.section_gain()<.01,"Section music fades in from silence")
	game.song_time=12.0
	check(is_equal_approx(game.section_gain(),1.0),"Section music is at full volume by the mark")
	if game.length()>game.play_finish_time:
		game.song_time=game.play_finish_time-.5
		check(game.section_gain()<.5 and game.play_finish_time>24.0,"Sections other than the bridge fade out past their end")
	game.start_game([SynkChart.note(26,5)],false,"bridge")
	game.countdown=0; game.song_time=game.length()-.1
	check(game.section_fade_out_start==INF and is_equal_approx(game.section_gain(),1.0),"The bridge plays out without a fade-out")
	game.start_game([SynkChart.note(2,5)],false,"full")
	game.countdown=0; game.song_time=.1
	check(is_equal_approx(game.section_gain(),1.0),"The full song never fades")
	game.song.verse2=4.0; game.song.bridge=8.0
	game.start_game([SynkChart.note(2,5),SynkChart.note(5,5)],false,"full")
	check(game.live.size()==2 and game.start_position==0.0 and game.play_finish_time==INF,"Full song still plays every note")
	game.set_play_mode("full"); game.set_mode("menu")
	for key in saved_marks:
		if saved_marks[key]==null: game.song.erase(key)
		else: game.song[key]=saved_marks[key]
	game.set_play_mode("bridge")
	check(game.section_available("bridge")==(game.play_mode=="bridge"),"Unavailable play modes fall back to the full song")
	game.set_play_mode("full")
	check(game.album_name({"id":"x"})=="Imported music" and game.album_name({"id":"x","album":"Night Drive"})=="Night Drive" and game.album_name({"id":"eclipse"})=="SYNK Originals","Album names fall back for songs without one")
	# 3-2-1 countdown.
	game.start_game([SynkChart.note(9,5)])
	check(game.countdown==3.0 and game.song_time==-3.0,"Countdown starts at 3")
	# Checkpoint dots: on-lane dots score, an off-lane dot breaks the hold and forfeits the rest.
	var dotted=SynkChart.note(2,5,"hold"); dotted.duration=1.5; dotted.checkpoints=[.4,.8,1.2]
	game.start_game([dotted]); game.countdown=0
	var dot_entry=game.live[0]
	dot_entry.started=true
	check(game.total_judgements()==5,"Each checkpoint dot counts as a judgment")
	game.song_time=2.45
	var judged_before=game.judged
	check(game.process_checkpoints(dot_entry,5.0,false) and game.judged==judged_before+1 and game.judgment_counts.PERFECT==1 and dot_entry.checks_done==1,"A dot passed on the lane scores PERFECT")
	game.song_time=2.85
	check(not game.process_checkpoints(dot_entry,11.0,false) and dot_entry.done and game.judgment_counts.MISS>=2 and dot_entry.checks_done==3,"Missing a dot breaks the hold and misses the remaining dots")
	# Arrange DOTS tool adds and removes a dot on the selected trail.
	var trail=SynkChart.note(3,5,"slide"); trail.duration=1.0
	check(game.toggle_checkpoint(trail,3.5,false) and trail.checkpoints==[.5],"Arrange DOTS adds a checkpoint")
	check(game.toggle_checkpoint(trail,3.52,false) and not trail.has("checkpoints"),"Tapping an existing dot removes it")
	game.set_mode("menu")
	# Chart deletion asks first; the built-in song only offers to delete its chart. Nothing is deleted here.
	game.chart_library.ask_delete(game.eclipse_song())
	check(game.chart_library.confirm.visible and not game.chart_library.confirm_song_button.visible,"Deleting asks for confirmation and keeps the built-in song")
	game.chart_library.confirm.visible=false
	check(not game.lobby.DragScroll.was_dragged(game.lobby.track_scroll) and game.lobby.track_list.get_child(0).mouse_filter==Control.MOUSE_FILTER_PASS,"Song list rows let drags and wheel scroll the list")
	check(game.field.world.cover_backdrop.visible and game.field.world.cover_material.get_shader_parameter("cover")==game.cover_texture_for_id(str(game.song.id)),"Song cover glows behind the stage")
	check(game.combo_glow.get_shader_parameter("use_gradient") and game.combo_glow.get_shader_parameter("gradient_middle")==game.field.world.colors[1],"Combo counter takes a gradient of the cover colors")
	await create_timer(1.2).timeout
	var first_row=game.lobby.track_list.get_child(0)
	check(first_row.variant=="track" and first_row.selected,"Selected song is highlighted in the lobby list")
	var lobby_chip: Button=game.lobby.mode_buttons["full"]; lobby_chip.fit_caption()
	check(lobby_chip.caption.get_theme_font_size("font_size")>lobby_chip.caption_size,"Buttons outside Chart Studio use larger text")
	check(game.lobby.display_title("XLOV_-_1_ONLY_(MP3.PM)")=="XLOV - 1 ONLY" and game.lobby.display_title("Eclipse")=="Eclipse","Song titles from file names are cleaned up")
	check(first_row.custom_minimum_size.y>=110 and is_equal_approx(first_row.scale.x,1.0),"Song cards are large and do not shrink toward the list edges")
	first_row.button_down.emit()
	check(not first_row.has_meta("ui_motion_bound"),"Song cards do not shrink while held")
	check(game.lobby.play_button.modulate.a>.99 and first_row.modulate.a>.99 and game.lobby.settings_button.rotation==0.0,"Lobby entrance animation settles every element")
	check(game.mode=="menu" and game.lobby.visible and not game.modal.visible,"Main scene boots to the lobby")
	check(game.lobby.play_button.visible and game.lobby.play_button.art.texture!=null and game.lobby.play_button.art.material is ShaderMaterial,"Lobby PLAY uses the animated reference artwork")
	check(game.lobby.settings_button.tooltip_text=="Settings" and game.lobby.settings_button.text.is_empty(),"Lobby settings is an icon-only gear")
	var ui_sound=game.get_tree().get_first_node_in_group("ui_sound")
	game.lobby.settings_button.button_down.emit()
	game.lobby.play_button.button_down.emit()
	check(ui_sound!=null and ui_sound.last_played.has("click") and ui_sound.last_played.has("play"),"Buttons play their UI sounds")
	check(ui_sound.sound_for(game.lobby.all_tab)=="toggle" and ui_sound.sound_for(game.lobby.create_chart_button)=="confirm","Button roles choose matching sounds")
	check(game.lobby.get_child(3).anchor_left<.05,"Lobby cover uses the space previously occupied by the left button rail")
	game.lobby.play_button.animate_hover(1.0)
	await create_timer(.24).timeout
	check(game.lobby.play_button.art_material.get_shader_parameter("hover_amount")>.9,"PLAY glow animates on hover")
	game.lobby.play_button.animate_hover(0.0)
	check(game.waveform.size()==512,"Waveform samples decoded")
	game.set_mode("guide")
	check(game.mode=="guide" and game.guide_back.visible and not game.modal.visible,"Note guide opens from the menu")
	game.guide_back.pressed.emit()
	check(game.mode=="menu" and game.lobby.visible,"Note guide returns to the lobby")
	game.lobby.settings_button.pressed.emit()
	check(game.settings_panel.visible and not game.lobby.visible and not game.modal.visible,"Lobby gear opens settings as its own page")
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
	var original_shape=game.note_shape
	game.settings_panel.shape_tiles["circle"].pressed.emit()
	check(game.note_shape=="circle" and game.settings_panel.shape_tiles["circle"].selected and not game.settings_panel.shape_tiles["rectangle"].selected,"Settings switch notes to circles")
	game.change_note_shape(original_shape)
	var saved_mode=game.bluetooth_mode; var saved_latency=game.bluetooth_latency_ms
	game.open_sync_helper()
	check(game.sync_helper.visible and not game.settings_panel.visible and game.sync_helper.player.playing,"Sync helper opens as its own page and starts the metronome")
	var helper=game.sync_helper
	check(is_equal_approx(helper.measured_delay_ms([.20,.21,.19,.22,.18,.2,.5,.2]),200.0),"Tap measurement uses the median so stray taps are ignored")
	helper.delay_input.value=240
	helper.save()
	check(game.bluetooth_mode and is_equal_approx(game.bluetooth_latency_ms,240) and not helper.visible and game.settings_panel.visible and not helper.player.playing,"Saving the helper applies the delay and returns to settings")
	check(is_equal_approx(game.settings_panel.bluetooth_latency_input.value,240),"Settings show the delay chosen in the helper")
	game.bluetooth_latency_input.value=saved_latency; game.bluetooth_toggle.button_pressed=saved_mode
	game.close_lobby_settings()
	check(not game.settings_panel.visible and game.lobby.visible,"Settings BACK returns to the lobby")
	game.start_game([SynkChart.note(1,5)])
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
	game.start_game([SynkChart.note(8,5)]); game.countdown=0; game.audio.play(4); game.song_time=4
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
	var auto_tap=SynkChart.note(1,5)
	var auto_hold=SynkChart.note(2,4,"hold"); auto_hold.duration=1.0
	var auto_slide=SynkChart.note(2.5,7,"slide"); auto_slide.duration=.7; auto_slide.end_lane=9
	var auto_flick=SynkChart.note(4,5,"flick"); auto_flick.direction=1
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
	game._audio_finished(); game._process(0.0)
	check(game.finishing and game.finish_overlay.visible and game.mode=="play" and not game.combo_hud.visible,"The song's end plays the finish animation first")
	check(not game.hit_label.visible,"The last judgment is hidden during the finish")
	check(game.finish_overlay.banner.text in ["AUTO PLAY"] and game.finish_overlay.digits_box.get_child_count()>0,"The finish carries the combo counter and a banner")
	game._process(.7); game._process(.7)
	check(game.finish_overlay.target_rect.size.y>0,"The flying combo targets the results' MAX COMBO figure")
	check(game.mode=="results" and game.results_screen.visible and game.results_screen.rank_label.text=="AUTO" and not game.modal.visible,"Auto Play results are identified as a preview")
	check(game.results_screen.buttons.size()==2 and int(game.judgment_counts.PERFECT)>0 and not game.score_panel.visible,"Results screen shows the judgment breakdown with Lobby and Retry only")
	check(not game.hit_label.visible,"The results screen shows no gameplay judgment")
	check(game.results_screen.rank_label.visible and not game.results_screen.rank_art.visible,"Auto Play results keep the text AUTO rank")
	game.results_screen.build_rank_art("SS")
	check(game.results_screen.rank_art.visible and game.results_screen.rank_art.get_child_count()==2 and game.results_screen.rank_art.get_child(0).material==game.combo_glow,"Ranks use the glass letters in the combo digits' style")
	check(game.finish_overlay.visible and not game.results_screen.combo_value_label.visible,"The landed combo counter stays on the results screen")
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
	for lane in SynkChart.LANES:
		var screen_point = highway.project(lane,0)/highway.size
		var mapped = highway.input_position(screen_point)
		check(absf(SynkCapture.lane(mapped.x)-lane)<.01,"3D projection maps back to lane "+str(lane))
	var hold = SynkChart.note(2,4,"hold"); hold.duration=1.0
	game.mode="record"; game.overdub=false; game.capture.notes=[SynkChart.note(2,5)]
	game.song_time=2.1; world._process(0)
	check(world.notes.has("captured0"),"Released recorded notes remain visible")
	var recorded_node=world.notes["captured0"].node
	check(world.notes["captured0"].lines.size()==1 and world.notes["captured0"].lines[0].visible==game.note_lines,"Recorded notes get a horizontal alignment line")
	var lines_before=game.note_lines
	game.toggle_note_lines(); world._process(0)
	check(world.notes["captured0"].lines[0].visible==(not lines_before) and game.note_lines_button.text==("LINES: OFF" if lines_before else "LINES: ON"),"LINES toggle hides and shows alignment lines")
	game.toggle_note_lines()
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
		check(note_art.get_shader_parameter("tint")==world.colors[palette],"Note color follows its type in every lane")
		check(note_art.get_shader_parameter("recolor")==bool(i>0 or world.cover_palette_active),"Note art is recolored to the cover palette")
	var flick_note_node=world.notes["play3"].node
	var flick_arrow_node=flick_note_node.get_child(flick_note_node.get_child_count()-1)
	var flick_arrow=flick_arrow_node.material_override as ShaderMaterial
	check(flick_arrow.get_shader_parameter("tint")==world.colors[2],"Flick direction arrow uses the flick color")
	var flick_cap=world.notes["play3"].node.get_child(0)
	check(world.camera.unproject_position(flick_arrow_node.global_position).y<world.camera.unproject_position(flick_cap.global_position).y-10,"Flick arrow floats above its note")
	var slide = SynkChart.note(2,5,"slide"); slide.duration=1.0; slide.end_lane=9
	game.start_game([hold,slide]); game.song_time=1.0
	world._process(0)
	check(world.notes.size()==2,"3D hold and slide geometry is created")
	var hold_node = world.notes["play0"].node
	game.song_time=1.25; world._process(0)
	check(world.notes["play0"].node==hold_node,"Falling notes reuse their 3D meshes")
	game.live[0].done=true; world._process(0)
	check(not world.notes.has("play0"),"Judged 3D notes leave the playfield")
	var tail_hold=SynkChart.note(2,5,"hold"); tail_hold.duration=1.0
	game.start_game([tail_hold]); game.song_time=1.5; world._process(0)
	var tail_children=world.notes["play0"].node.get_children()
	check(tail_children[-1].name=="SustainEndCap" and tail_children[-1].material_override.shader==tail_children[0].material_override.shader and is_equal_approx(tail_children[-1].mesh.size.x/tail_children[0].mesh.size.x,.65),"Hold tails reuse the filled note head at 65% size")
	var sharp_slide=SynkChart.note(1,0,"slide"); sharp_slide.duration=.4; sharp_slide.end_lane=SynkChart.MAX_LANE
	var sharp_centers=world.trail_centers(sharp_slide,32)
	var sharp_sides=world.trail_sides(sharp_centers)
	var widths_even=true
	for i in range(1,sharp_centers.size()-1):
		var travel=(sharp_centers[i+1]-sharp_centers[i-1]).normalized()
		if not is_equal_approx(sharp_sides[i].length(),1.0) or absf(sharp_sides[i].dot(travel))>.01: widths_even=false
	check(widths_even,"Slide trails keep the same width even when cutting sharply across lanes")
	game.change_note_shape("circle")
	game.start_game([SynkChart.note(2,5)]); game.song_time=1; world._process(0)
	var circle_mat=world.notes["play0"].node.get_child(0).material_override as ShaderMaterial
	check(circle_mat.shader.resource_path.ends_with("circle_note.gdshader") and is_equal_approx(world.notes["play0"].node.get_child(0).rotation_degrees.x,-90.0),"Circle notes lie flat on the highway")
	game.change_note_shape("rectangle")
	var missed_hold=SynkChart.note(1,5,"hold"); missed_hold.duration=1.5
	game.start_game([missed_hold]); game.countdown=0; game.song_time=1.0
	game.judge(game.live[0],-1)
	game.song_time=1.6; world._process(0)
	check(world.notes.has("play0"),"A missed hold stays on the highway")
	var missed_art=world.notes["play0"].node.get_child(0).material_override as ShaderMaterial
	var missed_z=world.notes["play0"].node.position.z
	check(missed_art.get_shader_parameter("desaturate")==1.0 and missed_art.get_shader_parameter("ghost_fade")==1.0,"A missed hold turns gray without fading out")
	game.song_time=1.9; world._process(0)
	check(world.notes.has("play0") and world.notes["play0"].node.position.z>missed_z,"A missed hold keeps scrolling past the bar")
	world.spawn_hit(6,"tap"); world.animate_effects(.45)
	var impact=world.bursts[0]
	# The art's own bottom edge; below it is only the fading mirrored glow.
	var flash_height=(impact.flash.mesh as QuadMesh).size.y
	var flash_bottom=world.camera.unproject_position(impact.flash.global_transform * Vector3(0,-flash_height*.5+flash_height*world.HIT_MIRROR/(1.0+world.HIT_MIRROR),0)).y
	var ring_front=world.camera.unproject_position(impact.ring.global_transform*Vector3(0,0,.97)).y
	check(flash_bottom<highway.viewport.size.y*.98 and ring_front<highway.viewport.size.y*.98,"Hit flash and ring remain above the screen bottom")
	world.animate_effects(.25)
	world.spawn_hit(2,"tap"); world.spawn_hit(8,"flick",1)
	check(world.bursts.size()==2,"Simultaneous hits retain independent animations")
	check(world.bursts[0].fill is MeshInstance3D and world.bursts[1].fill is MeshInstance3D,"Hit effects have filled centers")
	check(world.bursts[0].fill.material_override.get_shader_parameter("tint")==world.colors[0] and world.bursts[1].fill.material_override.get_shader_parameter("tint")==world.colors[2],"Hit effects use the tap and flick colors")
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
	game.start_game([SynkChart.note(1,5)])
	game.judge(game.live[0],-1)
	world.animate_miss_shake(.04)
	check(world.camera.position.distance_to(world.camera_rest_position())>.001,"Missing a note shakes the stage")
	check(world.camera.position.distance_to(world.camera_rest_position())<.08,"Miss shake stays subtle")
	world.animate_miss_shake(.3)
	check(world.camera.position.is_equal_approx(world.camera_rest_position()),"Stage returns to rest after the miss shake")
	var bar_screen_y=world.camera.unproject_position(Vector3.ZERO).y
	var kept_angle=game.highway_angle
	for angle in [18.0,44.0]:
		game.highway_angle=angle; world.animate_miss_shake(0)
		check(is_equal_approx(world.camera.rotation_degrees.x,-angle) and absf(world.camera.unproject_position(Vector3.ZERO).y-bar_screen_y)<2.0,"Changing the highway angle keeps the judgment bar in place on screen")
	game.highway_angle=kept_angle; world.animate_miss_shake(0)
	game.start_game([SynkChart.note(1,5)])
	game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false)
	check(game.score==1000000 and game.combo==1,"Perfect tap scores correctly")
	game._process(0.0)
	check(game.combo_art_value==1 and game.combo_hud.get_child_count()==1 and game.combo_pulse>0,"Counter uses the digit art and pulses on a hit")
	check(game.combo_digit_textures.size()==10 and game.combo_hud.get_child(0).texture==game.combo_digit_textures[1],"Combo uses the generated sprite atlas")
	check(game.combo_digit_textures[0]==game.COMBO_ZERO and game.combo_digit_textures[9] is ImageTexture and game.combo_hud.get_child(0).material==game.combo_glow and game.hit_art.material==game.hit_glow,"Generated zero completes the supplied 1–9 sprite sheet")
	check(game.hit_label.visible and game.hit_label.text in game.JUDGEMENT_ART and not game.hit_art.visible,"Hit judgement shows as bold text")
	var highway_center=(game.ui.get_global_transform_with_canvas().affine_inverse()*(game.field.get_global_transform_with_canvas()*game.field.project(game.field.world.CENTER_LANE,0))).x
	check(absf(game.combo_hud.position.x+game.combo_hud.size.x*.5-highway_center)<.5 and absf(game.hit_label.position.x+game.hit_label.size.x*.5-highway_center)<.5,"Combo and judgement art align with the projected highway center")
	check(game.hit_label.position.y+game.hit_label.size.y<=game.combo_hud.position.y+1,"Judgement sits above the combo counter")
	game.pointers[77]={"start":Vector2(.5,.765),"position":Vector2(.07+(9.5/SynkChart.LANES)*.86,.765)}
	world._process(0)
	var lit=world.finger_beams.filter(func(b): return b.visible)
	check(lit.size()==game.pointers.size() and lit.any(func(b): return is_equal_approx(b.position.x,world.lane_x(9))) and lit.all(func(b): return absf(b.position.x)+world.LANE_WIDTH*.5<=world.HIGHWAY_HALF_WIDTH+.001),"A finger beam lights exactly its lane without leaving the highway")
	var beam_mesh=world.finger_beams[0].mesh as PlaneMesh
	check(is_equal_approx(world.finger_beams[0].position.z+beam_mesh.size.y*.5,world.JUDGMENT_DEPTH*.5),"Finger beams reach the near edge of the judgment bar")
	check(absf(world.lane_x(0))+world.NOTE_WIDTH*.5<world.HIGHWAY_HALF_WIDTH and absf(world.lane_x(SynkChart.MAX_LANE))+world.NOTE_WIDTH*.5<world.HIGHWAY_HALF_WIDTH,"Notes in the outer lanes stay inside the highway rails")
	game.pointers.erase(77); world._process(0)
	check(world.finger_beams.filter(func(b): return b.visible).size()==game.pointers.size(),"The finger beam goes away when the finger lifts")
	var kept_combo=game.combo; game.combo=0; game._process(0.0)
	check(not game.combo_hud.visible,"Combo counter stays hidden at zero")
	game.combo=kept_combo; game._process(0.0)
	check(game.hud_shadow.visible and not game.song_hud.visible and not game.difficulty_hud.visible,"Left HUD has a shadow and the right side has no text")
	game.flash=0; game._process(0.0)
	check(game.hit_label.visible and game.hit_label.modulate.a>.5,"Last hit judgement remains visible after its pulse")
	game.pointer_event(1,Vector2(.5,.765),false,true,false)
	var hold_judgement=SynkChart.note(1,5,"hold"); hold_judgement.duration=1.0
	game.start_game([hold_judgement]); game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false)
	check(game.judged==1 and not game.live[0].done and game.score==500000,"Hold start is judged independently")
	var held_impact=world.bursts.back()
	check(held_impact.sustain_entry==game.live[0],"Hold start keeps its own hit artwork alive")
	world.animate_effects(.9)
	check(world.bursts.any(func(burst): return burst.node==held_impact.node) and held_impact.flash.material_override.get_shader_parameter("opacity")>.4,"Hold hit continues animating beyond an ordinary hit burst")
	world._process(0)
	check(world.notes.has("play0") and world.notes["play0"].held,"A held hold trail is clipped at the judgment bar")
	game.combo_pulse=0; game._process(.1)
	var first_hold_scale=game.combo_hud.scale.x
	game._process(.1)
	check(game.has_active_hold() and game.combo_hud.scale.x!=first_hold_scale and game.hit_label.scale.is_equal_approx(Vector2.ONE),"Active hold pulses only the combo")
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
	var flick=SynkChart.note(1,5,"flick"); flick.direction=1
	game.start_game([flick]); game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false); game.pointer_event(1,Vector2(.6,.765),false,true,false)
	check(game.score==1000000,"Final flick motion judges on release")
	var forgiving_slide=SynkChart.note(2,5,"slide")
	forgiving_slide.duration=1.0; forgiving_slide.end_lane=9
	game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.5
	game.live[0].started=true; game.live[0].pointer=7; game.live[0].error=.04
	game.pointers[7]={"start":Vector2(.5,.765),"position":Vector2(.07+((9.2+.5)/SynkChart.LANES)*.86,.765)}
	game.update_game()
	check(not game.live[0].done,"Brief slide drift stays active")
	game.song_time=2.64; game.pointers[7].position=Vector2(.07+((8.0+.5)/SynkChart.LANES)*.86,.765)
	game.update_game()
	check(not game.live[0].done,"Returning to the slide path remains active")
	game.song_time=2.98; game.update_game()
	check(game.live[0].done and game.score==1000000,"Recovered slide scores at the end")
	var early_slide=SynkChart.note(2,5,"slide")
	early_slide.duration=1.0; early_slide.end_lane=5
	game.start_game([early_slide]); game.countdown=0; game.song_time=2.9
	game.live[0].started=true; game.live[0].pointer=8; game.live[0].error=.05
	game.pointers[8]={"start":Vector2(.5,.765),"position":Vector2(.5,.765)}
	game.pointer_event(8,Vector2(.5,.765),false,true,false)
	check(game.live[0].done and game.score>0,"Slide release shortly before the tail can score")
	game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.3
	game.live[0].started=true; game.live[0].pointer=9; game.live[0].error=.04
	game.pointers[9]={"start":Vector2(.5,.765),"position":Vector2(.1,.765)}
	game.update_game(); game.song_time=2.55; game.update_game()
	check(not game.live[0].done,"A slide is not judged along its trail")
	game.song_time=3.21; game.update_game()
	check(game.live[0].done and game.score==0,"A slide still misses when its end is not reached")
	# A slide dropped halfway turns gray and keeps scrolling past the bar instead of freezing.
	game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.3
	game.live[0].started=true; game.live[0].pointer=9; game.live[0].error=.04
	game.pointers[9]={"start":Vector2(.5,.765),"position":Vector2(.5,.765)}
	game.update_game(); game.song_time=2.5; game.pointers.erase(9); game.update_game()
	check(game.live[0].done and game.live[0].has("missed_at"),"Letting go of a slide midway misses it")
	world._process(0)
	check(world.notes.has("play0"),"Missed slide stays on the stage")
	var missed_slide_node=world.notes["play0"].node
	var missed_slide_z=missed_slide_node.position.z
	game.song_time=2.7; world._process(.2)
	var missed_slide_art=missed_slide_node.get_child(0).material_override as ShaderMaterial
	check(missed_slide_node.position.z>missed_slide_z and missed_slide_art.get_shader_parameter("desaturate")>.9 and missed_slide_art.get_shader_parameter("ghost_fade")==1.0,"Missed slide turns gray and keeps scrolling without fading")
	game.song_time=12.0; world._process(.1)
	check(not world.notes.has("play0"),"Gray slide leaves once it has passed the camera")
	game.start_game([forgiving_slide]); game.countdown=0; game.song_time=2.3
	game.update_game(); world._process(0)
	check(game.live[0].done and world.notes.has("play0"),"Unstarted slide also remains visible when missed")
	game.start_game([SynkChart.note(1,5)]); game.countdown=0; game.song_time=1
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=game.size*Vector2(.5,.765)
	root.push_input(click,true)
	check(game.score==1000000,"Viewport mouse input reaches the highway")
	click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false; click.position=game.size*Vector2(.5,.765); root.push_input(click,true)
	game.open_editor()
	var shape_slide=SynkChart.note(10.5,2,"slide"); shape_slide.duration=1.0; shape_slide.end_lane=7
	game.document.load_notes([shape_slide]); game.document.selected=0; game.cursor=10.6; game.refresh_editor()
	check(game.slide_tools.visible,"Chart Studio shows slide shaping tools for a selected slide")
	var studio_button: Button=game.slide_tools.get_child(0); studio_button.fit_caption()
	check(studio_button.caption.get_theme_font_size("font_size")==studio_button.caption_size,"Chart Studio keeps its compact button text")
	var timeline=game.timeline; timeline.window_start=timeline.start_time()
	var trail_y=timeline.lane_y(SynkChart.lane_at(game.document.notes[0],11.0))
	timeline.begin(Vector2(timeline.time_x(11.0),trail_y))
	check(timeline.shape_point>0,"Pressing a selected slide's trail adds a shape point")
	timeline.move_pointer(Vector2(timeline.time_x(11.0),timeline.lane_y(0)))
	timeline.dragging=false; timeline.shape_point=-1
	check(SynkChart.valid(game.document.notes) and SynkChart.lane_at(game.document.notes[0],11.0)<1.0,"Dragging a shape point bends the slide")
	game.reshape_slide("smooth")
	var curved=game.document.notes[0]
	check(SynkChart.valid([curved]) and curved.path.any(func(point): return not is_equal_approx(float(point.lane),roundf(float(point.lane)))),"SMOOTH turns the slide into a soft curve")
	game.reshape_slide("snap")
	check(SynkChart.valid([curved]) and int(curved.path[0].lane)==2 and is_equal_approx(float(curved.path[-1].lane),float(curved.end_lane)),"SNAP locks the slide onto lanes")
	game.reshape_slide("reset")
	check(curved.path.is_empty(),"RESET returns the slide to a plain sweep")
	game.document.undo(); check(not game.document.notes[0].path.is_empty(),"Slide shaping can be undone")
	game.document.dirty=false
	game.open_editor(); game.document.load_notes([]); game.document.add(12,6); game.cursor=10
	game.record_here(); check(game.mode=="record" and game.start_position==10,"Recording seeks to selected section")
	world._process(0)
	check(world.recorder_guides.visible and world.recorder_guides.get_child_count()==SynkChart.LANES*2-1,"Recorder shows lane divisions and tap targets")
	game.countdown=0; game.song_time=11
	var arranged_note=SynkChart.note(10.8,5)
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
	var note_position=Vector3(game.field.world.lane_x(5),.2,(arranged_note.time-game.song_time)*game.field.world.travel_speed())
	var note_screen=game.field.world.camera.unproject_position(note_position)/Vector2(game.field.viewport.size)
	game.arrange_pointer_event(6,note_screen,true,false,false)
	game.arrange_pointer_event(6,note_screen+Vector2(.14,-.06),false,false,false)
	game.arrange_pointer_event(6,note_screen+Vector2(.14,-.06),false,true,false)
	check(arranged_note.lane!=5 and arranged_note.time<10.8,"Dragging a recorded note changes its lane and timing")
	check(not game.arrange_selection.is_empty() and not game.kind_buttons[0].disabled and game.record_help.text.contains("SELECTED"),"Selecting a note enables the arrange actions")
	var time_before_inside_swipe=game.song_time
	game.arrange_pointer_event(7,Vector2(.5,.5),true,false,false)
	game.arrange_pointer_event(7,Vector2(.5,.35),false,false,false)
	game.arrange_pointer_event(7,Vector2(.5,.35),false,true,false)
	check(is_equal_approx(game.song_time,time_before_inside_swipe),"Gestures within the highway never scroll the chart")
	var pointed_hold=SynkChart.note(game.song_time-.4,5,"hold"); pointed_hold.duration=2.0
	game.capture.notes.append(pointed_hold)
	game.arrange_selection={"note":pointed_hold,"document":false,"index":game.capture.notes.size()-1}
	game.dots_mode=true; game.refresh_arrange_controls()
	check(game.dots_button.visible and game.dots_button.text.contains("ADD POINTS"),"Arrange offers ADD POINTS")
	var point_at=pointed_hold.time+.3
	var trail_point=game.field.world.camera.unproject_position(Vector3(game.field.world.lane_x(5),.09,(point_at-game.song_time)*game.field.world.travel_speed()))/Vector2(game.field.viewport.size)
	game.arrange_pointer_event(11,trail_point,true,false,false); game.arrange_pointer_event(11,trail_point,false,true,false)
	check(pointed_hold.get("checkpoints",[]).size()==1,"Tapping the selected trail adds a point")
	var time_before_points_swipe=game.song_time
	game.arrange_pointer_event(12,trail_point,true,false,false)
	game.arrange_pointer_event(12,trail_point+Vector2(0,.12),false,false,false)
	game.arrange_pointer_event(12,trail_point+Vector2(0,.12),false,true,false)
	check(not is_equal_approx(game.song_time,time_before_points_swipe) and game.arrange_selection.get("note")==pointed_hold and pointed_hold.checkpoints.size()==1,"Swiping while adding points scrolls and keeps the note selected")
	game.arrange_pointer_event(13,Vector2(.03,.3),true,false,false); game.arrange_pointer_event(13,Vector2(.03,.2),false,true,false)
	check(game.arrange_selection.get("note")==pointed_hold,"Scrolling beside the highway keeps the selection")
	game.dots_mode=false; game.capture.notes.erase(pointed_hold); game.arrange_selection.clear(); game.refresh_arrange_controls()
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
	check(game.library.save_chart(str(custom_song.id),[SynkChart.note(.5,5)])==OK,"Selection fixture chart is available")
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
	game.song=custom_song; game.save_cover_image(str(custom_song.id),game.load_picked_image(art_path))
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
