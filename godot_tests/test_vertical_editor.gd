extends SceneTree
var failures=0
func check(value: bool,message: String) -> void:
    if not value: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func screen_touch(index: int,point: Vector2,pressed: bool) -> InputEventScreenTouch:
    var event=InputEventScreenTouch.new(); event.index=index; event.position=point; event.pressed=pressed; return event
func run():
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false); game.stage_intro_enabled=false
    game.document.load_notes([]); game.set_mode("editor"); game.zoom_seconds=8
    var timeline=game.timeline
    timeline.view_start=0
    await process_frame
    check(timeline.time_y(4)>timeline.time_y(2),"Time runs downward")
    check(timeline.lane_x(8)>timeline.lane_x(2),"Lanes run across the timeline")
    for kind in SynkChart.TYPES:
        game.studio.set_tool(kind)
        var time=1.0+SynkChart.TYPES.find(kind)
        var point=Vector2(timeline.lane_x(2),timeline.time_y(time))
        timeline.begin(point); timeline.finish(point)
        check(game.document.selection().kind==kind,"Place "+kind+" directly on grid")
    check(game.document.notes.size()==4,"One note per placement gesture")
    check(game.studio.direction_group.visible and not game.studio.duration_group.visible,"Flick inspector shows direction only")
    game.studio.change_note("direction",3)
    check(game.document.selection().direction==3,"Flick direction can be changed")
    game.studio.set_tool("select")
    game.document.selected=1; game.refresh_editor()
    var hold=game.document.selection()
    var tail=Vector2(timeline.lane_x(hold.end_lane),timeline.time_y(hold.time+hold.duration))
    timeline.begin(tail); timeline.move_pointer(Vector2(timeline.lane_x(2),timeline.time_y(3.5))); timeline.finish(Vector2(timeline.lane_x(2),timeline.time_y(3.5)))
    check(is_equal_approx(hold.duration,SynkChart.snap(3.5,game.song.bpm,game.snap_division)-float(hold.time)),"Hold endpoint drag changes duration")
    check(game.studio.duration_group.visible and not game.studio.direction_group.visible,"Hold inspector shows duration")
    game.document.undo(); game.refresh_editor()
    check(is_equal_approx(game.document.notes[1].duration,60.0/game.song.bpm),"Undo restores hold duration")
    game.document.selected=2
    var slide=game.document.selection(); slide.duration=2.0; slide.end_lane=7
    game.refresh_editor()
    var path_point=Vector2(timeline.lane_x(SynkChart.lane_at(slide,4.0)),timeline.time_y(4.0))
    timeline.begin(path_point); timeline.move_pointer(Vector2(timeline.lane_x(6),timeline.time_y(4.1))); timeline.finish(Vector2(timeline.lane_x(6),timeline.time_y(4.1)))
    check(slide.path.size()==3,"Slide trail tap adds a shape point")
    check(slide.path[1].lane>5.5,"Slide point drags across lanes")
    check(game.studio.end_lane_group.visible and game.slide_tools.visible,"Slide inspector exposes path controls")
    check(SynkChart.valid(game.document.notes),"Edits preserve valid chart data")
    var count=game.document.notes.size()
    var zoom=game.zoom_seconds
    timeline._gui_input(screen_touch(0,Vector2(timeline.lane_x(0),timeline.time_y(.2)),true))
    timeline._gui_input(screen_touch(1,Vector2(timeline.lane_x(8),timeline.time_y(.2)),true))
    var drag=InputEventScreenDrag.new(); drag.index=1; drag.position=Vector2(timeline.lane_x(9),timeline.time_y(.2))
    timeline._gui_input(drag)
    timeline._gui_input(screen_touch(1,drag.position,false)); timeline._gui_input(screen_touch(0,Vector2.ZERO,false))
    check(game.zoom_seconds<zoom and game.document.notes.size()==count,"Pinch zoom does not create notes")
    check(not "song_panel" in game.studio and game.studio.inspector.visible,"Song details are edited from the song list, not the editor")
    game.document.selected=2; game.refresh_editor()
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/vertical-editor-slide.png")
    game.cursor=4.0
    game.test_editor_here()
    check(game.mode=="play" and game.start_position>3.0 and game.start_position<4.0,"Test starts two beats before cursor")
    for entry in game.live: check(entry.note.time>=game.start_position,"Test excludes earlier notes")
    print("Vertical editor integration: ","PASS" if failures==0 else "%d FAILED" % failures)
    quit(0 if failures==0 else 1)
