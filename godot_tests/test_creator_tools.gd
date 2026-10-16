extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func capture(name: String):
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/creator-"+name+".png")
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; g.set_mode("editor"); g.document.settings.bpm=120; g.snap_division=4
    var slide=SynkChart.note(2,1,"slide"); slide.duration=.5; slide.end_lane=3
    slide.path=[{"offset":0.0,"lane":1.0},{"offset":.5,"lane":3.0}]; slide.checkpoints=[.25]
    var flick=SynkChart.note(2.5,2,"flick"); flick.direction=1
    g.document.load_notes([slide,flick,SynkChart.note(4.5,0)])
    g.studio.set_tool("range"); var t=g.timeline; t.range_active=true; t.range_start=2; t.range_end=4; t.update_range(); t.toggle_group_move()
    var start=Vector2(t.lane_x(1),t.time_y(2)); var end=start+Vector2(t.grid().size.x/SynkChart.LANES*2,t.grid().size.y/g.zoom_seconds)
    t.begin(start); t.move_pointer(end); t.finish(end)
    check(g.document.notes[0].time==3 and g.document.notes[0].lane==3 and g.document.notes[1].time==3.5 and g.document.notes[1].lane==4,"Group moves both axes with relative spacing")
    check(g.document.notes[0].path[1].lane==5 and g.document.notes[0].checkpoints==[.25] and g.document.notes[1].direction==1,"Move preserves trails, checkpoints and flick direction")
    check(g.document.notes[2].time==4.5 and t.range_indices==[0,1],"Move never recruits unrelated notes in destination range")
    check(g.document.undo_stack.size()==1,"Entire group drag is one undo step")
    g.document.undo(); g.refresh_editor()
    check(g.document.notes[0].time==2 and t.range_start==2,"Undo restores notes and selection position")
    g.document.redo(); g.refresh_editor()
    start=Vector2(t.lane_x(3),t.time_y(3)); t.begin(start); t.move_pointer(start+Vector2(9999,9999)); t.finish(start+Vector2(9999,9999))
    check(g.document.notes[0].end_lane==9 and g.document.notes[1].lane==8 and g.document.notes[1].time<g.length(),"Group clamps as a unit at lane and song boundaries")
    g.document.undo(); g.refresh_editor()
    check(g.features.save_bookmark("Chorus",3,5),"Save named range")
    check(g.features.save_bookmark("chorus",4,6) and g.features.bookmarks().size()==1,"Same bookmark name updates existing entry")
    check(not g.features.save_bookmark("",1,2) and not g.features.save_bookmark("Bad",2,9999),"Invalid bookmarks rejected")
    var config=JSON.parse_string(FileAccess.get_file_as_string(g.features.draft_path()))
    check(config.chart_settings.bookmarks.size()==1,"Bookmarks persist in chart draft")
    g.features.choose_variant(2)
    check(g.features.bookmarks().is_empty(),"Bookmarks belong only to their chart version")
    g.features.choose_variant(0)
    g.features.jump_bookmark(g.features.bookmarks()[0])
    check(g.cursor==4 and t.range_start==4 and t.range_end==6 and not t.group_mode,"Bookmark restores range for editing or practice")
    g.features.open_tools("Bookmarks"); await capture("bookmarks"); g.features.close_tools()
    var analysis=load("res://scripts/difficulty_analysis.gd")
    var sparse=[SynkChart.note(1,0),SynkChart.note(4,1)]
    var dense: Array=[]
    for i in 100: dense.append(SynkChart.note(1+float(i)/20,i%10))
    check(analysis.analyze(dense,96).level>analysis.analyze(sparse,96).level,"Difficulty increases with density")
    check(analysis.analyze([],96).level==0,"Empty chart is unrated")
    check(analysis.analyze([SynkChart.note(1,0),SynkChart.note(1,2)],96).chords==1,"Analysis counts chord groups")
    g.document.load_notes(dense); g.features.open_tools("Analyze"); await capture("analysis"); g.features.close_tools()
    g.features.remove_bookmark("chorus"); check(g.features.bookmarks().is_empty(),"Bookmark deletion persists")
    g.document.load_notes([SynkChart.note(11,2),SynkChart.note(13,4)])
    g.cursor=10; g.record_here(); g.countdown=0; g.song_time=10.2; g.visual_clock_ready=false; g.ghost_recording=true
    g.capture.notes.append(SynkChart.note(10.1,6)); g.field.world._process(0)
    check(g.field.world.notes.has("ghost0") and g.field.world.notes.ghost0.node.position.z<0,"Ghost existing notes approach before their beat")
    check(g.field.world.notes.has("captured0") and g.capture.notes.size()==1 and g.document.notes.size()==2,"New take stays separate from ghost source")
    if g.field.world.notes.has("ghost0"):
        check(is_equal_approx(float(g.field.world.notes.ghost0.node.get_child(0).material_override.get_shader_parameter("ghost_fade")),.32),"Ghosts are visually faded")
    await capture("ghost")
    g.toggle_ghost_recording(); g.field.world._process(0)
    check(not g.field.world.notes.has("ghost0") and g.field.world.notes.has("captured0"),"Ghost toggle hides guides only")
    g.toggle_arrange(); g.song_time=11.2; g.field.world._process(0)
    check(g.field.world.notes.has("record0"),"Arrange still shows editable original notes")
    g.audio.stop(); g.queue_free(); await process_frame
    print("Creator tools integration: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
