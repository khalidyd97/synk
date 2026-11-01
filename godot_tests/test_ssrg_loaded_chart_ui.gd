extends SceneTree
var failures=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 var fixture={"id":"float_keys_fixture","title":"Loaded chart","artist":"Fixture","album":"SSRG","ssrg":[13.0],"length":60.0,"ssrg_charts":[{"keys":13.0,"variant":"lv13","notes":415.0,"density":6.9}]}
 game.library.songs.append(fixture)
 var browser=game.ssrg_playables
 var row=browser.song_row(fixture)
 check(row!=null,"JSON-loaded floating lane count can build a song row")
 if row:row.queue_free()
 browser.selected_id=fixture.id;browser.refresh_detail()
 check(browser.detail.get_child_count()>0,"JSON-loaded floating lane count can build chart detail cards")
 game.ssrg_playable_run=true;game.set_mode("play");game.countdown=0
 game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.mode=="paused","Focus loss still pauses immediately without creating transition children")
 game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 check(game.mode=="paused","Repeated app-background notifications cannot resume gameplay")
 game.queue_free();await process_frame
 print("SSRG loaded-chart/browser and background-pause failures: ",failures);quit(failures)
