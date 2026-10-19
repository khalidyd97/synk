extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    g.lobby.show_play_browser(); await create_timer(.4).timeout
    var b=g.lobby.browser.play
    b.set_process(false)
    check(b.menu_motion and b.motion!=null,"Song browser actions opt into menu motion")
    var geometry=b.get_global_rect(); var before=b.motion.phase
    b._process(.2)
    check(b.motion.phase!=before,"Visible menu buttons animate")
    b.button_down.emit(); check(b.motion.press==1,"Press starts edge feedback")
    b._process(.1)
    check(b.motion.press>0 and b.motion.press<1,"Press feedback eases away")
    check(b.get_global_rect()==geometry and b.scale==Vector2.ONE,"Animation preserves touch geometry")
    b.disabled=true; before=b.motion.phase; b._process(.2)
    check(b.motion.phase==before,"Disabled buttons stop ambient motion")
    b.disabled=false; g.lobby.show_gateway(); before=b.motion.phase; b._process(.5)
    check(b.motion.phase==before,"Hidden buttons stop motion")
    g.open_lobby_settings()
    for control in g.settings_panel.find_children("*","Button",true,false):
        if control.get_script()==load("res://scripts/settings_action.gd"):
            check(not control.menu_motion and control.motion==null,"Settings stay outside menu animation scope")
    g.close_lobby_settings(); g.set_mode("library"); await process_frame
    check(g.chart_library.record_button.menu_motion and g.chart_library.edit_button.menu_motion,"Library actions animate")
    for control in g.chart_library.versions.get_children():
        if control is Button: check(control.menu_motion,"Dynamically created version buttons animate")
    check(g.results_screen.timing_button.menu_motion,"Results controls animate")
    g.queue_free(); await process_frame
    print("Menu button motion: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
