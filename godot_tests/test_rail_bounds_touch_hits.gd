extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func point(g: Control,lane: float,z: float) -> Vector2:
    return g.field.world.camera.unproject_position(Vector3(g.field.world.lane_x(lane),.035,z))/Vector2(g.field.viewport.size)
func line_anchor(g: Control,p: Vector2,height: float) -> Vector3:
    var world=g.field.touch_world_position(p)
    return Vector3(clampf(world.x,-g.field.world.HIGHWAY_HALF_WIDTH,g.field.world.HIGHWAY_HALF_WIDTH),height,0)
func frame() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_child(0).field.viewport.get_texture().get_image()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var w=g.field.world
    check(is_equal_approx(w.NOTE_SCALE,1.3) and is_equal_approx(w.NOTE_WIDTH,4.03) and w.FIT==1.0,"Original absolute note and effect sizes are preserved")
    check(is_equal_approx(w.FRAME_HALF_WIDTH,9.75),"Original highway width is restored")
    var pads=w.get_node("JudgmentPads")
    check(is_equal_approx(pads.mesh.size.x,19.5),"Original judgment band spans the full highway")
    check(not pads.has_node("LeftEndCap") and not pads.has_node("RightEndCap"),"No added end caps or inset band remain")
    check(is_equal_approx(w.finger_beams[0].mesh.size.x,w.NOTE_WIDTH),"Finger beams cover the full original note width")
    check(is_equal_approx(float(w.highway_shadow_material.get_shader_parameter("opacity")),.2),"Highway shadow uses the requested 20 percent opacity")
    var original_band=g.band_color; var original_style=g.highway_style
    g.band_color="39b7da"
    for style in ["gold","neon"]:
        g.highway_style=style; w.refresh_highway_look()
        var expected=Color("39b7da").darkened(.65)
        check(w.highway_shadow_material.get_shader_parameter("tint").is_equal_approx(expected),"Shadow follows custom judgment color in both highway styles")
    g.band_color=original_band; g.highway_style=original_style; w.refresh_highway_look()
    var hold=SynkChart.note(10,0,"hold"); hold.duration=4
    var right=SynkChart.note(10,9,"hold"); right.duration=4
    g.start_game([hold,right],false); g.countdown=0; g.song_time=10
    var left_touch=point(g,.35,.7); var right_touch=point(g,8.65,-.6)
    g.pointer_event(1,left_touch,true,false,false); g.pointer_event(2,right_touch,true,false,false)
    check(w.bursts.size()==2,"Both fingers receive independent hit effects")
    check(w.bursts[0].node.position.distance_to(line_anchor(g,left_touch,.1))<.001,"Left hit follows touch X while anchored to the judgment line")
    check(w.bursts[1].node.position.distance_to(line_anchor(g,right_touch,.1))<.001,"Right hit anchors independently on the judgment line")
    var moved=point(g,.15,-.7); g.pointer_event(1,moved,false,false,false); w.animate_effects(.05)
    check(w.bursts[0].node.position.distance_to(line_anchor(g,moved,.1))<.001,"Sustained hit follows horizontal movement without leaving the judgment line")
    for angle in [18.0,29.0,44.0]:
        g.highway_angle=angle; w.animate_miss_shake(0); w.animate_effects(.02)
        for burst in w.bursts:
            check(burst.flash.position.is_equal_approx(Vector3(0,(2.25-4.0*w.HIT_MIRROR*.5)*w.FIT,0)),"Original flash layout stays unchanged while origin is locked to the line")
            check(burst.fill.position.is_equal_approx(Vector3(0,2.25*w.FIT,0)),"Original fill layout is preserved")
            check(is_zero_approx(burst.node.position.z),"Only the hit origin is constrained to the judgment line")
    g.highway_angle=29; w.animate_miss_shake(0)
    var fallback=w.touch_hit_position(5,-999)
    check(is_equal_approx(fallback.x,w.lane_x(5)) and fallback.z==0,"Auto Play retains note-based hit positioning")
    g.countdown_ring.hide(); g.countdown_label.hide(); g.song_time=10.6
    await create_timer(.4).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/rail-bounds-touch-hits.png")
    var slide=SynkChart.note(10,4,"slide"); slide.duration=3; slide.end_lane=6
    slide.path=[{"offset":0.0,"lane":4.0},{"offset":3.0,"lane":6.0}]
    g.start_game([slide],false); g.countdown=0; g.song_time=10
    var slide_touch=point(g,4.3,.6); g.pointer_event(3,slide_touch,true,false,false); w._process(0)
    check(w.active_beams[4].position.distance_to(line_anchor(g,slide_touch,.08))<.001,"Slide secondary glow stays on the judgment line")
    var flick=SynkChart.note(20,4,"flick"); flick.direction=1
    g.start_game([flick],false); g.countdown=0; g.song_time=20
    g.pointer_event(4,point(g,4.2,0),true,false,false)
    var flick_touch=point(g,5.4,.5); g.song_time=20.02; g.pointer_event(4,flick_touch,false,true,false)
    check(w.bursts.size()==1 and w.bursts[0].kind=="flick","Manual flick still judges after swipe")
    if not w.bursts.is_empty(): check(w.bursts[0].node.position.distance_to(line_anchor(g,flick_touch,.1))<.001,"Flick hit uses swipe X anchored to the judgment line")
    w.set_process(false); w.clear_notes(); w.clear_hit_effects()
    # Isolate rendered note/beam pixels to check the rail silhouette on the GPU.
    for child in w.get_children():
        if child is WorldEnvironment:
            child.environment.background_mode=Environment.BG_COLOR; child.environment.background_color=Color.BLACK
        elif child is Node3D and child!=w.camera: child.visible=false
    w.cover_backdrop.visible=false
    g.change_note_sizing("note_size",1.25); g.change_note_sizing("hold_trail_width",1.5)
    for shape in ["circle","rectangle"]:
        g.note_shape=shape
        var group=Node3D.new(); w.add_child(group); group.position.z=-.5
        for lane in [0,9]:
            w.make_cap(group,lane,0,0)
            var visual_flick=SynkChart.note(0,lane,"flick"); visual_flick.direction=3 if lane==0 else 1; w.make_flick(group,visual_flick,2)
            var trail=SynkChart.note(0,lane,"slide"); trail.duration=.7; w.make_ribbon(group,trail,1)
        for beam in w.finger_beams: beam.visible=false
        for i in 2:
            var beam=w.finger_beams[i]; beam.visible=true; beam.position.x=w.lane_x(0 if i==0 else 9)
        for angle in [18.0,29.0,44.0]:
            g.highway_angle=angle; w.animate_miss_shake(0)
            # Raised 3D heads are checked visually; only ground beams must match
            # the ground-plane silhouette at every camera angle.
            group.visible=false
            var image=await frame(); var spill=0; var lit=0
            for y in range(0,image.get_height(),3):
                for x in range(0,image.get_width(),3):
                    var c=image.get_pixel(x,y)
                    if maxf(c.r,maxf(c.g,c.b))<.04: continue
                    var hit=g.field.touch_world_position(Vector2(float(x)/image.get_width(),float(y)/image.get_height()))
                    if hit.z< -55 or hit.z>2: continue
                    lit+=1
                    if absf(hit.x)>w.FRAME_HALF_WIDTH+.15: spill+=1
            group.visible=true
            var full_image=await frame()
            full_image.save_png("res://.tools/isolated-rail-"+shape+"-"+str(angle)+".png")
            check(lit>20,"Outer note/beam geometry remains visible")
            check(spill==0,"Full-width ground beams stay inside projected rails: "+shape+" / "+str(angle))
        group.queue_free(); await process_frame
    g.queue_free(); await process_frame
    print("Rail bounds and touch hit positions: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)

