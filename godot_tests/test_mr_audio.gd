extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func stereo_song() -> AudioStreamWAV:
    var rate=22050; var bytes=PackedByteArray(); bytes.resize(rate*4*4)
    for i in rate*4:
        var t=float(i)/rate
        var vocal=.3*sin(TAU*1000*t); var bass=.2*sin(TAU*60*t); var instrument=.15*sin(TAU*2500*t)
        bytes.encode_s16(i*4,roundi((vocal+bass+instrument)*32767))
        bytes.encode_s16(i*4+2,roundi((vocal+bass-instrument)*32767))
    var stream=AudioStreamWAV.new(); stream.mix_rate=rate; stream.stereo=true; stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.data=bytes
    return stream
func amplitude(bytes: PackedByteArray,frequency: float) -> float:
    var real=0.0; var imaginary=0.0; var count=11025
    for i in count:
        var at=i+22050; var value=float(bytes.decode_s16(at*2))/32767
        real+=value*cos(TAU*frequency*at/22050.0); imaginary+=value*sin(TAU*frequency*at/22050.0)
    return 2*sqrt(real*real+imaginary*imaginary)/count
func run():
    var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
    game.set_process(false); game.stage_intro_enabled=false
    game.mr.enabled=false; var source=stereo_song()
    game.audio.stream=source; game.mr.set_source(source); game.set_mode("editor")
    game.cursor=1; game.toggle_audition(); game.audio.pitch_scale=.5
    game.mr.toggle()
    var timeout=Time.get_ticks_msec()+15000
    while game.mr.reduced==null and game.mr.unavailable.is_empty() and Time.get_ticks_msec()<timeout: await process_frame
    check(game.mr.reduced!=null,"MR prepares stereo audio: "+game.mr.unavailable)
    if game.mr.reduced!=null:
        var data=game.mr.reduced.data
        check(absf(game.mr.reduced.get_length()-source.get_length())<.001,"MR keeps exact track length")
        check(amplitude(data,1000)<.06,"Centered vocal frequency is reduced")
        check(amplitude(data,60)>.16,"Centered bass is retained")
        check(amplitude(data,2500)>.13,"Stereo instruments are retained")
        check(game.audio.stream==game.mr.reduced and game.audio.playing,"Editor switches to MR while playing")
        check(game.audio.get_playback_position()>=1 and game.audio.get_playback_position()<1.8,"Switch retains playback position")
        check(is_equal_approx(game.audio.pitch_scale,.5),"Switch retains playback speed")
        game.mr.toggle(); check(game.audio.stream==source and game.audio.playing,"Toggle off restores source")
        game.mr.toggle(); game.stop_audition(); game.document.load_notes([]); game.record_speed=.5; game.record_here()
        check(game.audio.stream==game.mr.reduced and game.audio.pitch_scale==.5,"Recorder combines MR with slow playback")
        game.countdown=0; game.audio.play(1); game.toggle_pause()
        check(game.audio.stream==game.mr.reduced and game.audio.stream_paused,"Recorder pause retains MR")
        game.toggle_pause(); game.stop_take(); game.start_game([SynkChart.note(1,0)])
        check(game.audio.stream==source and game.audio.pitch_scale==1,"Gameplay uses original audio at normal speed")
    game.audio.stop(); game.mr.set_source(game.demo_stream); game.audio.stream=game.demo_stream
    check(not game.mr.unavailable.is_empty() and game.mr.reduced==null,"Mono audio falls back without silencing music")
    game.set_mode("editor")
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/mr-editor.png")
    game.record_here()
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/mr-recorder.png")
    game.audio.stop(); game.queue_free(); await process_frame
    print("MR audio integration: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
