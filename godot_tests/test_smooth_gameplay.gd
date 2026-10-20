extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var w=g.field.world; w.set_process(false)
    var hold=SynkChart.note(1,4,"hold"); hold.duration=8
    g.start_game([hold,SynkChart.note(2,2),SynkChart.note(3,6)],false)
    g.countdown=0; g.song_time=1.4; g.judge(g.live[0],-1)
    check(g.first_live_index()==1,"Judgment cursor skips completed notes")
    check(g.total_judgements()==4,"Cached totals include the hold head and release")
    w._process(0)
    check(w.notes.has("play0"),"Missed long hold remains visible after judgment cursor advances")
    g.song_time=10; g.visual_song_time=10; w._process(0)
    check(not w.notes.has("play0") or not w.notes.play0.node.visible,"Missed hold hides after its tail leaves the highway; prebuilt resources stay reusable")
    g.start_game([SynkChart.note(2,4)],false); g.countdown=0; g.song_time=1
    check(g.first_live_index()==0 and w.play_render_cursor==0,"Retry resets both cursors")
    w.spawn_hit(4,"tap"); var first=w.bursts[0].node.get_instance_id()
    w.animate_effects(.7)
    check(w.bursts.is_empty() and w.hit_pool.size()==1,"Expired hit returns to the bounded pool")
    w.spawn_hit(7,"slide")
    check(w.bursts[0].node.get_instance_id()==first and w.bursts[0].kind=="slide","Tap and slide reuse identical regular hit geometry")
    check(is_equal_approx(w.bursts[0].node.position.x,w.lane_x(7)),"Reused hit resets its lane position")
    w.animate_effects(.03); w.spawn_hit(2,"tap")
    check(w.bursts[0].flash.material_override!=w.bursts[1].flash.material_override,"Simultaneous hits retain independent opacity")
    w.clear_hit_effects()
    check(w.bursts.is_empty() and w.hit_pool.is_empty(),"Restart releases all pooled and active hit resources")
    for i in 40: w.spawn_hit(i%10,"tap")
    check(w.bursts.size()<=32,"Dense chords keep active effect allocation bounded")
    w.animate_effects(.7)
    check(w.hit_pool.size()<=w.HIT_POOL_LIMIT,"Inactive effect pool remains bounded")
    w.apply_palette(SynkCoverPalette.fallback())
    check(w.hit_pool.is_empty(),"Theme changes discard stale cached hit colors")
    g.combo=12; g.update_combo_art(); var digit=g.combo_hud.get_child(0).get_instance_id()
    g.combo=13; g.update_combo_art()
    check(g.combo_hud.get_child(0).get_instance_id()==digit and g.combo_view.combo==13,"Combo label is reused during dense hits")
    for speed in [.25,.5,1.0,1.5]:
        g.audio.pitch_scale=speed; g.visual_clock_ready=false
        var elapsed=0.0; var previous=0.0
        g.smooth_visual_time(0,1.0/60)
        for i in 240:
            var delta=[1.0/60,1.0/120,1.0/90,1.0/45][i%4]
            elapsed+=delta*speed
            var target=floor(elapsed/.02)*.02
            g.smooth_visual_time(target,delta)
            check(g.visual_song_time>=previous,"Visual clock never reverses under mixer jitter at any practice speed")
            check(absf(g.visual_song_time-elapsed)<.06,"Visual motion remains close to the audio clock")
            previous=g.visual_song_time
    g.smooth_visual_time(20,.016)
    check(is_equal_approx(g.visual_song_time,20),"Real seeks still reset motion immediately")
    for note_speed in [.5,1.0,2.5]:
        g.note_speed=note_speed; g.audio.pitch_scale=1; g.visual_clock_ready=false
        var note=SynkChart.note(20,4); var elapsed=20-g.note_travel_seconds()
        var target=elapsed; var previous_width=0.0; var previous_y=-INF; var reversals=0
        g.smooth_visual_time(target,1.0/60)
        for i in 700:
            var delta=[1.0/60,1.0/120,1.0/90,1.0/45][i%4]
            elapsed+=delta
            if i<30 or i>=50: target=floor(elapsed/.02)*.02
            var before=g.visual_song_time; g.smooth_visual_time(target,delta)
            if g.visual_song_time<before: reversals+=1
            g.song_time=g.visual_song_time
            w.sync_note("motion_probe",note,{},false,g.visual_song_time)
            var head=w.notes.motion_probe.node.get_child(0)
            var left=w.camera.unproject_position(head.global_transform*Vector3(-head.mesh.size.x*.5,0,0))
            var right=w.camera.unproject_position(head.global_transform*Vector3(head.mesh.size.x*.5,0,0))
            var width=left.distance_to(right); var y=w.camera.unproject_position(head.global_position).y
            check(width>=previous_width-.001,"Approaching notes never shrink through a stale audio sample")
            check(y>=previous_y-.001,"Approaching notes continue falling toward the judgment line")
            previous_width=width; previous_y=y
            if g.visual_song_time>=20: break
        check(reversals==0,"Mobile-sized timing stalls cause no backward frames at any note speed")
    g.queue_free(); await process_frame
    print("Smooth gameplay regressions: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
