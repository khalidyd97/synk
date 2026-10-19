extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func frame() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro.set_process(false)
    g.lobby.show_play_browser(); await create_timer(.7).timeout
    var bg=g.lobby.browser.background; var clock=bg.get_node("BackgroundMotion")
    check(clock.elapsed>0 and float(bg.material.get_shader_parameter("clock"))>0,"Visible page background runs its own animation clock")
    var before=clock.elapsed; g.lobby.visible=false; clock._process(2)
    check(clock.elapsed==before,"Hidden page background stops its clock")
    g.lobby.visible=true; clock.set_process(false)
    bg.material.set_shader_parameter("clock",0.0); var first=await frame()
    bg.material.set_shader_parameter("clock",8.0); var second=await frame()
    var changed=0
    # Sample only the unobstructed bottom-left atmosphere, not animated controls.
    for y in range(695,715,2):
        for x in range(5,710,2):
            if first.get_pixel(x,y)!=second.get_pixel(x,y): changed+=1
    check(changed>50,"Background visibly changes between animation frames")
    first.save_png("res://.tools/ambient-page-a.png"); second.save_png("res://.tools/ambient-page-b.png")
    var play=g.lobby.browser.play; play.grab_focus(); play._process(.02)
    check(play.hover_amount>0 and play.hover_amount<1,"Button focus lighting eases in")
    play.button_down.emit(); check(play.press_amount==1,"Button press triggers feedback")
    play._process(.05); check(play.press_amount>0 and play.press_amount<1,"Button feedback decays smoothly")
    var toggle=g.lobby.auto_button; toggle.amount=0; toggle.button_pressed=true; toggle._process(.02)
    check(toggle.amount>0 and toggle.amount<1,"Auto toggle animates between states")
    g.set_mode("menu"); g.lobby.show_gateway()
    var ambient: Node=null
    for child in g.lobby.gateway.get_children():
        if child.has_node("BackgroundMotion"): ambient=child.get_node("BackgroundMotion")
    check(ambient!=null and g.lobby.home_video!=null,"Lobby retains animated video plus ambient motion")
    g.open_lobby_settings(); check(g.settings_panel.get_child(0).has_node("BackgroundMotion"),"Settings uses live ambient background")
    g.open_sync_helper(); check(g.sync_helper.get_child(0).has_node("BackgroundMotion"),"Audio sync image has live background motion")
    g.close_sync_helper(); g.close_lobby_settings()
    g.stage_intro_enabled=true; g.set_mode("menu"); g.start_game([SynkChart.note(3,4)],false)
    check(is_equal_approx(g.stage_intro.load_time,5.0),"Game loading screen lasts five seconds before its transition")
    var w=g.field.world; var origin=w.camera_rest_position()
    for at in [0.0,.5,1.15,1.6,2.0]:
        g.stage_intro.elapsed=at; g.stage_intro.animate(); w.animate_miss_shake(0)
        check(is_equal_approx(w.camera.fov,w.GAMEPLAY_FOV),"Highway FOV remains fixed throughout entrance")
        check(w.camera.position.is_equal_approx(origin),"Highway position remains fixed throughout entrance")
        check(is_equal_approx(w.camera.rotation_degrees.x,-g.highway_angle),"Highway angle remains fixed throughout entrance")
    g.stage_intro.skip(); w.animate_miss_shake(0)
    check(is_equal_approx(w.camera.fov,w.GAMEPLAY_FOV),"Skipping loading cannot change the highway zoom")
    g.queue_free(); await process_frame
    print("Ambient UI motion and stationary highway entrance: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
