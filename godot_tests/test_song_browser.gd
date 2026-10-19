extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
    await create_timer(.55).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/song-browser-"+name+".png")
func wait_for_song(g: Control) -> void:
    for i in 300:
        g.poll_song_worker()
        if g.loading_song_index<0 and g.worker_song_id.is_empty(): return
        await process_frame
    check(false,"Song loading completes")
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var l=g.lobby; var view=l.browser
    g.demo_stream.save_to_wav("user://songs/browser_fixture.wav")
    var names=["Neon Drift","Starfall Runner","Midnight Circuit","Laser Bloom","Pulse Garden","Afterglow City","Orbit Echo"]
    var artists=["Nova Kai","Lumen Theory","Sable & Sky","Halo Avenue","Mira Vale","Echo Parade","Nova Kai"]
    var genres=["Synthwave","Electro","Drum & Bass","Future Pop","House","Synthwave","Trance"]
    g.library.songs=[]
    for i in names.size():
        var id=str(i+1).repeat(64)
        var song={"id":id,"title":names[i],"artist":artists[i],"album":artists[i],"genre":genres[i],"bpm":118+i*8,"file":"browser_fixture.wav"}
        g.library.songs.append(song)
        var notes: Array=[]
        for j in range(60+i*32): notes.append(SynkChart.note(3+j*(.4-i*.03),j%10))
        g.song_metadata[id]={"duration":204.0-i*4,"waveform":g.waveform,"notes":notes,"has_chart":true,"note_count":notes.size()}
        for variant in ["original","easy","normal","hard","expert"]:
            var path="user://charts/"+id+("" if variant=="original" else "_"+variant)+".json"
            var copy=notes.duplicate(true); copy[0].lane=1+["original","easy","normal","hard","expert"].find(variant)
            SynkLibrary.atomic_write(path,{"version":2,"song_id":id,"notes":copy,"chart_settings":{"bpm":118+i*8,"beat_offset":0.0}})
    l.favorites=[g.library.songs[0].id,g.library.songs[2].id,g.library.songs[5].id]
    g.apply_song(g.library.songs[0],g.demo_stream,g.song_metadata[g.library.songs[0].id])
    l.refresh(); l.show_play_browser(); l.choose_difficulty("normal"); l.begin_preview()
    check(l.filtered_entries.size()==8 and l.track_list.columns==1,"Reference layout lists songs as vertical rows")
    check(view.difficulty.size()==4 and view.difficulty.hard.disabled==false,"Easy/Normal/Hard/Expert select actual saved versions")
    check(g.features.current_variant=="normal" and g.saved_notes[0].lane==3,"Difficulty choice loads the correct chart")
    var first=l.track_list.get_child(0); var scroll_position=l.track_scroll.scroll_vertical
    l.refresh()
    check(l.track_list.get_child(0)==first and l.track_scroll.scroll_vertical==scroll_position,"Refreshing reuses rows and preserves list position")
    await shot("reference")
    check(l.preview_player.playing,"Preview follows the global enabled preference")
    l.set_preview_enabled(false); check(not l.preview_player.playing,"Global preference stops preview audio immediately")
    l.search.text="lumen"; l.search.text_changed.emit("lumen")
    check(l.filtered_entries.size()==1 and l.filtered_entries[0].title=="Starfall Runner","Search matches artist names")
    await wait_for_song(g)
    check(g.song.title=="Starfall Runner" and view.title_label.text=="Starfall Runner","Selecting a filtered song updates the live details")
    l.search.text="does not exist"; l.search.text_changed.emit(l.search.text)
    check(l.filtered_entries.is_empty() and view.play.disabled,"Empty search prevents playback of stale selection")
    await shot("empty")
    l.search.text=""; l.search.text_changed.emit(""); await wait_for_song(g)
    l.set_filter("favorites"); await wait_for_song(g)
    check(l.filtered_entries.size()==3,"Favorites filter includes only stored favorites")
    var removed=str(l.filtered_entries[0].id); l.toggle_favorite_id(removed); await wait_for_song(g)
    check(l.filtered_entries.size()==2 and removed not in l.favorites,"Removing a favorite reconciles the filtered list")
    l.recent.clear(); l.set_filter("recent")
    check(l.filtered_entries.is_empty(),"Recently played starts empty without inventing history")
    l.remember_played(g.library.songs[1].id); l.set_filter("recent"); await wait_for_song(g)
    check(l.filtered_entries.size()==1 and l.filtered_entries[0].id==g.library.songs[1].id,"Recently played uses persisted real play history")
    l.set_filter("new"); await wait_for_song(g)
    check(l.filtered_entries.size()==6 and l.filtered_entries[0].id==g.library.songs[6].id,"New shows unplayed imports newest first")
    l.set_filter("all"); await wait_for_song(g)
    var drag=l.track_scroll.get_node("DragScroll")
    var point=l.track_scroll.get_global_rect().position+Vector2(50,60)
    drag.handle(7,point,true,false); drag.handle(7,point-Vector2(0,100),false,false); drag.handle(7,point-Vector2(0,100),false,true)
    check(drag.dragged and not drag.pressing,"Touch drags finish without turning into row clicks")
    drag.stop(); l.track_scroll.scroll_vertical=0
    var clicked=l.track_list.get_child(1); clicked.pressed.emit(); await wait_for_song(g)
    check(g.song.id==clicked.entry.id,"A row click selects that row's real song")
    view.difficulty.hard.pressed.emit()
    check(g.features.current_variant=="hard" and g.saved_notes[0].lane==4,"Hard charts keep their own notes and version path")
    var notes=g.baseline_notes().duplicate(true); notes.sort_custom(func(a,b): return float(a.time)<float(b.time))
    var key=(str(g.song.id)+JSON.stringify(notes)).sha256_text()
    g.prefs.set_value("scores",key,912345); g.prefs.set_value("score_ranks",key,"A"); view.update_best()
    check(view.best_value.text=="912345" and view.rank_value.text=="A","Best score and rank belong to the selected chart")
    l.choose_difficulty("easy"); check(view.best_value.text=="0","A different chart does not inherit another difficulty's score")
    DirAccess.remove_absolute("user://charts/"+str(g.song.id)+"_expert.json"); l.refresh()
    check(view.difficulty.expert.disabled,"Missing charts are disabled rather than fabricated")
    root.size=Vector2i(1024,600); await shot("compact")
    check(l.track_list.get_combined_minimum_size().x<=l.track_scroll.size.x+1,"Song rows fit compact screens")
    check(view.panel.get_global_rect().end.x<=g.size.x,"Selected-song panel fits compact screens")
    l.show_gateway(); check(not l.preview_player.playing,"Returning to lobby stops previews")
    g.queue_free(); await process_frame
    print("Reference song browser: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
