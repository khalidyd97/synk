extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; g.get_node("SafeAreaPoll").stop()
    g.lobby.show_play_browser(); await process_frame
    var floating=g.floating_text_input
    g.lobby.search.grab_focus(); await process_frame; await process_frame
    check(floating.overlay.visible and floating.source==g.lobby.search,"Focusing an existing search field opens the floating editor")
    floating.single.text="Eclipse"; floating.single.text_changed.emit("Eclipse")
    check(g.lobby.search.text=="Eclipse","Typing updates the original field and its live search")
    floating.finish(false)
    check(g.lobby.search.text=="" and not floating.overlay.visible,"Cancel restores the original field value")
    g.lobby.search.grab_focus(); await process_frame; await process_frame
    floating.single.text="Star"; floating.single.text_changed.emit("Star"); floating.finish(true)
    check(g.lobby.search.text=="Star" and not floating.overlay.visible,"Done commits without reopening the floating field")
    var text=TextEdit.new(); g.ui.add_child(text); text.position=Vector2(100,100); text.size=Vector2(300,100)
    text.text="one\ntwo"; text.grab_focus(); await process_frame; await process_frame
    check(floating.multiple.visible and floating.source==text,"Dynamically created multiline inputs are supported")
    floating.multiple.text="one\ntwo\nthree"; floating.multiple.text_changed.emit(); floating.finish(true)
    check(text.text=="one\ntwo\nthree","Multiline text retains its line breaks")
    var number=SpinBox.new(); g.ui.add_child(number); number.position=Vector2(100,100); number.value=12
    number.get_line_edit().grab_focus(); await process_frame; await process_frame
    floating.single.text="42"; floating.single.text_changed.emit("42"); floating.finish(true)
    check(number.value==42,"Numeric SpinBox editing commits through its normal validation")
    var dynamic=LineEdit.new(); g.ui.add_child(dynamic); dynamic.position=Vector2(100,200); dynamic.size=Vector2(300,60)
    dynamic.grab_focus(); await process_frame; await process_frame
    check(floating.source==dynamic,"New fields are detected without manual registration")
    g.set_safe_area_pixels(Rect2(120,0,2280,1080),Vector2(2400,1080))
    floating.layout_for_keyboard(DisplayServer.window_get_size().y*.45)
    var keyboard_top=g.size.y*.55
    check(floating.panel.position.y+floating.panel.size.y<=keyboard_top+1,"Floating field sits above the software keyboard")
    check(floating.panel.position.x>=g.safe_area_rect.position.x,"Floating field respects the notch safe area")
    var escape=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
    g._unhandled_input(escape)
    check(not floating.overlay.visible and g.mode=="menu","Back dismisses text entry without leaving the current screen")
    text.queue_free(); number.queue_free(); dynamic.queue_free()
    g.start_game([SynkChart.note(2,4)],false); g.countdown=0; g.song_time=1
    var w=g.field.world
    var laser_counts=[]
    for stream in w.ambient_streaks: laser_counts.append(stream.amount)
    var hold=SynkChart.note(0,4,"hold"); hold.duration=10
    var slide=hold.duplicate(true); slide.kind="slide"
    for note in [hold,slide]:
        g.start_game([note],true); g.countdown=0; g.song_time=1; g.live[0].started=true
        w.update_ambient_particles(0)
        check(w.ambient_streaks.size()==2,"Only the regular two laser streams exist")
        for i in 2: check(w.ambient_streaks[i].amount==laser_counts[i],"Hold and slide notes do not increase laser density")
    g.queue_free(); await process_frame
    print("Floating text entry and steady lasers: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
