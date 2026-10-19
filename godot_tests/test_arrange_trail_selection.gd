extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func point(g: Control,n: Dictionary,at: float,side: float=0) -> Vector2:
    var w=g.field.world
    return w.camera.unproject_position(Vector3(w.lane_x(SynkChart.lane_at(n,at))+side,w.trail_height(),(at-g.song_time)*w.travel_speed()))/Vector2(g.field.viewport.size)
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.recorder.set_process(false); g.stage_intro_enabled=false
    g.set_mode("editor"); g.record_here(); g.countdown=0; g.toggle_arrange(); g.song_time=10
    g.document.notes=[]
    var hold=SynkChart.note(1,4,"hold"); hold.duration=12
    var slide=SynkChart.note(1,2,"slide"); slide.duration=12; slide.end_lane=6
    slide.path=[{"offset":0.0,"lane":2.0},{"offset":7.0,"lane":6.0},{"offset":9.0,"lane":3.0},{"offset":12.0,"lane":6.0}]
    for note in [hold,slide]:
        g.capture.notes=[note]; g.arrange_selection.clear()
        var at=10-minf(.6,g.note_travel_seconds()*.4)
        var p=point(g,note,at)
        check(g.song_time-float(note.time)>g.note_travel_seconds(),"Fixture head is offscreen")
        g.arrange_pointer_event(1,p,true,false,false)
        check(not g.arrange_selection.is_empty() and g.arrange_selection.note==note,"Offscreen head can be selected through the "+note.kind+" body")
        var original=note.duplicate(true)
        g.arrange_pointer_event(1,p,false,false,false)
        check(note==original,"Grabbing the middle does not move the note")
        g.arrange_pointer_event(1,p,false,true,false)
        for width in [.3,1.5]:
            g.hold_trail_width=width
            var edge=point(g,note,at,g.field.world.TRAIL_HALF*.65*width*.8)
            check(g.arrange_note_distance(note,edge)<.09,"Selectable ribbon follows configured width")
        g.hold_trail_width=1
    g.capture.notes=[]; g.document.notes=[slide]; var at=9.5; var p=point(g,slide,at)
    g.arrange_pointer_event(2,p,true,false,false)
    check(g.arrange_selection.get("document",false),"Existing chart trails can also be selected")
    var initial_lane=slide.lane; var original=slide.duplicate(true)
    var moved=point(g,slide,at,g.field.world.LANE_WIDTH)
    g.arrange_pointer_event(2,moved,false,false,false)
    check(slide.lane==initial_lane+1,"Dragging from slide body shifts by the grabbed lane delta")
    check(is_equal_approx(slide.time,original.time),"Horizontal body drag preserves timing")
    g.arrange_pointer_event(2,moved,false,true,false)
    g.recorder.config.locked=["slide"]; g.arrange_selection.clear()
    g.arrange_pointer_event(3,point(g,slide,at),true,false,false)
    check(g.arrange_selection.is_empty(),"Locked trails stay protected")
    g.queue_free(); await process_frame
    print("Arrange trail selection: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
