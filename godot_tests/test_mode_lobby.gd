extends SceneTree
var failures=0
func check(value: bool,message: String) -> void:
    if not value: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func capture(name: String) -> void:
    await create_timer(.5).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/modes-%s.png" % name)
func run():
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false); game.stage_intro_enabled=false
    var lobby=game.lobby
    check(lobby.gateway.visible,"Startup opens mode lobby")
    await capture("lobby")
    lobby.show_play_browser()
    check(not lobby.gateway.visible and lobby.carousel.visible,"Play opens song browser")
    lobby.begin_preview()
    check(lobby.preview_player.playing,"Play browser supports previews")
    await capture("play")
    lobby.show_gateway()
    check(lobby.gateway.visible and not lobby.preview_player.playing,"Main lobby stops song previews")
    game.open_editor()
    check(game.mode=="library","Create entrance opens chart library")
    game.document.load_notes(SynkChart.demo()); game.set_mode("editor")
    check(game.studio.record_button.caption_text=="● RECORD","Editor recording action is named RECORD")
    check(float(game.studio.record_button.art_material.get_shader_parameter("glare"))==1.0,"RECORD keeps glare")
    check(float(game.play_button.art_material.get_shader_parameter("glare"))==0.0,"Other editor actions have no glare")
    await capture("editor")
    game.studio.record_button.pressed.emit()
    for button in game.kind_buttons:
        check(float(button.art_material.get_shader_parameter("glare"))==0.0,"Recorder tool glare removed")
    game.set_mode("menu")
    check(lobby.gateway.visible,"Returning home opens mode lobby")
    game.open_lobby_settings(); game.close_lobby_settings()
    check(lobby.gateway.visible and lobby.visible,"Settings returns to main lobby")
    print("Mode lobby integration: ","PASS" if failures==0 else "%d FAILED" % failures)
    quit(0 if failures==0 else 1)
