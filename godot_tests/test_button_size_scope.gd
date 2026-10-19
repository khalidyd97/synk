extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func anchors(n: Control) -> Vector4: return Vector4(n.anchor_left,n.anchor_top,n.anchor_right,n.anchor_bottom)
func run() -> void:
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var editor_buttons: Dictionary={}
    for n in g.studio.find_children("*","Button",true,false): editor_buttons[n]=anchors(n)
    var recorder_buttons: Dictionary={}
    for n in g.record_tools.find_children("*","Button",true,false): recorder_buttons[n]=anchors(n)
    g.open_lobby_settings(); g.settings_panel.show_page("audio"); g.open_sync_helper(); g.close_sync_helper(); g.close_lobby_settings()
    g.lobby.show_play_browser(); g.set_mode("library"); g.set_mode("results")
    g.start_game([SynkChart.note(3,4)],false)
    check(g.pause_button.anchor_right>.08 and g.pause_button.anchor_bottom>.105,"Gameplay pause control has a larger touch target")
    g.toggle_pause()
    var gameplay_pause=g.primary.get_global_rect().size
    g.set_mode("editor"); g.record_here()
    check(is_equal_approx(g.pause_button.anchor_right,.08) and is_equal_approx(g.pause_button.anchor_bottom,.105),"Recorder pause button retains its original dimensions")
    g.toggle_pause()
    check(is_equal_approx(g.modal.anchor_top,.36) and is_equal_approx(g.modal.anchor_bottom,.64),"Recorder pause modal retains its original layout")
    check(is_equal_approx(g.primary.anchor_top,.58) and is_equal_approx(g.primary.anchor_bottom,.88),"Recorder pause actions retain their original dimensions")
    check(g.primary.get_global_rect().size.y<gameplay_pause.y,"Gameplay pause actions enlarge independently of recorder actions")
    for n in editor_buttons: check(anchors(n).is_equal_approx(editor_buttons[n]),"Editor control geometry stays unchanged")
    for n in recorder_buttons: check(anchors(n).is_equal_approx(recorder_buttons[n]),"Recorder control geometry stays unchanged")
    check(anchors(g.studio.record_button).is_equal_approx(Vector4(.46,.02,.56,.075)),"Editor Record keeps its existing toolbar footprint")
    check(g.studio.has_meta("keep_caption_size"),"Editor keeps compact caption sizing")
    g.queue_free(); await process_frame
    print("Button sizing scope: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
