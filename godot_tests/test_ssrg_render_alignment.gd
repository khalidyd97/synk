extends SceneTree
var failures=0
func check(ok: bool, label: String):
 if not ok: failures+=1;push_error(label)
func freeze(node: Node):
 node.set_process(false);node.set_physics_process(false)
 for child in node.get_children():freeze(child)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1440,640)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.set_mode("play");game.countdown=0
 game.field.sync_projection_style();freeze(game)
 game.field.show();game.field.screen.show();game.field.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var world=game.field.world;world.apply_camera();world.update_ssrg_warp()
 for material in world.track_materials:
  check(is_zero_approx(material.get_shader_parameter("opacity")),"Old rectangular floor cannot tint the SSRG stage")
 check(not world.highway_shadow.visible,"Old floor shadow is hidden in the 2D stage")
 check(world.track_nodes.all(func(node):return not node.visible),"Obsolete floor passes are not drawn")
 var note=SynkChart.note(5,4.5)
 world.build_note_node("early",note)
 var parent:Node3D=world.notes.early.node
 parent.position.z=-.25*world.TRACK_LENGTH
 var head:MeshInstance3D=parent.get_child(0)
 var expected=Vector3(0,.13,world.SSRG_STAGE_DISTANCE*(pow(.75,6)-1))
 var bounds=head.global_transform*head.get_aabb().grow(head.extra_cull_margin)
 check(bounds.has_point(expected),"Culling includes the early note's actual shader-projected position")
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 var image=game.field.viewport.get_texture().get_image()
 var pixel=world.camera.unproject_position(expected)
 var color=image.get_pixelv(Vector2i(pixel))
 check(maxf(color.r,maxf(color.g,color.b))>.55,"Early approach note is actually rendered before its raw depth enters the camera")
 var hold=SynkChart.note(5,0,"hold");hold.duration=1.0
 world.build_note_node("held",hold)
 var held_node:Node3D=world.notes.held.node
 held_node.position.z=.2*world.travel_speed()
 world.set_trail_clip(held_node,.02)
 await process_frame;await RenderingServer.frame_post_draw
 image=game.field.viewport.get_texture().get_image()
 var below=Vector3(world.ssrg_x(0)*(1.0+.15/world.SSRG_STAGE_DISTANCE),.13,.15)
 var below_color=image.get_pixelv(Vector2i(world.camera.unproject_position(below)))
 check(below_color.r<.4 and below_color.g<.4,"Held ribbon clips at the drawn judgment line instead of old raw Z")
 for lanes in [4,7,13]:
  game.ssrg_lane_count=lanes
  for slot in [0,int((lanes-1)/2),lanes-1]:
   var lane=float(slot)*9.0/(lanes-1)
   game.pointers={1:{"position":Vector2(.07+(lane+.5)/10.0*.86,.85)}}
   world.update_finger_beams()
   var beam=world.finger_beams[0]
   check(absf(beam.position.x-world.ssrg_beam_center(lane))<.001,"Beam matches its source channel in %d lanes" % lanes)
   check(absf(beam.position.x-world.ssrg_x(lane))<4.0*world.SSRG_UNIT,"Beam and note share the same channel within original sprite layout tolerance")
   check(is_equal_approx(beam.mesh.size.x,295.0*520.0/606.0*world.SSRG_UNIT),"Beam uses the original 295-unit bottom width projected to judgment")
   check(absf(beam.position.x)+beam.mesh.size.x*.5<world.HIGHWAY_HALF_WIDTH,"Outer beam edge stays inside the highway at judgment")
   var far=beam.position.z-beam.mesh.size.y*.5
   check(absf(far+world.SSRG_BEAM_REACH)<.001,"Beam begins at its original UI y286 apex")
   var flash=game.field.world.ssrg_theme.flash_point(world.ssrg_x(lane))
   var line=world.camera.unproject_position(Vector3(world.ssrg_x(lane),.035,0))
   check(line.distance_to(world.camera.unproject_position(flash))<.001,"Hit flash stays aligned at outer and central lanes")
 game.ssrg_lane_count=13;game.pointers={}
 for slot in [0,3,6,9,12]:
  var lane=float(slot)*.75
  game.pointers[slot]={"position":Vector2(.07+(lane+.5)/10.0*.86,.85)}
 world.update_finger_beams()
 await process_frame;await RenderingServer.frame_post_draw
 game.field.viewport.get_texture().get_image().save_png("res://.tools/ssrg-beams-aligned.png")
 game.pointers={};game.visual_song_time=1.25;game.song_time=1.22;game.visual_clock_ready=true
 game.paused_mode="play";game.set_mode("paused")
 check(is_equal_approx(world.render_time(),1.25),"Pausing retains the displayed note time without snapping")
 game.set_mode("record");game.field.sync_projection_style();world.update_finger_beams()
 check(not game.field.screen.material.get_shader_parameter("ssrg_canvas"),"Recorder restores its postprocessing")
 check(float(world.track_materials[0].get_shader_parameter("opacity"))>0.0,"Recorder restores its original floor")
 check(is_equal_approx(world.finger_beams[0].mesh.size.y,59),"Recorder restores its original beam layout")
 game.set_mode("play");game.countdown=3
 world._process(0)
 check(world.shown_keys.is_empty(),"No notes appear during a new-game countdown")
 print("SSRG render bounds, beam alignment and transition failures: ",failures)
 game.queue_free();await process_frame;quit(failures)

