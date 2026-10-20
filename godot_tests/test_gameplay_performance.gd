extends SceneTree
# Requires the graphics renderer: the headless dummy does not retain MultiMesh transforms.
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var w=g.field.world; w.set_process(false)
    g.start_game([SynkChart.note(2,4)],false); g.countdown=0
    w.clear_hit_effects(); w.spawn_hit(4,"tap"); w.animate_effects(.1)
    var burst=w.bursts[0]; var batch=burst.particle_batch
    check(batch is MultiMeshInstance3D,"Sparks share one instanced draw per hit")
    check(burst.node.get_child_count()==4,"A regular burst has only flash, fill, ring and particle batch")
    check(batch.multimesh.instance_count==burst.particles.size(),"Instanced capacity preserves particle count")
    check(batch.multimesh.get_instance_transform(0).origin.length()>0,"Batched sparks travel away from the hit")
    g.features.effects["Particles"]=0; w.animate_effects(.01)
    check(batch.multimesh.visible_instance_count==0,"Zero density hides all instances")
    g.features.effects["Particles"]=.5; w.animate_effects(.01)
    check(batch.multimesh.visible_instance_count==ceili(burst.particles.size()*.5),"Half density draws half the batch")
    var before=batch.multimesh.get_instance_transform(0)
    g.mode="paused"; w.animate_effects(.1)
    check(batch.multimesh.get_instance_transform(0)==before,"Pause freezes particle transforms")
    g.mode="play"; g.features.effects["Particles"]=1; w.animate_effects(.7)
    w.spawn_hit(6,"tap")
    check(w.bursts[0].particle_batch==batch and batch.multimesh.visible_instance_count==0,"Reused batch hides stale instances before its next update")
    w.clear_hit_effects()
    var dense: Array=[]
    for i in 20: dense.append(SynkChart.note(3+i*.01,i%SynkChart.LANES))
    g.start_game(dense,true); w.clear_hit_effects()
    var required=w.chart_hit_pool_requirements()
    check(required.get("0normal")==20,"Pool sizing covers twenty overlapping taps rather than a fixed ten")
    w.spawn_hit(1,"tap"); w.animate_effects(.7)
    w.prefill_hits()
    check(w.hit_pool.size()==20,"Prefill adds missing effects without consuming its warm inventory")
    var warm_ids: Dictionary={}
    for hit in w.hit_pool: warm_ids[hit.node.get_instance_id()]=true
    w.prefill_hits()
    check(w.hit_pool.size()==20 and w.hit_pool.all(func(hit): return warm_ids.has(hit.node.get_instance_id())),"Repeated prefill neither rebuilds nor grows a complete pool")
    var ids: Dictionary={}
    for hit in w.hit_pool: ids[hit.node.get_instance_id()]=true
    for i in 20: w.spawn_hit(i%SynkChart.LANES,"tap")
    check(w.bursts.all(func(hit): return ids.has(hit.node.get_instance_id())),"Dense opening reuses prefetched hits without allocating")
    check(w.hit_pool.size()+w.bursts.size()<=w.HIT_POOL_LIMIT,"Chart-specific effect inventory remains bounded")
    w.clear_hit_effects()
    var hold=SynkChart.note(1,3,"hold"); hold.duration=8
    var later=SynkChart.note(5,7,"hold"); later.duration=2
    g.start_game([hold,later],true)
    check(w.chart_hit_pool_requirements().get("1normal",0)>=2,"Long sustain heads remain in the overlap calculation")
    w.apply_camera(); w.update_cover_backdrop()
    var camera_updates=w.camera_revision; var backdrop_updates=w.backdrop_projection_updates
    w.apply_camera(); w.update_cover_backdrop()
    check(w.camera_revision==camera_updates and w.backdrop_projection_updates==backdrop_updates,"Stationary camera and backdrop skip repeated projection work")
    w.apply_camera(Vector3(.04,0,0)); w.update_cover_backdrop()
    check(w.backdrop_projection_updates==backdrop_updates+1,"Miss-shake movement invalidates the backdrop cache")
    w.apply_camera(); w.update_cover_backdrop(); g.align_gameplay_hud()
    var layouts=g.hud_layout_updates
    g.align_gameplay_hud()
    check(g.hud_layout_updates==layouts,"Unchanged gameplay HUD skips projection and layout")
    w.apply_camera(Vector3(.03,0,0)); g.align_gameplay_hud()
    check(g.hud_layout_updates==layouts+1,"Camera motion invalidates HUD positioning")
    root.size=Vector2i(1000,650); await process_frame
    w.update_cover_backdrop(); g.align_gameplay_hud()
    check(w.backdrop_projection_updates>backdrop_updates+1 and g.hud_layout_updates>layouts+1,"Viewport resize refreshes backdrop and HUD geometry")
    g.queue_free(); await process_frame
    print("Gameplay performance regressions: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
