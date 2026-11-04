extends SceneTree
func _initialize():run.call_deferred()
func run():
 assert(SynkChart.LANES==13 and SynkChart.MAX_LANE==12 and SynkChart.FORMAT_VERSION==3)
 var old=SynkChart.note(2,0,"slide");old.lane=2.25;old.end_lane=9;old.duration=1.0
 old.path=[{"offset":0.0,"lane":2.25},{"offset":1.0,"lane":9.0}];old.checkpoints=[.5]
 var legacy={"version":2,"song_id":"migration","notes":[old]}
 var migrated=SynkChart.notes_from_file(legacy)
 assert(migrated[0].lane==3 and migrated[0].end_lane==12 and migrated[0].path[-1].lane==12)
 assert(old.lane==2.25 and old.path[-1].lane==9,"Loading never modifies the original data")
 assert(migrated[0].time==2 and migrated[0].duration==1 and migrated[0].checkpoints==[.5],"Migration keeps every timing and checkpoint")
 assert(SynkChart.notes_from_file({"version":3,"notes":migrated})==migrated,"New charts are never converted twice")
 var integer_slide=old.duplicate(true);integer_slide.lane=2;integer_slide.end_lane=7
 integer_slide.path=[{"offset":0.0,"lane":2.0},{"offset":.5,"lane":4.5},{"offset":1.0,"lane":7.0}]
 var fitted=SynkChart.notes_from_file({"version":2,"notes":[integer_slide]})[0]
 assert(fitted.path[0].lane==fitted.lane and fitted.path[-1].lane==fitted.end_lane and fitted.path[1].lane==6,"Converted curves meet their head and tail while preserving the interior")
 var folder="user://thirteen_lanes_"+str(Time.get_ticks_usec());var library=SynkLibrary.new(folder)
 var file=folder.path_join("charts/migration.json");SynkLibrary.atomic_write(file,legacy)
 var before=FileAccess.get_sha256(file)
 assert(library.load_chart("migration")[0].lane==3 and FileAccess.get_sha256(file)==before,"Old chart bytes remain intact")
 var capture=SynkCapture.new()
 for lane in 13:
  var p=Vector2(.07+.86*(lane+.5)/13,.765)
  assert(capture.begin(lane,3+lane,p,"tap"))
  var n=capture.end(lane,3.05+lane,p)
  assert(n.lane==lane,"Recorder can author every lane")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.stage_intro_enabled=false;game.ssrg_playable_run=false
 game.start_game([SynkChart.note(5,12)],false);game.countdown=0;game.set_process(false)
 var world=game.field.world
 for mode in ["play","record"]:
  game.set_mode(mode);world.apply_camera();world.update_ssrg_warp()
  var previous=-INF
  for lane in 13:
   var point=game.field.project(lane,0)
   assert(point.x>previous,"All thirteen lane centres are distinct")
   previous=point.x
   var touch=game.field.input_position(point/Vector2(game.field.viewport.size))
   assert(absf(SynkCapture.lane(touch.x)-lane)<.001,"Touch positions agree in gameplay and recording")
 game.set_mode("editor")
 await process_frame
 game.document.add(2,12)
 assert(game.document.selection().lane==12,"Studio can create lane thirteen")
 for lane in 13:assert(game.timeline.lane(game.timeline.lane_x(lane))==lane,"Studio grid exposes thirteen lanes")
 for child in game.get_children():
  if child is CanvasLayer and child.layer>=90:child.hide()
 if DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/synk-ssrg-rebuild/studio-13.png")
 game.queue_free();await process_frame
 print("Thirteen-lane chart migration, recorder, input and studio: PASS")
 quit()
