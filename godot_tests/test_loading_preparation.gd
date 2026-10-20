extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g)
    await create_timer(3).timeout
    g.set_process(false)
    var w=g.field.world; var loader=g.gameplay_loading
    var hold=SynkChart.note(4,3,"hold"); hold.duration=1
    var slide=SynkChart.note(5,5,"slide"); slide.duration=1; slide.end_lane=7
    slide.path=[{"offset":0.0,"lane":5.0},{"offset":1.0,"lane":7.0}]; slide.checkpoints=[.25,.75]
    var chart=[SynkChart.note(3,2),hold,slide,SynkChart.note(6,9,"flick")]
    g.start_game(chart,true)
    g._process(.5)
    var countdown=g.countdown; var initial_text=g.hud.text
    check(w.prebuild_index==0,"Note allocation waits until previous resources have drained")
    g.set_mode("paused"); var paused_progress=loader.progress
    await create_timer(.15).timeout
    check(loader.progress==paused_progress and not g.audio.playing,"Pausing suspends loading work")
    g.set_mode("play")
    check(loader.preparing and countdown==3 and not g.audio.playing,"Countdown and audio wait for loading preparation")
    var shape=g.note_shape; var style=g.trail_style
    var deadline=Time.get_ticks_msec()+90000
    var previous=""
    var snapped=false
    while loader.preparing and Time.get_ticks_msec()<deadline:
        if previous!=loader.status: previous=loader.status; print("Loading stage: ",previous)
        if loader.status=="WARMING NOTE APPEARANCE" and not snapped:
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://.tools/loading-preparation-preview.png")
            snapped=true
        g._process(.016)
        check(g.countdown==countdown and not g.audio.playing,"Preparation never starts the song early")
        check(g.note_shape==shape and g.trail_style==style,"Warm-up variants do not leak into active settings")
        await process_frame
    check(not loader.preparing and loader.progress==1,"Loading completes")
    check(loader.variants_drawn==42,"Every note appearance and classic effect direction is rendered")
    check(loader.audio_primed and loader.primed_frames>0 and loader.prime_playback==null,"Decoder primes silently and releases its private playback")
    check(not loader.frame_time_samples.is_empty(),"Final readiness measures real frame intervals")
    check(g.background_work_suspended and g.lobby.process_mode==Node.PROCESS_MODE_DISABLED,"Hidden menu branches and background scan integration stop during play")
    check(w.play_visibility!=null and g.live[2].has("curve"),"Loading prepares both slide coefficients and visibility events")
    check(g.live[2].checkpoint_lanes.size()==2 and absf(g.live[2].checkpoint_lanes[0]-SynkChart.lane_at(g.live[2].note,5.25))<.000001,"Checkpoint lanes are prepared using the same slide curve")
    check(not g.live[2].note.has("curve"),"Runtime caches stay out of chart data")
    check(loader.uploaded_notes==g.live.size(),"Every real chart note is submitted behind the loading card")
    check(loader.uploaded_effects==w.hit_pool.size()+w.bloom_pool.size(),"Every prepared effect instance is submitted before countdown")
    check(loader.rendered_frames>=loader.SETTLE_FRAMES,"Readiness includes rendered settling frames")
    check(w.bursts.is_empty() and w.blooms.is_empty(),"Warm-up effects are recycled before countdown")
    check(w.bloom_pool.size()>=24,"Bloom effects are ready even when classic is selected")
    check(loader.temporary.is_empty() and loader.uploading.is_empty(),"Warm-up widgets and uploaded-note overrides are cleaned up")
    check(g.hud.text==initial_text,"HUD warm-up never replaces the live score")
    var pools=w.hit_pool.size()
    check(pools>0 and pools<=w.HIT_POOL_LIMIT,"Chart peak capacity is prepared and bounded")
    g.stage_intro.elapsed=g.stage_intro.load_time+g.stage_intro.ENTER_TIME
    g.stage_intro.visible=false; g._process(.1)
    check(g.countdown<countdown,"Countdown advances after preparation and presentation finish")
    # A retry still waits behind an opaque card, and cancelling invalidates its coroutine.
    g.start_game(chart,true); var token=loader.generation
    g.stage_intro.skip()
    check(g.stage_intro.visible and loader.preparing,"Skipping presentation cannot expose warm-up graphics")
    g.set_mode("menu"); await create_timer(.2).timeout
    check(not g.background_work_suspended and g.lobby.process_mode!=Node.PROCESS_MODE_DISABLED,"Returning to the menu restores background processing")
    check(not loader.preparing and loader.generation>token and loader.temporary.is_empty(),"Leaving gameplay cancels preparation safely")
    # A second run cancels a partially warmed run without allowing stale completion.
    g.start_game(chart,true)
    deadline=Time.get_ticks_msec()+30000
    while loader.status!="WARMING NOTE APPEARANCE" and Time.get_ticks_msec()<deadline: await process_frame
    token=loader.generation
    g.start_game([SynkChart.note(4,1)],false)
    check(loader.generation>token and loader.preparing and loader.progress==0,"Restart replaces the loading generation")
    await create_timer(.1).timeout
    check(g.live.size()==1 and g.note_shape==shape and g.trail_style==style,"Cancelled warm-up cannot alter the next chart")
    g.set_mode("menu"); await create_timer(.1).timeout
    # Exercise the real update loop through loading, countdown, audio, and a first bloom hit.
    g.hit_style="bloom"
    var live_slide=SynkChart.note(.5,4,"slide"); live_slide.duration=.4; live_slide.end_lane=5
    live_slide.path=[{"offset":0.0,"lane":4.0},{"offset":.4,"lane":5.0}]
    g.start_game([live_slide,SynkChart.note(2,7)],true)
    g.set_process(true)
    deadline=Time.get_ticks_msec()+90000
    while g.judged<1 and Time.get_ticks_msec()<deadline:
        if g.mode=="paused": g.toggle_pause()
        await process_frame
    check(not loader.preparing and not g.stage_intro.running() and g.countdown==0,"Live countdown starts only after all preparation completes")
    check(g.audio.playing and g.judged>=1 and not w.blooms.is_empty(),"Live autoplay reaches its first prewarmed bloom hit")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/loading-ready-gameplay.png")
    g.set_mode("menu"); await process_frame
    g.queue_free(); await process_frame
    print("Gameplay loading preparation: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
