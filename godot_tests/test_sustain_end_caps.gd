extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; g.set_mode("play"); g.apply_stage_cover()
    var w=g.field.world; w.set_process(false)
    for shape in ["circle","rectangle"]:
        g.note_shape=shape
        for size in [.6,1.0,1.25]:
            g.note_size=size
            for style in ["neon","solid"]:
                g.trail_style=style
                for kind in ["hold","slide"]:
                    for recording in [false,true]:
                        var note=SynkChart.note(3,3,kind); note.duration=.5
                        if kind=="slide": note.end_lane=6; note.path=[{"offset":0.0,"lane":3.0},{"offset":.5,"lane":6.0}]
                        var group=Node3D.new(); w.add_child(group)
                        var palette=w.palette_for_kind(kind)
                        var head=w.make_cap(group,note.lane,0,palette,recording)
                        w.make_ribbon(group,note,palette,recording)
                        var tail=group.get_node("SustainEndCap")
                        check(is_equal_approx(tail.mesh.size.x/head.mesh.size.x,.65) and is_equal_approx(tail.mesh.size.y/head.mesh.size.y,.65),"Both dimensions are exactly 35% smaller")
                        check(tail.material_override.shader==head.material_override.shader,"Endpoint uses the same filled note artwork shader")
                        check(tail.position.y+.0001>=w.trail_height(),"Filled endpoint stays above its trail")
                        check(tail.rotation.is_equal_approx(head.rotation),"Endpoint keeps the original note silhouette")
                        check(is_equal_approx(tail.position.x,w.lane_x(note.end_lane)) and is_equal_approx(tail.position.z,.5*w.travel_speed()*(1 if recording else -1)),"Endpoint stays at the exact release time and lane")
                        w.set_trail_clip(group,0)
                        check(tail.material_override.get_shader_parameter("clip_z")==0,"Endpoint respects sustain clipping")
                        group.queue_free()
    g.note_shape="circle"; g.note_size=1.0; g.trail_style="solid"
    var hold=SynkChart.note(2,2,"hold"); hold.duration=.7
    var slide=SynkChart.note(2,6,"slide"); slide.duration=.7; slide.end_lane=7
    slide.path=[{"offset":0.0,"lane":6.0},{"offset":.7,"lane":7.0}]
    g.start_game([hold,slide],true); g.countdown=0; g.song_time=1.7; w._process(0)
    await process_frame; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/filled-sustain-endpoints.png")
    print("Filled sustain endpoints: "+("PASS" if failures==0 else "FAIL"))
    g.queue_free(); await process_frame; quit(failures)
