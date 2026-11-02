extends SceneTree
var failures=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func freeze(node:Node):
 node.set_process(false);node.set_physics_process(false)
 for child in node.get_children():freeze(child)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1564,720);AudioServer.set_bus_mute(0,true)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.stage_intro_enabled=false;game.ssrg_playable_run=false;game.note_shape="circle";game.highway_colors="theme";game.note_size=1
 var hold=SynkChart.note(3.3,2,"hold");hold.duration=.7
 var slide=SynkChart.note(3.65,10,"slide");slide.duration=.7;slide.end_lane=8
 slide.path=[{"offset":0.0,"lane":10.0},{"offset":.7,"lane":8.0}]
 var notes=[SynkChart.note(3.12,6),hold,SynkChart.note(3.7,8),slide,SynkChart.note(4.1,4),SynkChart.note(4.6,6)]
 game.start_game(notes,false);game.countdown=0;game.resume_countdown=0;game.song_time=3;game.visual_song_time=3;game.audio.stop()
 var world=game.field.world
 while world.prebuilding:world.step_prebuild()
 freeze(game);game.app_login.hide()
 for child in game.get_children():
  if child is CanvasLayer and child.layer>=90:child.hide()
 game.field.show();game.field.screen.show();game.field.modulate=Color.WHITE;game.field.screen.modulate=Color.WHITE
 game.field.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 game.score_panel.modulate=Color.WHITE
 game.stage_intro.begin(game.cover_texture_for_id("eclipse"),Color.WHITE,"Eclipse","TEST",true);game.stage_intro.hide()
 game.stage_intro.play_cover._process(0)
 game.displayed_score=84520
 var expected_time=game.note_travel_seconds()
 var expected:Array[Vector2]=[]
 world.apply_camera();world.update_ssrg_warp()
 for lane in 13:expected.append(game.field.project(lane,0))
 for style in ["aurora","solar"]:
  game.change_highway_look("style",style);world.apply_camera();world.update_ssrg_warp();game.field.sync_projection_style()
  check(world.concept_theme.active and world.concept_theme.visible,"Dedicated geometry is active for "+style)
  var bar=world.get_node("JudgmentPads")
  var top=world.ssrg_warped_z(bar.position.z-world.JUDGMENT_DEPTH*.5*bar.scale.y)
  var bottom=world.ssrg_warped_z(bar.position.z+world.JUDGMENT_DEPTH*.5*bar.scale.y)
  check(absf(top+49*world.SSRG_UNIT)<.001 and absf(bottom-81*world.SSRG_UNIT)<.001,"Bar matches the original SSRG lower-screen judgment area")
  check(top<0 and bottom>0,"The unchanged hit plane lies inside the bar")
  var painted=world.concept_theme.road_sprite
  check(painted.mesh is QuadMesh,"Highway is a flat image sprite")
  check(world.concept_theme.get_child_count()==14,"Only one painted highway and thirteen flat markers are built")
  var inset=painted.mesh.size.x*.5-world.concept_theme.RAIL_FRAME_WIDTH
  check(is_equal_approx(inset,world.FRAME_HALF_WIDTH),"Painted frames remain outside the exact playable boundary")
  check(world.concept_theme.road_material.get_shader_parameter("artwork")==world.concept_theme.ROAD_IMAGES[style],"Road and full rail frames come from the selected image")
  check(not world.gold_nodes.any(func(n):return n.visible) and not world.neon_nodes.any(func(n):return n.visible),"Other rails never overlap the new theme")
  check(not world.ssrg_theme.active and not game.ssrg_playable_run,"Visual theme never changes chart rules")
  check(world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and game.note_travel_seconds()==expected_time,"SSRG projection and timing are unchanged")
  check(int(world.cover_material.get_shader_parameter("concept_style"))==(1 if style=="aurora" else 2),"Correct black backdrop mode is selected")
  check(game.prefs.get_value("highway","style","")==style,"Selection is saved")
  for lane in 13:
   var point=game.field.project(lane,0)
   check(point.distance_to(expected[lane])<.001,"Theme preserves every judgment centre")
   var touch=game.field.input_position(point/Vector2(game.field.viewport.size))
   check(absf(SynkCapture.lane(touch.x)-lane)<.001,"Every visible lane remains touch aligned")
  for i in notes.size():
   world.build_note_node("concept_%d" % i,notes[i]);world.notes["concept_%d" % i].node.position.z=(3-float(notes[i].time))*world.travel_speed()
  world.update_cover_backdrop()
  game.stage_intro.play_cover._process(0)
  var card=game.stage_intro.play_cover.target_rect()
  var entrance=game.field.get_global_transform_with_canvas()*game.field.project(world.CENTER_LANE,1)
  var centre=game.stage_intro.play_cover.get_global_transform_with_canvas()*card.get_center()
  check(absf(centre.x-entrance.x)<1,"Album art anchors above the highway entrance")
  if DisplayServer.get_name()!="headless":
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.tools/new-highway-review/%s-gameplay.png" % style)
   var rendered=game.field.viewport.get_texture().get_image()
   for depth in [-.3,.3]:
    var bar_point=Vector2i(world.camera.unproject_position(Vector3(0,.035,world.ssrg_warped_z(depth))))
    check(rendered.get_pixelv(bar_point).v>.05,"Painted judgment bar is visible above and below the hit centre")
   var clear_point=Vector2i(world.camera.unproject_position(Vector3(0,.008,world.SSRG_STAGE_DISTANCE*(.65-1))))
   check(rendered.get_pixelv(clear_point).v<.01,"Highway interior stays solid black with no baked lane lines or reflections")
   for side in [-1,1]:
    var q=.8
    var rail_point=Vector3(side*(world.FRAME_HALF_WIDTH+.4)*q,.008,world.SSRG_STAGE_DISTANCE*(q-1))
    var at=Vector2i(world.camera.unproject_position(rail_point));var brightest=0.0
    for x in range(-3,4):
     for y in range(-3,4):brightest=maxf(brightest,rendered.get_pixelv(at+Vector2i(x,y)).v)
    check(brightest>.15,"Both painted rail frames are visible in the actual render")
  var clock=world.animation_time;game.mode="paused";world.animate_effects(.25)
  check(world.animation_time==clock,"Pause freezes stage drift and note animation")
  game.mode="play"
  game.rail_color="ff4d6d";world.refresh_highway_look()
  check(world.concept_theme.road_material.get_shader_parameter("tint").is_equal_approx(Color("ff4d6d")),"Custom rail colors remain supported")
  game.rail_color="";world.refresh_highway_look()
 game.set_mode("record");world.refresh_highway_look()
 check(not world.concept_theme.visible and int(world.cover_material.get_shader_parameter("concept_style"))==0,"Recording never inherits the decorative stage")
 check(world.gold_nodes.all(func(n):return n.visible),"Recorder retains its readable rails")
 check(is_equal_approx(world.get_node("JudgmentPads").scale.y,1.0) and is_zero_approx(world.get_node("JudgmentPads").position.z),"Leaving a theme restores the standard judgment sprite size and position")
 game.set_mode("play");game.ssrg_playable_run=true;game.ssrg_playable_previous_style="solar";game.highway_style="ssrg";world.refresh_highway_look()
 check(not world.concept_theme.visible and world.ssrg_theme.active,"Imported SSRG runs retain their source stage")
 game.set_mode("menu")
 check(game.highway_style=="solar","Returning from SSRG restores the selected new theme")
 check(game.settings_panel.style_tiles.size()==5 and game.settings_panel.style_tiles.has("aurora") and game.settings_panel.style_tiles.has("solar"),"Both styles appear in settings")
 game.stage_intro.play_cover._process(0)
 game.open_lobby_settings();game.settings_panel.show_page("visuals",false);game.settings_panel.show_section("highway",false)
 if DisplayServer.get_name()!="headless":
  await create_timer(.4).timeout
  var section=game.settings_panel.pages.visuals.sections.highway
  section.scroll.scroll_vertical=300
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/new-highway-review/style-picker.png")
 game.queue_free();await process_frame
 var restored=load("res://scenes/main.tscn").instantiate();root.add_child(restored)
 await process_frame;await process_frame
 check(restored.highway_style=="solar","New style survives restarting the game")
 restored.queue_free();await process_frame
 print("Aurora/Solar geometry, SSRG alignment, customization, pause and persistence failures: ",failures)
 quit(failures)
