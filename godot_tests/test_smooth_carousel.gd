extends SceneTree
# Historical runner name retained; the song browser now uses a vertical list.
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func wait_song(g: Control):
    for i in 300:
        g.poll_song_worker()
        if g.loading_song_index<0 and g.worker_song_id.is_empty(): return
        await process_frame
    check(false,"Song load timed out")
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; var l=g.lobby; l.show_play_browser()
    g.demo_stream.save_to_wav("user://songs/swipe.wav"); g.library.songs=[]
    for i in 12:
        var id=str(i+1).sha256_text()
        g.library.songs.append({"id":id,"title":"Track "+str(i+1),"bpm":120,"file":"swipe.wav"})
        g.song_metadata[id]={"duration":96.0,"waveform":g.waveform,"notes":[],"has_chart":false,"note_count":0}
    l.refresh(); await create_timer(.4).timeout
    var row=l.track_list.get_child(0); l.track_scroll.scroll_vertical=100; l.refresh()
    check(l.track_list.get_child(0)==row and l.track_scroll.scroll_vertical==100,"Refresh reuses rows and preserves scroll position")
    l.select_track(1)
    check(g.loading_song_index==1 and l.title_label.text=="Track 1" and l.play_button.disabled,"Pending selection updates immediately and cannot play the old song")
    l.select_track(2); l.select_track(3); await wait_song(g)
    check(g.song.id==g.library.songs[2].id and l.title_label.text=="Track 3","Rapid clicks commit only the latest requested song")
    await create_timer(.3).timeout
    check(l.browser.cover.get_parent().get_child_count()==1,"Cover transitions clean up outgoing layers")
    l.select_track(2); l.select_track(3)
    check(g.loading_song_index<0,"Selecting the loaded song cancels an older pending request")
    await wait_song(g)
    g.document.dirty=true; l.select_track(1)
    check(g.song.id==g.library.songs[2].id and l.title_label.text=="Track 3","Blocked switch keeps the real selection visible")
    g.document.dirty=false
    var helper=l.track_scroll.get_node("DragScroll"); var point=l.track_scroll.get_global_rect().position+Vector2(40,100)
    helper.handle(4,point,true,false); helper.handle(4,point-Vector2(0,60),false,false); helper.handle(4,point-Vector2(0,60),false,true,true)
    check(not helper.pressing and helper.velocity==0,"Cancelled touch cannot leave an inertial drag running")
    g.queue_free(); await process_frame
    print("Smooth song list integration: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
