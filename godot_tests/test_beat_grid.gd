extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.set_mode("editor"); g.document.settings.bpm=120
    var notes=g.document.notes.duplicate(true)
    g.beat_clock.set_offset(.2)
    check(is_equal_approx(SynkChart.snap(.71,120,1,.2),.7),"Snapping respects beat offset")
    check(g.beat_clock.beat_index(.19)==-1 and g.beat_clock.beat_index(.2)==0 and g.beat_clock.beat_index(.7)==1,"Metronome shares grid origin")
    check(g.document.notes==notes,"Grid offset never moves notes")
    g.features.autosave()
    var saved=JSON.parse_string(FileAccess.get_file_as_string(g.features.draft_path()))
    check(saved.chart_settings.beat_offset==.2,"Offset is saved in this chart draft")
    g.beat_clock.enabled=true; g.audio.play(.69); g.beat_clock.last_time=.68; g.beat_clock.last_beat=0
    await create_timer(.04).timeout
    check(g.beat_clock.ticks_emitted>0,"Metronome ticks while editor audio plays")
    var ticks=g.beat_clock.ticks_emitted; g.audio.stream_paused=true
    await create_timer(.1).timeout
    check(g.beat_clock.ticks_emitted==ticks,"Paused audio never ticks")
    g.audio.stop(); g.features.open_tools("Grid")
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/beat-grid.png")
    g.queue_free(); await process_frame
    print("Beat grid and metronome: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
