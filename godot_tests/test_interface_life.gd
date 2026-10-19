extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    g.open_lobby_settings(); await process_frame
    var b=g.settings_panel.nav_buttons.audio; var life=b.get_node("InterfaceLife")
    var geometry=b.get_global_rect(); var before=life.motion.phase
    await create_timer(.15).timeout
    check(life.motion.phase!=before,"Visible settings animate")
    check(b.get_global_rect()==geometry,"Decoration preserves layout and touch bounds")
    b.button_down.emit(); check(life.motion.press>0,"Button taps trigger feedback")
    var dynamic=Button.new(); g.settings_panel.canvas.add_child(dynamic); await process_frame; await process_frame
    check(dynamic.has_node("InterfaceLife"),"Dynamically created controls are included")
    dynamic.queue_free(); g.close_lobby_settings(); await process_frame
    check(not life.is_processing(),"Hidden interface stops its animation drivers")
    check(g.field.find_children("InterfaceLife","",true,false).is_empty(),"Highway receives no interface animation")
    check(not g.pause_button.has_node("InterfaceLife") and not g.score_panel.has_node("InterfaceLife"),"Gameplay HUD stays unchanged")
    g.start_game([SynkChart.note(3,4)],false); await process_frame
    for scope in [g.studio,g.settings_panel,g.record_tools,g.sync_helper]:
        for driver in scope.find_children("InterfaceLife","",true,false): check(not driver.is_processing(),"Menu motion sleeps during gameplay")
    g.queue_free(); await process_frame
    print("Interface life: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
