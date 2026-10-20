extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func legacy_input(g: Control,p: Vector2) -> Vector2:
    var field=g.field; var camera=field.world.camera
    var pixel=p*Vector2(field.viewport.size)
    var hit=Plane(Vector3.UP,.035).intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
    var on_pad=hit!=null and absf(hit.z)<=field.world.JUDGMENT_DEPTH*.5+.001
    if on_pad: p.y=clampf(p.y,.6001,.9199)
    else:
        pixel=Vector2(p.x*field.viewport.size.x,field.project(field.world.CENTER_LANE,0).y)
        hit=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
    if hit!=null: p.x=.07+((hit.x/field.world.LANE_WIDTH+field.world.CENTER_LANE)+.5)/SynkChart.LANES*.86
    if on_pad and absf(hit.x)<=field.world.PAD_HALF_WIDTH+.001: p.x=clampf(p.x,.070001,.929999)
    return p
func run() -> void:
    var buffer=load("res://scripts/run_sample_buffer.gd").new()
    buffer.begin_reserve(8,4)
    while not buffer.reserve_step(): pass
    var row=buffer.performance[0]
    buffer.add_performance(1,.8); buffer.add_timing(1,-30)
    var snapshot=buffer.performance_snapshot()
    buffer.reset(); buffer.add_performance(2,1)
    check(row.time==2 and snapshot[0].time==1,"Reserved rows are reused while result snapshots remain independent")
    check(buffer.performance_count==1 and buffer.performance_snapshot().size()==1 and buffer.timing_snapshot().is_empty(),"Unused buffer capacity is never exposed as samples")
    check(buffer.fallback_allocations==0,"Reserved writes allocate no new sample dictionaries")
    var hold=SynkChart.note(1,4,"hold"); hold.duration=100
    var live: Array=[{"note":hold,"done":false}]
    for i in range(2,100): live.append({"note":SynkChart.note(i,i%10),"done":false})
    var lookup=load("res://scripts/judgment_lookup.gd").new(live)
    for time in range(2,80):
        for index in lookup.candidates(time):
            if index!=0: live[index].done=true; lookup.retire(index)
    var active=lookup.candidates(79.1)
    check(active.size()==1 and active.has(0),"Long sustain retains judgment tracking without rescanning retired taps")
    check(lookup.candidates(90).has(85),"Overdue notes remain available for miss judgments after a time jump")
    var stream=AudioStreamWAV.new(); stream.mix_rate=22050; stream.format=AudioStreamWAV.FORMAT_16_BITS
    var data=PackedByteArray(); data.resize(44100); stream.data=data
    var validation=load("res://scripts/gameplay_validation.gd")
    var valid_note=SynkChart.note(.5,2)
    check(validation.inspect([valid_note],stream).is_empty(),"A valid chart can start")
    check(not validation.inspect([{"time":.5}],stream).is_empty(),"Malformed chart is rejected")
    check(not validation.inspect([SynkChart.note(2,2)],stream).is_empty(),"Notes beyond audio are rejected")
    check(not validation.inspect([valid_note],null).is_empty(),"Missing song audio is rejected")
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; g.field.world.set_process(false)
    for viewport_size in [Vector2i(1280,720),Vector2i(1000,650)]:
        root.size=viewport_size; await process_frame
        for angle in [18,29,44]:
            g.highway_angle=angle; g.field.world.apply_camera(); g.field.prepare_input_mapping()
            for x in [.05,.2,.5,.8,.95]:
                for y in [.2,.5,.8,.95]:
                    var p=Vector2(x,y)
                    check(g.field.input_position(p).distance_to(legacy_input(g,p))<.0001,"Prepared touch mapping matches original lane and flick coordinates")
                    var camera=g.field.world.camera; var pixel=p*Vector2(g.field.viewport.size)
                    var expected=Plane(Vector3.UP,.035).intersects_ray(camera.project_ray_origin(pixel),camera.project_ray_normal(pixel))
                    var actual=g.field.ground_hit(p,.035)
                    check((actual==null)==(expected==null),"Prepared mapping preserves sky/behind-camera rejection")
                    if actual!=null and expected!=null: check(actual.distance_to(expected)<maxf(.003,expected.length()*.00002),"Prepared touch world point matches ray-plane intersection")
    var builds=g.field.input_mapping.builds; g.field.prepare_input_mapping()
    check(g.field.input_mapping.builds==builds,"Unchanged input projection reuses cached transforms")
    g.field.world.camera.position.x+=.04; g.field.prepare_input_mapping()
    check(g.field.input_mapping.builds==builds+1,"Camera movement invalidates touch transforms")
    var mode=g.mode; var before=g.live.size()
    g.start_game([{"time":1}],false)
    check(g.mode==mode and g.live.size()==before,"Rejected chart leaves the current screen and run intact")
    g.queue_free(); await process_frame
    print("Input, judgment, buffer and validation preparation: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
