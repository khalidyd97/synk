extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var audit=load("res://scripts/chart_audit.gd")
    var hold=SynkChart.note(2,3,"hold"); hold.duration=2
    var slide=SynkChart.note(6,1,"slide"); slide.duration=.05; slide.end_lane=8
    var notes=[hold,SynkChart.note(3,3),slide,SynkChart.note(101,0)]
    var original=notes.duplicate(true); var issues=audit.inspect(notes,100)
    check(issues.size()==3,"Detect overlap, slide speed and overflow")
    check(notes==original,"Validation never mutates notes")
    check(audit.inspect([SynkChart.note(1,0),SynkChart.note(1,2)],100).is_empty(),"Chords across lanes are valid")
    check(audit.inspect([hold,SynkChart.note(4,3)],100).is_empty(),"Note at hold release is allowed")
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.set_mode("editor"); g.document.load_notes(notes); g.refresh_editor()
    g.studio.overview.seek_at(Vector2(10,24+(g.studio.overview.size.y-30)*.5))
    check(absf(g.cursor-g.length()*.5)<.01,"Overview jumps to whole-song position")
    g.features.open_tools("Check")
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/chart-check.png")
    var page=g.features.tabs.get_node("Check").get_child(0)
    page.get_children().back().get_child(1).pressed.emit()
    check(g.mode=="editor" and g.document.selected==1 and g.cursor==3,"Issue button jumps to the affected note")
    g.queue_free(); await process_frame
    print("Chart checks and overview: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
