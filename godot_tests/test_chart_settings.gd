extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.set_mode("editor"); var f=g.features
    g.song.bpm=123.0; g.song.beat_offset=.12; g.song.verse2=6.0
    g.prefs.set_value("bookmarks","eclipse",[{"name":"Legacy","start":1.0,"end":2.0}])
    f.load_variant()
    check(g.chart_bpm()==123 and g.chart_offset()==.12 and f.bookmarks().size()==1,"Legacy shared timing and bookmarks migrate into chart defaults")
    g.document.load_notes([SynkChart.note(2,0),SynkChart.note(3,2)])
    f.set_chart_value("bpm",140.0); f.set_chart_value("beat_offset",.25); f.set_chart_value("verse2",5.0)
    f.save_bookmark("Original mark",2,4); g.save_editor()
    check(g.song.bpm==123 and g.song.beat_offset==.12 and g.song.verse2==6,"Chart timing changes never mutate song data")
    f.choose_variant(1)
    check(g.chart_bpm()==123 and g.chart_offset()==.12 and g.section_mark("verse2")==6,"New version inherits legacy song defaults, not another chart's edits")
    check(not f.bookmarks().any(func(b): return b.name=="Original mark"),"Bookmarks do not leak between versions")
    f.set_chart_value("bpm",180.0); f.set_chart_value("beat_offset",.5); f.set_chart_value("verse2",8.0)
    f.save_bookmark("Easy mark",3,6)
    f.choose_variant(0)
    check(g.chart_bpm()==140 and g.chart_offset()==.25 and g.section_mark("verse2")==5,"Switching restores original chart timing")
    f.choose_variant(1)
    check(g.chart_bpm()==180 and g.chart_offset()==.5 and g.section_mark("verse2")==8,"Draft recovery restores Easy timing independently")
    check(f.bookmarks().any(func(b): return b.name=="Easy mark"),"Draft recovery restores chart bookmarks")
    f.save_bookmark("Temporary",5,7)
    g.document.undo(); g.refresh_editor()
    check(not f.bookmarks().any(func(b): return b.name=="Temporary"),"Bookmark edits are undoable")
    g.document.redo(); g.refresh_editor()
    var note_count=g.document.notes.size()
    f.set_chart_value("bpm",190.0); f.autosave()
    var first=JSON.parse_string(FileAccess.get_file_as_string(f.draft_path()))
    f.set_chart_value("bpm",200.0); f.autosave()
    var second=JSON.parse_string(FileAccess.get_file_as_string(f.draft_path()))
    check(first.chart_settings.bpm==190 and second.chart_settings.bpm==200 and g.document.notes.size()==note_count,"Settings-only changes invalidate autosave hash")
    var file="user://settings-share.json"; f.export_chart(file)
    f.set_chart_value("bpm",210.0); f.set_chart_value("beat_offset",.8)
    check(f.import_chart(file)==OK and g.chart_bpm()==200 and g.chart_offset()==.5,"Import/export round-trips chart settings")
    g.document.undo(); g.refresh_editor()
    check(g.chart_bpm()==210 and g.chart_offset()==.8,"Import undo restores settings as well as notes")
    var bad=JSON.parse_string(FileAccess.get_file_as_string(file)); bad.chart_settings.bpm=0
    SynkLibrary.atomic_write(file,bad); var count=g.document.undo_stack.size()
    check(f.import_chart(file)==ERR_INVALID_DATA and g.document.undo_stack.size()==count and g.chart_bpm()==210,"Invalid settings import is atomic")
    f.set_effect("Hit flashes",.4); f.choose_variant(0)
    check(is_equal_approx(f.effect("Hit flashes"),.4),"Global effects stay global when changing charts")
    check(not f.payload(g.document.notes).chart_settings.has("note_shape"),"Global display preferences excluded from chart files")
    f.set_chart_value("bpm",150.0); g.stage_intro_enabled=false
    g.start_game(g.document.notes,false,"full")
    check(g.chart_bpm()==150,"Editor test uses current draft settings")
    g.set_mode("menu"); g.start_game(g.baseline_notes(),false,"full")
    check(g.chart_bpm()==140,"Published Play uses saved settings, not unsaved draft timing")
    g.set_mode("editor")
    check(g.chart_bpm()==150,"Returning to editor keeps draft settings intact")
    g.document.add(5,3); f.recovery_checked=""; var before=g.document.notes.size()
    g.set_mode("record"); g.set_mode("editor")
    check(g.document.notes.size()==before and g.chart_bpm()==150,"Entering editor never overwrites an in-memory take or timing edits with an older draft")
    f.open_tools("Grid")
    check("ORIGINAL" in f.tools_context.text and f.scope_buttons["THIS CHART"].selected,"Timing UI clearly belongs to active chart")
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/chart-level-timing.png")
    f.show_scope("VERSIONS"); f.choose_variant(1); f.show_scope("THIS CHART","Grid")
    var inputs: Array=[]
    for row in f.tabs.get_node("Grid").get_child(0).get_children():
        if row is HBoxContainer:
            for input in row.get_children():
                if input is SpinBox: inputs.append(input)
    check(inputs[0].value==210 and inputs[1].value==.8,"Timing controls refresh to the newly selected version without stale values")
    f.close_tools(); f.open_tools("Authoring")
    check(f.global_settings and not f.tabs.tabs_visible,"Editor preferences are isolated game settings")
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/global-editor-prefs.png")
    g.queue_free(); await process_frame
    print("Chart settings ownership: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
