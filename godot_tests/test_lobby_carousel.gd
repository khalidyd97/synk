extends SceneTree
# Historical runner name retained for song browser preview/transport regression.
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; var l=g.lobby; l.show_play_browser()
    l.set_preview_enabled(true); l.begin_preview()
    check(l.preview_player.playing and l.preview_player.stream==g.audio.stream,"Preview uses the selected song's actual audio")
    l.search.text="no such song"; l.search.text_changed.emit(l.search.text)
    check(l.browser.empty.visible and l.play_button.disabled and not l.preview_player.playing,"Empty search stops preview and disables playback")
    l.search.text=""; l.search.text_changed.emit("")
    check(l.preview_delay>=0,"Restoring results schedules preview again")
    l.begin_preview(); g.set_mode("editor")
    check(not l.preview_player.playing,"Leaving the song list stops its preview")
    g.set_mode("menu"); l.show_play_browser(); l.auto_button.button_pressed=true; l.press_play()
    check(g.mode=="play" and g.auto_play,"Autoplay toggle applies to the gradient Play button")
    check(l.recent.has("eclipse"),"Starting playback records the song in recent history")
    g.queue_free(); await process_frame
    print("Song browser transport: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
