extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func make_hold(at: float,lane: int,duration: float) -> Dictionary:
    var n=SynkChart.note(at,lane,"hold"); n.duration=duration; return n
func run() -> void:
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.set_mode("editor")
    var r=g.recorder; r.set_process(false)
    g.document.load_notes([SynkChart.note(1,1),SynkChart.note(4.5,2),make_hold(5,3,.5),SynkChart.note(9,4)],{"bpm":120.0,"beat_offset":.1})
    var original=g.document.notes.duplicate(true)
    g.timeline.range_active=true; g.timeline.range_start=4; g.timeline.range_end=8
    r.use_range=true; r.replace=true; r.pre_roll=1; r.pass_kind="tap"; r.locked=["hold"]
    g.cursor=6; g.record_here()
    check(r.region==Vector2(4,8) and is_equal_approx(g.start_position,2),"Punch-in uses selection and one audible bar of lead-in")
    check(not r.can_capture(3.99) and r.can_capture(4) and not r.can_capture(8),"Input is gated at punch boundaries")
    check(r.capture_tool()=="tap" and not r.writable(make_hold(5,1,1)),"Pass recording excludes locked/completed types")
    g.countdown=0; g.song_time=3.5
    g.pointer_event(1,Vector2(.5,.8),true,false,false)
    check(g.capture.gestures.is_empty(),"Pre-roll cannot accidentally capture notes")
    r.pre_roll=4; r.replace=false; r.locked.clear()
    check(r.config.pre_roll==1 and r.config.replace and not r.writable(make_hold(5,1,1)),"Options stay frozen for the active session")
    g.capture.notes=[SynkChart.note(6,6),SynkChart.note(8.2,7)]
    g.song_time=7; g.stop_take()
    check(g.mode=="editor" and r.review!=null,"Stopping opens take review in editor")
    check(g.document.notes.size()==4 and g.document.notes.any(func(n): return n.kind=="hold"),"Replacement preserves locked types and outside notes")
    check(not g.document.notes.any(func(n): return float(n.time)==4.5) and g.document.notes.any(func(n): return float(n.time)==6),"Replacement changes only eligible notes in the punch")
    check(not g.document.notes.any(func(n): return float(n.time)==8.2),"Notes outside punch are rejected")
    check(r.highlights.size()==1,"New notes are highlighted for review")
    await create_timer(.45).timeout
    await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://.tools/recorder-take-review.png")
    r.undo_take(); r.close_review()
    check(g.document.notes==original,"Undo restores all replaced notes in one action")
    g.document.redo(); check(g.document.notes.any(func(n): return float(n.time)==6),"Take replacement supports redo")
    g.document.undo()
    r.config={"quantize":"strict","division":4,"pass":"all","locked":[]}
    r.region=Vector2(4,8)
    var slide=SynkChart.note(4.16,1,"slide"); slide.duration=.41; slide.end_lane=3
    slide.path=[{"offset":0.0,"lane":1.0},{"offset":.41,"lane":3.0}]; slide.checkpoints=[.2]
    var prepared=r.prepare([slide])
    check(prepared.size()==1 and is_equal_approx(prepared[0].time,4.1),"Strict quantization uses chart BPM and beat offset")
    check(is_equal_approx(prepared[0].duration,.5) and is_equal_approx(prepared[0].path[-1].offset,.5),"Quantization preserves a valid slide path and duration")
    check(SynkChart.valid(prepared),"Quantized slides remain valid chart data")
    r.config.quantize="soft"
    prepared=r.prepare([SynkChart.note(4.16,1)])
    check(is_equal_approx(prepared[0].time,4.13),"Soft snap moves halfway toward the grid")
    r.config.quantize="free"
    check(is_equal_approx(r.prepare([SynkChart.note(4.16,1)])[0].time,4.16),"Free mode preserves expressive timing")
    var diff=r.comparison([SynkChart.note(5,1),SynkChart.note(6,2)],[SynkChart.note(5.04,1),SynkChart.note(7,3)])
    check(diff.added==1 and diff.removed==1 and diff.shifted==1 and is_equal_approx(diff.ms,40),"Comparison distinguishes added, removed and moved notes")
    var moving=SynkChart.note(4,1,"slide"); moving.duration=3; moving.end_lane=4
    moving.path=[{"offset":0.0,"lane":1.0},{"offset":3.0,"lane":4.0}]
    r.takes=[{"notes":[moving,SynkChart.note(7,2)]},{"notes":[SynkChart.note(5,3),SynkChart.note(6.5,6)]}]
    var combined=r.combine(0,1,6)
    check(combined.size()==2 and combined[0].duration==2 and combined[1].time==6.5,"Combining takes splices at chosen time and trims crossing sustains")
    check(SynkChart.valid(combined),"Spliced slide remains valid")
    var bad=[SynkChart.note(5,1),SynkChart.note(5.04,1),make_hold(6,2,.08)]
    check(r.quality(bad).size()>=2,"Quality checks catch double taps and short sustains")
    r.use_range=true; r.replace=false; r.pre_roll=0; r.pass_kind="all"; r.locked=[]; r.loop_takes=true
    g.cursor=4; g.record_here(); g.countdown=0; g.song_time=8; g.capture.notes=[SynkChart.note(5,2)]
    r._process(.016)
    check(g.mode=="record" and r.takes.size()==1 and g.capture.notes.is_empty(),"Loop recording banks an attempt and starts a clean take")
    check(g.document.notes==original,"Loop takes do not destructively change the chart")
    g.countdown=0; g.song_time=7; g.capture.notes=[SynkChart.note(6,3)]; g.stop_take()
    check(r.takes.size()==2 and r.review!=null,"Manual stop presents every loop attempt")
    r.select_take(0); check(g.document.notes.any(func(n): return n.time==5 and n.kind=="tap" and abs(int(n.lane)-3)>=3),"Selecting a banked attempt restores its tap with room beside the locked hold")
    g.loop_enabled=true; g.loop_a=0; g.loop_b=1
    r.preview(); check(r.reviewing_audio and g.audio.playing,"Take replay starts without inheriting editor loop bounds")
    check(not r.review_panel.visible and r.replay_return.visible,"Take replay shows the entire timeline with an accessible return control")
    g._audio_finished(); check(not r.reviewing_audio and not g.audio.playing,"Review playback never restarts the editor loop at song end")
    check(r.review_panel.visible and not r.replay_return.visible,"Playback completion restores take review")
    g.loop_enabled=false
    r.retry(); check(g.mode=="record" and r.takes.size()==2 and g.document.notes==original,"Retry rolls back provisional edits and preserves take bank")
    g.countdown=0; g.song_time=5; g.capture.notes=[SynkChart.note(4.5,4)]
    g.toggle_pause()
    check(g.mode=="paused" and g.pause_home.text=="REVIEW TAKE" and g.pause_restart.text=="RETRY TAKE","Recorder pause labels match recorder actions")
    g.primary.pressed.emit()
    check(g.mode=="record" and g.resume_countdown>0,"Resume returns to recording with a countdown")
    g.resume_countdown=0; g.toggle_pause(); g.pause_home.pressed.emit()
    check(g.mode=="editor" and r.review!=null,"Pause review returns to the take, never the lobby")
    r.keep(); r.loop_takes=false; g.cursor=4; g.record_here(); g.countdown=0; g.song_time=5
    g.audio.play(5); g.toggle_arrange(); check(g.arranging and g.audio.stream_paused,"Correction pauses audio without leaving recorder")
    g.toggle_pause(); g.toggle_pause(); check(g.mode=="record" and g.arranging and g.audio.stream_paused,"Resuming a correction preserves its paused transport")
    g.stop_take(); r.keep()
    var before_cancel=g.document.notes.duplicate(true); var undo_count=g.document.undo_stack.size()
    r.replace=true; g.record_here(); g.stop_take()
    check(g.document.notes==before_cancel and g.document.undo_stack.size()==undo_count,"An empty or cancelled replacement take cannot erase the existing section")
    r.keep()
    r.show_setup(); await create_timer(.5).timeout
    await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://.tools/recorder-setup.png")
    check(r.setup!=null,"Setup is accessible in editor")
    r.setup.queue_free(); r.setup=null
    g.queue_free(); await process_frame
    print("Recorder workflow: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
