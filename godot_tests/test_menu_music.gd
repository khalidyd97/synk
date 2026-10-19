extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    var m=g.menu_music; m.volume=.6
    check(m.stream!=null and m.stream.loop,"Menu theme loads and loops")
    g.set_mode("menu"); g.lobby.show_gateway(); m._process(2.0)
    check(m.wanted() and m.playing and m.level==1.0,"Music plays on the lobby")
    g.lobby.show_play_browser(); m._process(2.0)
    check(not m.wanted() and m.level==0.0,"Music fades out on the song list (previews)")
    g.lobby.show_gateway(); m._process(.6)
    check(m.level>0.0 and m.level<1.0,"Music fades back in gradually")
    g.set_mode("library"); check(m.wanted(),"Music plays on the Chart Studio list")
    g.set_mode("editor"); check(not m.wanted(),"Music is silent in the editor")
    g.stage_intro_enabled=false; g.start_game([SynkChart.note(5,3)],false); check(not m.wanted(),"Music is silent in gameplay")
    g.set_mode("menu"); g.lobby.show_gateway(); m.volume=0.0; check(not m.wanted(),"0% turns menu music off")
    g.queue_free(); await process_frame
    print("Menu music: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
