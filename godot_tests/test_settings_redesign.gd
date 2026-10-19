extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
    await create_timer(.55).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/settings-new-"+name+".png")
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var s=g.settings_panel; var original=g.document.notes.duplicate(true); var config=g.document.settings.duplicate(true)
    g.highway_angle=29; g.open_lobby_settings()
    check(g.highway_angle==29 and s.highway_angle_input.value==29,"Opening settings preserves exact saved values without rounding")
    check(s.pages.size()==4 and s.pages.gameplay.root.visible,"Settings has four scoped global pages")
    await shot("gameplay")
    s.note_speed_input.plus.pressed.emit(); check(g.note_speed==1.25,"Large plus changes note speed")
    s.note_speed_input.value=3; check(s.note_speed_input.plus.disabled,"Stepper disables at upper bound")
    s.note_speed_input.value=.5; check(s.note_speed_input.minus.disabled,"Stepper disables at lower bound")
    s.highway_angle_input.plus.pressed.emit(); check(g.highway_angle==31,"Angle increases by exactly two degrees")
    s.shape_tiles.rectangle.pressed.emit(); check(g.note_shape=="rectangle" and s.shape_tiles.rectangle.selected,"Shape selection applies immediately")
    s.nav_buttons.audio.pressed.emit()
    check(s.selected_page=="audio" and s.pages.audio.root.visible and not s.pages.gameplay.root.visible,"Tabs switch the visible page")
    check(s.pages.audio.sections.timing.root.modulate.a<1,"Page transition animates rather than jumping")
    s.show_section("headset",false)
    s.bluetooth_toggle.button_pressed=true; s.bluetooth_latency_input.value=240
    check(g.bluetooth_mode and g.bluetooth_latency_ms==240 and s.bluetooth_latency_input.editable,"Bluetooth controls remain connected")
    await shot("audio")
    check(s.bluetooth_toggle.knob>.99,"Switch thumb animates to on state")
    g.open_sync_helper(); check(g.sync_helper.visible and not s.visible,"Sync helper opens")
    g.close_sync_helper(); check(s.visible and s.selected_page=="audio","Sync helper returns to same Settings category")
    s.bluetooth_toggle.button_pressed=false
    check(not s.bluetooth_latency_input.editable and s.bluetooth_latency_input.plus.disabled,"Bluetooth off disables extra delay")
    s.show_page("visuals"); s.sizing_inputs.note_size.value=85; s.sizing_inputs.hold_trail_width.value=45
    s.effect_inputs.Particles.value=35
    check(is_equal_approx(g.note_size,.85) and is_equal_approx(g.hold_trail_width,.45) and is_equal_approx(g.features.effect("Particles"),.35),"Visual controls apply global note and effect preferences")
    await shot("visuals")
    s.show_page("editor"); s.authoring_switches.ghost.button_pressed=false; s.authoring_switches.lines.button_pressed=false
    s.authoring_switches.mr.button_pressed=true; s.metronome_toggle.button_pressed=true
    check(not g.ghost_recording and not g.note_lines and g.mr.enabled and g.beat_clock.enabled,"Editor switches update their existing services")
    var speed=g.record_speed; s.speed_button.pressed.emit(); check(g.record_speed!=speed,"Recorder speed uses existing playback preference")
    await shot("editor")
    check(g.document.notes==original and g.document.settings==config,"Global settings never modify chart data")
    s.show_page("audio"); s.show_page("visuals"); s.show_page("gameplay"); await create_timer(.4).timeout
    check(is_equal_approx(s.pages.gameplay.root.modulate.a,1) and is_equal_approx(s.pages.gameplay.root.position.x,28),"Rapid navigation settles at exact visible layout")
    var drag=s.pages.gameplay.scroll.get_node("DragScroll"); drag.dragged=true
    var speed_before=g.note_speed; s.note_speed_input.plus.pressed.emit()
    check(g.note_speed==speed_before,"Dragging over a stepper cannot change the preference")
    drag.stop(); s.show_section("browsing",false); drag=s.pages.gameplay.scroll.get_node("DragScroll"); drag.dragged=true
    var preview_before=g.lobby.preview_enabled; s.song_preview_toggle.button_pressed=not preview_before
    check(g.lobby.preview_enabled==preview_before and s.song_preview_toggle.button_pressed==preview_before,"Dragging over a switch cannot change its preference")
    drag.stop()
    root.size=Vector2i(1024,600); await shot("compact")
    for key in s.pages:
        s.show_page(key,false); await process_frame; await process_frame
        var data=s.pages[key]
        check(data.list.get_combined_minimum_size().x<=data.scroll.size.x+1,"Page rows fit compact screen: "+key)
        check(s.page_host.get_global_rect().end.x<=g.size.x+1,"Settings panel fits compact screen")
    var prefs=ConfigFile.new(); prefs.load("user://preferences.cfg")
    check(is_equal_approx(prefs.get_value("gameplay","note_size"),.85) and is_equal_approx(prefs.get_value("effects","Particles"),.35),"Preferences persist")
    s.back_button.pressed.emit(); check(g.lobby.visible and not s.visible,"Back returns to lobby")
    g.queue_free(); await process_frame
    print("Settings redesign: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
