extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func bounded(control: Control,bounds: Rect2) -> bool:
    return bounds.grow(1.5).encloses(control.get_global_rect())
func run():
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame; await process_frame
    g.set_process(false); g.get_node("SafeAreaPoll").stop()
    for safe in [Rect2(160,0,2240,1080),Rect2(0,0,2240,1080),Rect2(0,80,2400,920),Rect2(160,40,2080,1000),Rect2(0,0,2400,1080)]:
        g.set_safe_area_pixels(safe,Vector2(2400,1080)); await process_frame; await process_frame
        var area=Rect2(g.get_global_transform_with_canvas()*g.safe_area_rect.position,g.safe_area_rect.size)
        check(g.ui.position.is_zero_approx() and g.ui.size.is_equal_approx(g.size),"UI root stays full bleed for every notch position")
        check(g.field.position.is_zero_approx() and g.field.size.is_equal_approx(g.size),"Gameplay and touch projection remain full screen")
        check(g.stage_intro.size.is_equal_approx(g.size) and g.pause_backdrop.size.is_equal_approx(g.size),"Loading and pause overlays extend beneath cutouts")
        var buttons=g.lobby.gateway.get_node("SafeLobbyButtons")
        for button in buttons.get_children(): check(bounded(button,area),"Lobby buttons avoid the cutout")
        check(bounded(g.pause_button,area),"Pause button stays inside the safe area")
        check(bounded(g.score_panel,area),"Pause button and score layout remain aligned")
        check(bounded(g.settings_panel.back_button,area),"Settings back button avoids cutouts")
        check(bounded(g.lobby.play_button,area),"Song selection play button avoids cutouts")
        check(bounded(g.chart_library.record_button,area),"Chart library record button avoids cutouts")
        check(bounded(g.studio.record_button,area),"Editor controls avoid cutouts without shrinking the background")
        check(bounded(g.kind_buttons[0],area) and bounded(g.record_speed_button,area),"Recorder top and bottom buttons avoid cutouts")
        check(g.studio.size.is_equal_approx(g.size),"Editor background remains full screen")
    for window in [Vector2i(1600,720),Vector2i(1280,800)]:
        root.size=window; await process_frame; await process_frame
        g.set_safe_area_pixels(Rect2(0,0,2240,1080),Vector2(2400,1080))
        await process_frame; await process_frame
        var resized_area=Rect2(g.get_global_transform_with_canvas()*g.safe_area_rect.position,g.safe_area_rect.size)
        check(g.field.size.is_equal_approx(g.size) and g.ui.size.is_equal_approx(g.size),"Resizing preserves full-screen rendering")
        check(bounded(g.pause_button,resized_area) and bounded(g.settings_panel.back_button,resized_area),"Controls update when window geometry and notch side change")
    g.set_safe_area_pixels(Rect2(),Vector2.ZERO)
    check(g.safe_area_rect==Rect2(Vector2.ZERO,g.size),"Unavailable safe-area metrics fall back to the full window")
    var preset=ConfigFile.new(); preset.load("res://export_presets.cfg")
    check(preset.get_value("preset.1.options","screen/edge_to_edge",false),"Android export explicitly enables edge-to-edge drawing")
    g.queue_free(); await process_frame
    print("Edge-to-edge backgrounds and safe controls: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
