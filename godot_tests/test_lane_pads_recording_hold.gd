extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func screen_point(g: Control,x: float,z: float) -> Vector2:
    return g.field.world.camera.unproject_position(Vector3(x,.035,z))/Vector2(g.field.viewport.size)
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var w=g.field.world
    for window in [Vector2i(1280,720),Vector2i(1024,600)]:
        root.size=window; await process_frame; await process_frame
        for angle in [w.MIN_ANGLE,29.0,w.MAX_ANGLE]:
            g.highway_angle=angle; w.animate_miss_shake(0)
            for z in [-.95,0.0,.95]:
                var widths: Array=[]
                for lane in SynkChart.LANES:
                    var left=w.lane_x(lane-.5); var right=w.lane_x(lane+.5)
                    widths.append(screen_point(g,right,z).x-screen_point(g,left,z).x)
                    for fraction in [-.48,0.0,.48]:
                        var p=screen_point(g,w.lane_x(lane+fraction),z)
                        var mapped=g.field.input_position(p)
                        check(roundi(SynkCapture.lane(mapped.x))==lane,"Every pad corner maps to its lane")
                        var c=SynkCapture.new()
                        check(c.begin(1,1,mapped,"tap"),"Full pad accepts recorder taps, including outer lanes")
                check(float(widths.max())-float(widths.min())<.00001,"All ten visible cells have equal width")
    root.size=Vector2i(1280,720); g.highway_angle=29; w.animate_miss_shake(0)
    await process_frame; await process_frame
    for edge in [-1,1]:
        var c=SynkCapture.new()
        check(c.begin(1,1,g.field.input_position(screen_point(g,edge*w.PAD_HALF_WIDTH,0)),"tap"),"Exact outer pad edge remains tappable")
    for lane in SynkChart.LANES:
        for fraction in [-.48,.48]:
            for z in [-.95,.95]:
                g.start_game([SynkChart.note(1,lane)],false)
                g.countdown=0; g.song_time=1
                g.pointer_event(1,screen_point(g,w.lane_x(lane+fraction),z),true,false,false)
                check(g.live[0].done and g.judgment_counts.PERFECT==1,"Gameplay judges taps throughout each entire pad")
    g.set_mode("editor"); g.document.load_notes([]); g.cursor=0; g.record_here()
    g.countdown=0; g.song_time=1; g.audio.stop()
    var p=screen_point(g,w.lane_x(4),0)
    g.pointer_event(7,p,true,false,false)
    var initial=g.capture.gestures[7].note.duplicate(true)
    for seconds in [2.0,8.0,30.0,60.0]:
        g.song_time=seconds
        var preview=w.recording_preview(g.capture.gestures[7])
        check(is_equal_approx(float(preview.time)+float(preview.duration),seconds),"Stationary hold preview reaches live judgment line")
        check(float(preview.duration)<=g.note_travel_seconds()+.001,"Long hold preview geometry stays bounded")
        w._process(0)
        check(w.notes.has("gesture7"),"Stationary hold stays visible after travelling offstage")
        check(g.capture.gestures[7].note==initial,"Visual preview never changes recorded gesture data")
    g.countdown_ring.hide(); g.countdown_label.hide()
    g.song_time=30; w._process(0)
    await create_timer(.4).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/recorder-equal-pads-long-hold.png")
    g.song_time=61; g.pointer_event(7,p,false,true,false)
    check(g.capture.notes.size()==1 and g.capture.notes[0].kind=="hold" and is_equal_approx(g.capture.notes[0].duration,60),"Release preserves the full recorded hold duration")
    g.song_time=62
    g.tool="slide"; g.pointer_event(8,p,true,false,false)
    g.song_time=63; g.pointer_event(8,screen_point(g,w.lane_x(6),0),false,false,false)
    g.song_time=75
    var slide=w.recording_preview(g.capture.gestures[8])
    check(slide.kind=="slide" and is_equal_approx(float(slide.time)+float(slide.duration),75),"Paused slide finger keeps extending the live trail")
    check(absf(SynkChart.lane_at(slide,75)-6)<.01,"Stationary slide tail stays at the last finger lane")
    g.capture.gestures.clear(); w._process(0)
    check(not w.notes.has("gesture8"),"Canceled gesture removes its visual trail")
    g.queue_free(); await process_frame
    print("Equal lane pads and stationary recording holds: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
