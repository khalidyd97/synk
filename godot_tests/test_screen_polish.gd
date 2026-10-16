extends SceneTree
var failures=0
func check(value: bool,message: String) -> void:
    if not value: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func capture(name: String) -> void:
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/polish-%s.png" % name)
func run():
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false); game.stage_intro_enabled=false
    game.set_mode("library")
    await capture("library")
    check(game.chart_library.chart_cards.size()>=1,"Library shows original chart")
    check(game.chart_library.grid.get_combined_minimum_size().x<=game.chart_library.scroll.size.x+1,"Library cards fit viewport")
    game.chart_library.search.text="missing track"
    game.chart_library.search.text_changed.emit(game.chart_library.search.text)
    check(game.chart_library.chart_cards.is_empty(),"Library search handles empty results")
    game.chart_library.search.text="eclipse"
    game.chart_library.library_filter="charted"; game.chart_library.refresh()
    check(game.chart_library.chart_cards.size()==1,"Library search and chart filter combine")
    game.chart_library.update_card_metadata("unknown"); game.chart_library.update_selection()
    game.set_mode("menu"); game.open_lobby_settings()
    await capture("settings")
    game.open_sync_helper()
    await capture("sync")
    check(game.sync_helper.lane.mouse_filter==Control.MOUSE_FILTER_STOP,"Sync practice lane keeps touch input")
    game.sync_helper.close(); game.close_lobby_settings()
    game.document.load_notes(SynkChart.demo()); game.set_mode("editor"); game.seek_to(12)
    await capture("editor")
    game.record_here()
    await capture("recorder")
    game.audio.stop(); game.set_mode("play"); game.toggle_pause()
    await create_timer(.4).timeout
    await capture("pause")
    game.set_mode("guide")
    await capture("guide")
    game.set_mode("results")
    game.results_screen.show_results({"cover":game.ECLIPSE_COVER,"tint":Color.WHITE,"title":"Eclipse","details":"SYNK Originals · Expert","rank":"SS","score":982450,"accuracy":98.25,"max_combo":128,"counts":{"PERFECT":180,"GREAT":12,"GOOD":2,"MISS":1},"best":982450,"new_best":true,"auto_play":false})
    game.results_screen.elapsed=2.0; game.results_screen.animate()
    await capture("results")
    print("Screen polish integration: ","PASS" if failures==0 else "%d FAILED" % failures)
    quit(0 if failures==0 else 1)
