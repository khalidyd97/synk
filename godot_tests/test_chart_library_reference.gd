extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
    await create_timer(.65).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/chart-library-"+name+".png")
func settle(g: Control) -> void:
    for i in 300:
        g.poll_song_worker(); await process_frame
        if g.loading_song_index<0 and g.worker_song_id.is_empty():
            await process_frame; return
    check(false,"Audio load completes")
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var v=g.chart_library
    g.demo_stream.save_to_wav("user://songs/library_fixture.wav")
    var names=["Neon Drift","Starfall Runner","Midnight Circuit","Laser Bloom","Pulse Garden","Afterglow City"]
    var artists=["Nova Kai","Lumen Theory","Sable & Sky","Halo Avenue","Mira Vale","Echo Parade"]
    g.library.songs=[]
    for i in names.size():
        var id=str(i+1).repeat(64)
        var song={"id":id,"title":names[i],"artist":artists[i],"album":artists[i],"bpm":118+i*8,"file":"library_fixture.wav"}
        g.library.songs.append(song)
        g.song_metadata[id]={"duration":96.0,"waveform":g.waveform,"notes":[],"has_chart":false,"note_count":0}
        if i==3: continue
        for variant in (["original","normal","expert"] if i==0 else ["original","normal"]):
            var notes: Array=[]
            for j in range(120+i*20):
                var note=SynkChart.note(2+j*.4,j%10,"flick" if j%11==0 else "tap")
                notes.append(note)
            SynkLibrary.atomic_write(v.chart_file(id,variant),{"version":2,"song_id":id,"notes":notes,"chart_settings":{"bpm":118+i*8,"beat_offset":0.0}})
        if i in [0,2,5]:
            var notes: Array=[]
            for j in 80: notes.append(SynkChart.note(2+j*.6,j%10))
            SynkLibrary.atomic_write(v.draft_file(id,"normal"),{"version":2,"song_id":id,"notes":notes,"chart_settings":{"bpm":118+i*8,"beat_offset":0.0}})
    g.set_mode("library"); v.select_entry(g.library.songs[0].id); v.selected_variant="normal"; v.update_panel()
    check(g.mode=="library" and g.song.id=="eclipse","Browsing does not open editor or change live chart")
    check(v.chart_cards.size()==7 and v.grid.columns==1,"Creator library uses a single column song list")
    check(v.versions.get_child_count()==3 and v.stats_label.text.begins_with("80 Notes"),"Selected version displays real recoverable draft notes")
    await shot("reference")
    var first=v.chart_cards[0]; v.refresh(); check(v.chart_cards[0]==first,"Refresh reuses rows")
    v.search.text="lumen"; v.refresh(); check(v.chart_cards.size()==1,"Artist search works")
    v.search.text="not found"; v.refresh(); check(v.chart_cards.is_empty() and not v.panel.visible,"Empty search hides stale chart actions")
    await shot("empty")
    v.search.text=""; v.library_filter="draft"; v.refresh(); check(v.chart_cards.size()==3,"In progress uses actual draft files")
    v.library_filter="charted"; v.refresh(); check(v.chart_cards.size()==6,"Ready includes saved versions and built-in chart")
    v.library_filter="all"; v.refresh(); v.select_entry(g.library.songs[3].id)
    check(v.versions.get_child_count()==1 and v.stats_label.text.begins_with("0 Notes"),"Uncharted song has an honest empty state")
    v.select_entry(g.library.songs[0].id); v.selected_variant="normal"; v.update_panel()
    v.edit_button.pressed.emit(); check(v.edit_button.disabled,"Audio loading disables duplicate launches")
    await settle(g)
    check(g.mode=="editor" and g.features.current_variant=="normal" and g.document.notes.size()==80 and g.document.dirty,"Edit loads selected song and recovers selected draft")
    g.close_editor(); v.select_entry(g.library.songs[0].id); v.selected_variant="normal"; v.update_panel()
    v.record_button.pressed.emit()
    check(g.mode=="record" and g.recorder.active and g.recorder.baseline.size()==80,"Record continues the selected draft without clearing it")
    g.audio.stop(); g.set_mode("editor"); g.close_editor()
    v.select_entry(g.library.songs[0].id); v.create_version(g.features.VARIANTS.find("hard"))
    check(g.mode=="editor" and g.features.current_variant=="hard" and g.document.notes.is_empty(),"New creates a separate empty version in the editor")
    g.document.dirty=false; g.set_mode("library")
    v.library_filter="recent"; v.refresh(); check(v.chart_cards.size()==1,"Recent records actual chart authoring sessions")
    v.library_filter="all"; v.refresh(); v.select_entry(g.library.songs[1].id); v.open_selected("editor")
    v.select_entry(g.library.songs[2].id); await settle(g)
    check(g.mode=="library" and v.pending_action.is_empty(),"Changing selection cancels queued editor launch")
    v.select_entry(g.library.songs[0].id); v.selected_variant="normal"; v.update_panel()
    v.ask_delete(v.selected_entry()); check(v.confirm.visible and not v.confirm_chart_button.disabled,"Manage confirms selected version deletion")
    v.finish_delete(false)
    check(not FileAccess.file_exists(v.chart_file(g.library.songs[0].id,"normal")) and not FileAccess.file_exists(v.draft_file(g.library.songs[0].id,"normal")),"Delete removes only selected version and draft")
    check(FileAccess.file_exists(v.chart_file(g.library.songs[0].id,"expert")),"Other chart versions remain intact")
    v.select_entry("eclipse"); v.ask_delete(v.selected_entry()); check(not v.confirm_song_button.visible,"Built-in song remains protected")
    v.confirm.visible=false
    g.countdown=0; g.countdown_ring.hide(); g.countdown_label.hide()
    root.size=Vector2i(1024,600); await shot("compact")
    check(v.grid.get_combined_minimum_size().x<=v.scroll.size.x+1,"Rows fit compact screen")
    check(v.panel.get_global_rect().end.x<=g.size.x+1,"Selected chart panel fits compact screen")
    check(v.edit_button.get_global_rect().end.y<=g.size.y+1,"Actions remain inside compact screen")
    var id=str(g.library.songs[5].id)
    # Give the delete fixture its own audio file so other fixtures stay usable.
    g.demo_stream.save_to_wav("user://songs/delete_fixture.wav"); g.library.songs[5].file="delete_fixture.wav"
    check(g.library.delete_song(id)==OK,"Song deletion succeeds")
    check(not FileAccess.file_exists(v.chart_file(id,"normal")) and not FileAccess.file_exists(v.draft_file(id,"normal")),"Whole-song deletion removes version files and drafts")
    g.queue_free(); await process_frame
    print("Reference chart library: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
