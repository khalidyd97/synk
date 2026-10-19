extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); await create_timer(.8).timeout
    var gate=g.lobby.gateway
    var logo=gate.find_child("LobbyWordmark",true,false)
    var play=gate.find_child("PlayCard",true,false); var create=gate.find_child("CreateCard",true,false)
    var settings=gate.find_child("SettingsButton",true,false)
    check(logo!=null and logo.word=="SYNK","Home shows the type-set SYNK wordmark")
    check(play!=null and create!=null and settings!=null,"Home has Play, Create charts and Settings")
    check(gate.find_children("*","TextureRect",true,false).all(func(t): return t.texture==null or not str(t.texture.resource_path).contains("button")),"Old image buttons are gone")
    var rect=play.get_global_rect(); play.grab_focus(); play._process(.3)
    check(play.hover_amount>.5 and play.get_global_rect()==rect,"Focus lights the card without moving its hit area")
    var frame=logo.time; logo._process(.5); check(logo.time>frame,"Wordmark gradient animates while visible")
    play.pressed.emit()
    check(not gate.visible and g.lobby.browser.visible,"Play opens the song browser")
    var hidden=logo.time; logo._process(1); check(logo.time==hidden,"Hidden wordmark stops animating")
    g.lobby.show_gateway(); await create_timer(.6).timeout
    settings.pressed.emit(); check(g.menu_settings_open and g.settings_panel.visible,"Gear opens Settings")
    g.close_lobby_settings(); await create_timer(.6).timeout
    create.pressed.emit(); check(g.mode=="library","Create charts opens the Chart Studio song list")
    g.set_mode("menu"); root.size=Vector2i(1024,600); await create_timer(.6).timeout
    check(play.get_global_rect().end.x<=g.size.x and create.get_global_rect().end.x<=g.size.x,"Cards fit a compact screen")
    g.queue_free(); await process_frame
    print("Lobby home: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
