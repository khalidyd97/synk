extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func shot(name: String):
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/scope-"+name+".png")
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.lobby.show_play_browser(); g.lobby.begin_preview()
    g.open_lobby_settings(); g.settings_panel.song_preview_toggle.button_pressed=false
    check(not g.lobby.preview_enabled and not g.lobby.preview_player.playing,"Settings disables preview audio immediately")
    var prefs=ConfigFile.new(); prefs.load("user://preferences.cfg")
    check(not prefs.get_value("audio","song_preview",true),"Preview preference persists")
    g.settings_panel.song_preview_toggle.button_pressed=true
    check(g.lobby.preview_enabled,"Settings enables previews")
    await shot("settings")
    g.features.open_tools("Effects")
    check(not g.features.tabs.tabs_visible and g.features.tabs.is_tab_hidden(0),"Global effects never expose chart navigation")
    check("every song" in g.features.tools_context.text,"Effects explicitly show game-wide scope")
    await shot("effects"); g.features.close_tools(); g.close_lobby_settings()
    g.set_mode("editor"); g.features.open_tools()
    check(g.features.tabs.is_tab_hidden(3) and not g.features.tabs.is_tab_hidden(6),"Chart category includes chart timing and excludes global effects")
    check("ORIGINAL" in g.features.tools_context.text and "CHART" in g.features.tools_context.text,"Chart tools identify active chart")
    await shot("chart")
    g.features.show_scope("THIS SONG")
    check(not g.features.tabs.is_tab_hidden(10) and g.features.tabs.is_tab_hidden(6) and g.features.tabs.is_tab_hidden(0),"Song category shows only song tools")
    check("Shared by all" in g.features.tools_context.text,"Song tools disclose shared scope")
    await shot("song")
    g.features.show_scope("VERSIONS"); g.features.choose_variant(1)
    g.features.show_scope("THIS CHART")
    check("EASY" in g.features.tools_context.text and "EASY" in g.features.draft_context.text,"Changing versions refreshes chart context")
    g.features.show_scope("SHARE")
    check(g.features.tabs.current_tab==2 and "EASY" in g.features.tools_context.text,"Sharing identifies the selected chart version")
    g.features.close_tools(); g.queue_free(); await process_frame
    print("Scoped tools and preview settings: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
