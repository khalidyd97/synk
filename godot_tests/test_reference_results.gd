extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
    await create_timer(.15).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/results-reference-"+name+".png")
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var n=SynkChart.note(2,4,"hold"); n.duration=1; n.checkpoints=[.5]
    g.start_game([n,SynkChart.note(4,3)])
    g.countdown=0; g.song_time=2; g.live[0].timing_error=.02; g.judge(g.live[0],.02,false)
    g.song_time=2.5; g.process_checkpoints(g.live[0],4,false)
    g.song_time=3; g.judge(g.live[0],.08)
    g.song_time=4; g.judge(g.live[1],-1)
    check(g.performance_samples.size()==4,"Accuracy history records hold heads, checkpoints, releases and misses")
    check(g.performance_samples[0].weight==1 and is_equal_approx(g.performance_samples[2].weight,.8) and g.performance_samples[-1].weight==0,"Graph weights follow scoring judgments")
    g._audio_finished()
    check(g.pending_results.notes_total==2 and g.pending_results.notes_hit==1,"Notes hit count note heads separately from hold/checkpoint judgments")
    g.show_pending_results(); check(g.results_screen.combo_value_label.visible and not g.finish_overlay.visible,"Finish hands off to the new results card typography")
    var r=g.results_screen; r.set_process(false)
    var samples: Array=[]
    var weights: Array=[]
    for i in 512: weights.append(1.0)
    for i in 98: weights.append(.8)
    for i in 21: weights.append(.5)
    for i in 11: weights.append(0.0)
    seed(29); weights.shuffle()
    for i in weights.size(): samples.append({"time":i*204.0/weights.size(),"weight":weights[i],"amount":1})
    var id="a".repeat(64)
    g.demo_stream.save_to_wav("user://songs/next_fixture.wav")
    g.library.songs=[{"id":id,"title":"Next Track","album":"Fixture","bpm":120,"file":"next_fixture.wav"}]
    SynkLibrary.atomic_write("user://charts/"+id+".json",{"version":2,"song_id":id,"notes":[SynkChart.note(3,6)],"chart_settings":{"bpm":120,"beat_offset":0.0}})
    g.song_metadata[id]={"duration":96.0,"waveform":g.waveform,"notes":[SynkChart.note(3,6)],"has_chart":true,"note_count":1}
    g.lobby.refresh()
    var data={"cover":preload("res://assets/brand/song_placeholder.svg"),"tint":Color.WHITE,"title":"Neon Drift","artist":"Nova Kai","difficulty":"Normal","bpm":118,"rank":"A","score":948320,"accuracy":93.6,"max_combo":287,
        "counts":{"PERFECT":512,"GREAT":98,"GOOD":21,"MISS":11},"best":948320,"previous_best":935840,"new_best":true,"auto_play":false,"notes_total":642,"notes_hit":631,"range_start":0,"range_end":204,"performance":samples,"timing":[{"time":4,"ms":-20},{"time":7,"ms":40}]}
    g.set_mode("results"); r.show_results(data); r.elapsed=2; r.animate()
    check(r.rank_label.text=="A" and r.score_label.text=="948,320","Reference rank and score show actual supplied results")
    check(r.hit_value.text=="631/642" and r.stats_label.text=="93.6%","Summary cards show note totals and accuracy")
    check(r.total_judgments==642 and r.counts.MISS==11,"Judgment percentages use the true total")
    check(r.best_badge.visible and "+12,480" in r.note_label.text,"New best improvement is measured against the prior record")
    check(r.accuracy_graph.points.size()>1 and r.graph_time.text=="0:00 — 3:24","Song graph uses recorded performance and real duration")
    await shot("desktop")
    r.toggle_graph(); check(r.timing_graph.visible and not r.accuracy_graph.visible,"Timing drilldown remains available")
    r.toggle_graph()
    data.auto_play=true; r.show_results(data); r.elapsed=2; r.animate()
    check(r.rank_label.text=="AUTO" and not r.best_badge.visible and "not saved" in r.note_label.text,"Auto Play remains explicitly unsaved and cannot show New Best")
    data.auto_play=false; data.practice=true; r.show_results(data); r.elapsed=2; r.animate()
    check(r.rank_label.text=="PRACTICE" and r.next_button.disabled and not r.best_badge.visible,"Practice results preserve their scope and do not advance songs")
    data.practice=false; data.performance=[]; data.counts={}; data.notes_total=0; data.notes_hit=0
    r.show_results(data); r.elapsed=2; r.animate()
    check(r.accuracy_graph.points.is_empty() and r.total_judgments==0 and r.hit_value.text=="0/0","Empty results show an honest empty graph without division errors")
    data.performance=samples; data.counts={"PERFECT":512,"GREAT":98,"GOOD":21,"MISS":11}; data.notes_total=642; data.notes_hit=631
    r.show_results(data); r.elapsed=2; r.animate(); root.size=Vector2i(1024,600)
    await shot("compact")
    check(r.detail_panel.get_global_rect().end.x<=g.size.x and r.buttons[-1].get_global_rect().end.x<=g.size.x,"Results fit compact landscape screens")
    g.demo_stream.save_to_wav("user://songs/next_fixture.wav")
    g.library.songs=[{"id":id,"title":"Next Track","album":"Fixture","bpm":120,"file":"next_fixture.wav"}]
    var next_notes=[SynkChart.note(3,6)]
    SynkLibrary.atomic_write("user://charts/"+id+".json",{"version":2,"song_id":id,"notes":next_notes,"chart_settings":{"bpm":120,"beat_offset":0.0}})
    g.song_metadata[id]={"duration":96.0,"waveform":g.waveform,"notes":next_notes,"has_chart":true,"note_count":1}
    g.document.dirty=false; g.lobby.set_filter("all"); g.lobby.refresh()
    g.set_mode("results"); r.show_results(data); r.set_process(true)
    r.next_button.pressed.emit(); g.lobby.select_track(0)
    for frame in 2: await process_frame
    check(g.mode=="menu" and r.pending_next_id.is_empty(),"Choosing another song cancels a pending Next Song launch")
    g.set_mode("results"); r.show_results(data)
    r.next_button.pressed.emit()
    for i in 300:
        g.poll_song_worker(); await process_frame
        if g.mode=="play": break
    check(g.mode=="play" and str(g.song.id)==id and g.live[0].note.lane==6,"Next Song waits for the new audio/chart before starting playback")
    g.set_mode("results"); r.show_results(data); r.buttons[0].pressed.emit()
    check(g.mode=="menu" and not g.lobby.gateway.visible and g.lobby.browser.visible,"Song List returns directly to selection instead of the main lobby")
    g.queue_free(); await process_frame
    print("Reference results screen: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
