extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func screen(g: Control,lane: float) -> Vector2:
    return g.field.world.camera.unproject_position(Vector3(g.field.world.lane_x(lane),.035,0))/Vector2(g.field.viewport.size)
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; g.set_mode("editor"); g.document.load_notes([]); g.cursor=0; g.record_here()
    g.audio.stop(); g.countdown=0; var w=g.field.world; w.set_process(false)
    g.song_time=1; g.pointer_event(1,screen(g,4),true,false,false)
    g.song_time=1.045; g.pointer_event(2,screen(g,5),true,false,false)
    g.song_time=1.1; g.pointer_event(2,screen(g,5),false,true,false)
    g.song_time=1.12; g.pointer_event(1,screen(g,4),false,true,false)
    var notes=g.capture.notes
    check(notes.size()==2 and notes[0].time==notes[1].time,"Recorder event path aligns chord timing")
    check(absf(float(notes[0].lane)-float(notes[1].lane))*w.LANE_WIDTH>w.NOTE_WIDTH*g.note_size,"Actual note width determines the automatic gap")
    g.song_time=1.4; w._process(0)
    var heads: Array=[]
    for i in notes.size():
        var head=w.notes["captured"+str(i)].node.get_child(0)
        heads.append(w.camera.unproject_position(head.global_position))
    check(absf(heads[0].y-heads[1].y)<.1,"Chord heads render on the same horizontal line")
    await create_timer(.25).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/recorder-auto-chord-layout.png")
    var fixed=SynkChart.note(3,4); var original=fixed.duplicate(true)
    g.document.load_notes([fixed]); g.capture.notes.clear(); g.capture.gestures.clear(); g.song_time=3.03
    g.pointer_event(3,screen(g,4),true,false,false); g.song_time=3.13; g.pointer_event(3,screen(g,4),false,true,false)
    check(g.document.notes[0]==original,"Saved chart obstacles remain unchanged during overdub")
    check(g.capture.notes[0].time==3.0 and abs(int(g.capture.notes[0].lane)-4)>=3,"Overdub aligns to an existing head and finds a different lane")
    g.recorder.region=Vector2(4,8); g.capture.notes.clear(); g.capture.gestures.clear()
    g.document.load_notes([SynkChart.note(3.97,2)]); g.song_time=4.01
    g.pointer_event(4,screen(g,2),true,false,false); g.song_time=4.10; g.pointer_event(4,screen(g,2),false,true,false)
    check(g.capture.notes[0].time>=4,"Near-boundary chord snapping cannot move a note outside the punch range")
    var prepared=g.recorder.prepare(g.capture.notes)
    check(prepared.size()==1,"Punch-boundary notes survive take preparation")
    var new_notes=[SynkChart.note(6,4),SynkChart.note(6,5)]
    g.space_authored_notes(new_notes,[])
    check(abs(int(new_notes[0].lane)-int(new_notes[1].lane))>=3,"Editor creation/paste shares the same spacing rule")
    print("Recorder chord layout integration: "+("PASS" if failures==0 else "FAIL"))
    g.queue_free(); await process_frame; quit(failures)

