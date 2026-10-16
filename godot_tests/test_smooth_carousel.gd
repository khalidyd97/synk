extends SceneTree
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
func shot(name: String):
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/smooth-"+name+".png")
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; var l=g.lobby; l.show_play_browser()
    g.demo_stream.save_to_wav("user://songs/swipe.wav"); g.library.songs=[]
    for i in 4:
        var id=str(i+1).repeat(64)
        g.library.songs.append({"id":id,"title":"Swipe track "+str(i+1),"bpm":120,"file":"swipe.wav"})
        g.song_metadata[id]={"duration":96.0,"waveform":g.waveform,"notes":[],"has_chart":false,"note_count":0}
        var image=Image.create(32,32,false,Image.FORMAT_RGBA8); image.fill(Color.from_hsv(float(i)/4,.8,.8))
        g.song_cover_textures[id]=ImageTexture.create_from_image(image)
    l.refresh(); var c=l.carousel; c.set_process(false)
    await create_timer(.65).timeout
    var first=c.cards[0]; var row=l.track_list.get_child(0)
    c.shown=.25; l.refresh()
    check(c.cards[0]==first and l.track_list.get_child(0)==row and c.shown==.25,"Refresh reuses cards and preserves animation position")
    c.shown=0; c.begin_drag(Vector2(500,200),0); c.move_drag(Vector2(500-c.spacing()*.6,200))
    check(absf(c.shown-.6)<.01 and c.current==0,"Cards follow finger before committing selection")
    await shot("mid-swipe")
    c.drag_velocity=0; c.finish_drag(Vector2(500-c.spacing()*.6,200))
    check(c.current==1 and g.loading_song_index==1 and l.title_label.text=="Swipe track 1","Release selects pending song without old metadata")
    check(l.hero_art.modulate.a<.14 and l.background_stack.get_child_count()>1,"Background crossfade keeps old cover visible")
    await create_timer(.2).timeout
    check(l.hero_art.modulate.a>0 and l.hero_art.modulate.a<.14,"Background transition has intermediate opacity")
    c.step(1); c.step(1); await wait_song(g)
    check(str(g.song.id)=="3".repeat(64) and c.current==3,"Rapid next selections load only newest requested song")
    c._process(.02); var intermediate=c.shown; l.refresh()
    check(c.shown==intermediate and c.shown<3,"Async refresh never snaps the carousel")
    await create_timer(.7).timeout
    check(l.background_stack.get_child_count()==1 and is_equal_approx(l.hero_art.modulate.a,.14),"Crossfade cleans up old layers and settles")
    c.step(-1); l.select_track(3)
    check(g.loading_song_index<0 and c.current==3,"Selecting already-loaded song cancels older pending load")
    await wait_song(g)
    g.document.dirty=true; c.step(-1)
    check(c.current==3,"Blocked song switch rolls selection back smoothly")
    g.document.dirty=false
    c.current=0; c.shown=0; c.begin_drag(Vector2(500,200),0)
    c.move_drag(Vector2(1500,200)); check(c.shown>=-.25,"Swipe edge resistance is bounded")
    c.finish_drag(Vector2(1500,200),true)
    check(c.current==0 and not c.dragging,"Canceled touch never changes song")
    c.select_id(str(g.song.id)); c.shown=float(c.current); c.layout_cards()
    await shot("settled")
    g.queue_free(); await process_frame
    print("Smooth carousel integration: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
