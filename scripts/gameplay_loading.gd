extends Node
# Serial loading stages keep shader/resource work behind the opaque loading card.
# A generation token prevents a cancelled/restarted load from touching a later run.
const BUDGET_USEC = 4000
const UPLOAD_BATCH = 16
const SETTLE_FRAMES = 3
var game: Control
var preparing = false
var allow_note_build = false
var generation = 0
var progress = 1.0
var status = "READY"
var rendered_frames = 0
var variants_drawn = 0
var uploaded_notes = 0
var uploaded_effects = 0
var prime_playback: AudioStreamPlayback
var primed_sounds=0
var primed_frames=0
var audio_primed=false
var frame_stable=false
var frame_time_samples=PackedFloat64Array()
var temporary: Array = []
var uploading: Array = []

func cancel() -> void:
    generation += 1
    if preparing and game.field: game.field.world.prebuilding=false
    if prime_playback: prime_playback.stop(); prime_playback=null
    preparing = false; allow_note_build=false
    for entry in uploading:
        if is_instance_valid(entry[0]): entry[0].transform=entry[1]; entry[0].visible=false
    uploading.clear()
    for node in temporary:
        if is_instance_valid(node): node.queue_free()
    temporary.clear()

func begin() -> void:
    cancel()
    preparing=true; progress=0; status="PREPARING STAGE"
    rendered_frames=0; variants_drawn=0; uploaded_notes=0; uploaded_effects=0
    primed_sounds=0; primed_frames=0; audio_primed=false; frame_stable=false; frame_time_samples.clear()
    run.call_deferred(generation)

func valid(token: int) -> bool:
    return token==generation and preparing and game.mode in ["play","paused"]

func frame(token: int) -> bool:
    # Pause suspends loading as well as the stage animation.
    while valid(token) and game.mode=="paused": await get_tree().process_frame
    if not valid(token): return false
    if DisplayServer.get_name()=="headless": await get_tree().process_frame
    else: await RenderingServer.frame_post_draw
    if not valid(token): return false
    rendered_frames+=1
    # Resume on the next update, not inside the render submission callback.
    await get_tree().process_frame
    return valid(token)

func draw_frames(token: int,count: int=2) -> bool:
    for i in count:
        if not await frame(token): return false
    return true

func discard(node: Node) -> void:
    temporary.erase(node)
    if is_instance_valid(node): node.queue_free()

func run(token: int) -> void:
    var w=game.field.world
    status="CLEARING PREVIOUS STAGE"
    if not await draw_frames(token): return
    # queue_free has drained before building the next effect inventory.
    w.animated_materials=w.animated_materials.filter(func(ref): return ref.get_ref()!=null)
    status="FINISHING BACKGROUND TASKS"
    if game.document.dirty and game.features.autosave()!=OK:
        game.tell("The draft could not be saved. Your edits remain open in Chart Studio.")
    game.mr.suspend_background_render()
    while not game.worker_song_id.is_empty() or game.mr.worker.is_started():
        game.poll_song_worker(true); game.mr._process(0)
        if not await frame(token): return
    progress=.02; status="PREPARING AUDIO"
    if game.audio.stream and game.audio.stream.get_length()>0:
        prime_playback=game.audio.stream.instantiate_playback()
        if prime_playback:
            prime_playback.start(maxf(0,game.start_position))
            var finished=false
            while primed_frames<4096 and not finished:
                var started=Time.get_ticks_usec()
                while primed_frames<4096 and Time.get_ticks_usec()-started<BUDGET_USEC:
                    var frames=prime_playback.mix_audio(1.0,mini(512,4096-primed_frames))
                    primed_frames+=frames.size()
                    if frames.is_empty(): finished=true; break
                if not await frame(token): return
            prime_playback.stop(); prime_playback=null
            audio_primed=primed_frames>0
    status="PREPARING GAME SOUNDS"
    var sounds: Array=game.extras.SOUNDS.values()+game.UiSound.SOUNDS.values()
    var sound_budget=Time.get_ticks_usec()
    for stream in sounds:
        prime_playback=stream.instantiate_playback()
        if prime_playback:
            prime_playback.start(); prime_playback.mix_audio(1.0,512)
            prime_playback.stop(); prime_playback=null; primed_sounds+=1
        if Time.get_ticks_usec()-sound_budget>=BUDGET_USEC:
            if not await frame(token): return
            sound_budget=Time.get_ticks_usec()
    progress=.04; status="PREPARING NOTE TIMELINE"
    var cursor=0
    while cursor<game.live.size():
        var started=Time.get_ticks_usec()
        while cursor<game.live.size() and Time.get_ticks_usec()-started<BUDGET_USEC:
            var entry: Dictionary=game.live[cursor]
            if entry.note.kind=="slide": entry.curve=preload("res://scripts/playback_curve.gd").new(entry.note)
            var lanes=PackedFloat64Array()
            for offset in entry.note.get("checkpoints",[]): lanes.append(game.play_lane_at(entry,float(entry.note.time)+float(offset)))
            entry.checkpoint_lanes=lanes; entry.judgment_index=cursor; entry.end_time=float(entry.note.time)+float(entry.note.duration); cursor+=1
        progress=.04+.04*float(cursor)/maxi(1,game.live.size())
        if not await frame(token): return
    w.play_visibility=preload("res://scripts/playback_visibility.gd").new(game.live,game.note_travel_seconds(),w.travel_speed())
    w.apply_camera(); w.update_cover_backdrop()
    status="PREPARING INPUT AND JUDGMENTS"
    game.field.prepare_input_mapping()
    game.judgment_lookup=preload("res://scripts/judgment_lookup.gd").new(game.live)
    game.run_samples.begin_reserve(game.total_judgements()+16,game.live.size() if not game.auto_play else 0)
    while not game.run_samples.reserve_step(BUDGET_USEC):
        if not await frame(token): return
    status="BUILDING NOTES"; allow_note_build=true
    while w.prebuilding:
        progress=.08+w.prebuild_progress()*.32
        if not await frame(token): return
    allow_note_build=false
    progress=.4; status="PREPARING HIT EFFECTS"
    var wanted=w.chart_hit_pool_requirements()
    var keys: Array=[]
    for key in wanted:
        var have=0
        for hit in w.hit_pool:
            if hit.pool_key==key: have+=1
        for i in maxi(0,int(wanted[key])-have): keys.append(key)
    var index=0
    while index<keys.size():
        var started=Time.get_ticks_usec()
        while index<keys.size() and Time.get_ticks_usec()-started<BUDGET_USEC:
            w.add_pooled_hit(keys[index]); index+=1
        progress=.4+.12*float(index)/maxi(1,keys.size())
        if not await frame(token): return
    # Both styles are warmed, so switching styles never introduces a first-use shader.
    while w.bloom_pool.size()<24:
        var started=Time.get_ticks_usec()
        while w.bloom_pool.size()<24 and Time.get_ticks_usec()-started<BUDGET_USEC:
            w.bloom_pool.append(w.make_bloom())
        if not await frame(token): return
    progress=.52; status="WARMING NOTE APPEARANCE"
    var tasks: Array=[]
    for shape in ["rectangle","circle","puck"]:
        for palette in 4: tasks.append(["cap",shape,palette])
        for direction in 4: tasks.append(["flick",shape,direction])
        for style in ["neon","solid"]:
            for kind in ["hold","slide"]: tasks.append([kind,shape,style])
    for task in tasks:
        if not valid(token): return
        var group=Node3D.new(); w.add_child(group); group.position.z=-24
        temporary.append(group)
        var shape=game.note_shape; var style=game.trail_style
        game.note_shape=task[1]
        if task[0]=="cap": w.make_cap(group,w.CENTER_LANE,0,int(task[2]))
        elif task[0]=="flick":
            var note=SynkChart.note(0,6,"flick"); note.direction=int(task[2]); w.make_flick(group,note,2)
        else:
            game.trail_style=task[2]
            var note=SynkChart.note(0,6,task[0]); note.duration=.5; note.end_lane=8
            if task[0]=="slide": note.path=[{"offset":0.0,"lane":6.0},{"offset":.5,"lane":8.0}]
            w.make_cap(group,6,0,w.palette_for_kind(task[0]))
            w.make_ribbon(group,note,w.palette_for_kind(task[0]))
        # Never yield while a temporary appearance is installed.
        game.note_shape=shape; game.trail_style=style
        if not await draw_frames(token): return
        variants_drawn+=1; progress=.52+.18*float(variants_drawn)/tasks.size()
        discard(group)
    status="WARMING HIT EFFECTS"
    for family in ["0normal","1normal","0flick0","0flick1","0flick2","0flick3"]:
        if not valid(token): return
        var kind="hold" if family=="1normal" else ("flick" if family.begins_with("0flick") else "tap")
        var direction=int(family.trim_prefix("0flick")) if kind=="flick" else 0
        w.prewarming_hits=true; w.spawn_hit(w.CENTER_LANE,kind,direction); w.prewarming_hits=false
        w.animate_effects(.09)
        if not await draw_frames(token): return
        for hit in w.bursts: w.recycle_hit(hit)
        w.bursts.clear()
        variants_drawn+=1
    w.spawn_bloom(w.CENTER_LANE,"tap",{},-999); w.animate_blooms(.1,true)
    w.multiplier_wave(); w.update_multiplier_wave(.1)
    for beam in w.finger_beams+w.active_beams: beam.visible=true
    if not await draw_frames(token): return
    for bloom in w.blooms: bloom.node.hide(); w.bloom_pool.append(bloom)
    w.blooms.clear(); w.gold_age=-1; w.gold_wave.hide(); w.gold_bar.hide(); w.flare=0
    for beam in w.finger_beams+w.active_beams: beam.visible=false
    progress=.74; status="PREPARING CHART GRAPHICS"
    var entries=w.notes.values()
    index=0
    while index<entries.size():
        while index<entries.size() and uploading.size()<UPLOAD_BATCH:
            var node: Node3D=entries[index].node
            uploading.append([node,node.transform])
            # Bring the head into the frustum so meshes/materials are actually submitted.
            var head=node.get_child(0) as Node3D
            node.position=Vector3(-head.position.x,0,-24); node.visible=true
            index+=1
        if not await draw_frames(token): return
        for entry in uploading: entry[0].transform=entry[1]; entry[0].visible=false
        uploading.clear(); uploaded_notes=index
        progress=.74+.10*float(index)/maxi(1,entries.size())
    # Submit every prepared effect instance too, including its unique MultiMesh buffer.
    status="PREPARING EFFECT GRAPHICS"
    var inventory: Array=w.hit_pool+w.bloom_pool
    index=0
    while index<inventory.size():
        var batch: Array=[]
        for i in mini(8,inventory.size()-index):
            var effect: Dictionary=inventory[index]; index+=1
            var node: Node3D=effect.node
            uploading.append([node,node.transform]); batch.append(effect)
            node.position=w.touch_hit_position(w.CENTER_LANE,-999); node.visible=true
            if effect.has("particle_batch"):
                effect.flash.material_override.set_shader_parameter("opacity",.5)
                effect.fill.material_override.set_shader_parameter("opacity",.3)
                effect.ring.material_override.albedo_color.a=.4
                var instances: MultiMesh=effect.particle_batch.multimesh
                instances.visible_instance_count=instances.instance_count
                for particle_index in effect.particles.size():
                    var particle=effect.particles[particle_index]
                    instances.set_instance_transform(particle_index,Transform3D(particle.basis.scaled(Vector3.ONE*.5),particle.velocity*.1))
            else:
                for material in [effect.flat,effect.sparks]:
                    material.set_shader_parameter("age",.2); material.set_shader_parameter("strength",1.0)
        if not await draw_frames(token): return
        for entry in uploading: entry[0].transform=entry[1]; entry[0].visible=false
        uploading.clear()
        for effect in batch:
            if effect.has("particle_batch"): effect.particle_batch.multimesh.visible_instance_count=0
        uploaded_effects=index
        progress=.84+.04*float(index)/maxi(1,inventory.size())
    status="PREPARING SCORE AND COMBO"
    var hud=game.create_hud_warmup(); temporary.append(hud)
    var widgets=hud.get_children()
    index=0
    while index<widgets.size():
        var batch: Array=[]
        for i in mini(4,widgets.size()-index):
            widgets[index].visible=true; batch.append(widgets[index]); index+=1
        if not await draw_frames(token): return
        for widget in batch: widget.visible=false
        progress=.88+.06*float(index)/widgets.size()
    discard(hud)
    progress=.94; status="FINALIZING STAGE"
    # Flush temporary deletion and allow several clean rendered frames before countdown.
    if not await draw_frames(token,SETTLE_FRAMES): return
    w.animated_materials=w.animated_materials.filter(func(ref): return ref.get_ref()!=null)
    status="CHECKING FRAME STABILITY"
    # A slow device must still start: allow a brief observation window, not an FPS gate.
    var deadline=Time.get_ticks_usec()+750000
    var target=1000.0/maxi(1,Engine.max_fps if Engine.max_fps>0 else game.display_refresh_rate())
    var quiet=0
    while Time.get_ticks_usec()<deadline:
        var before=Time.get_ticks_usec()
        if not await frame(token): return
        var elapsed=(Time.get_ticks_usec()-before)/1000.0
        frame_time_samples.append(elapsed)
        quiet=quiet+1 if elapsed<=target*1.5+1.0 else 0
        if quiet>=4: frame_stable=true; break
    progress=1.0; status="READY"; preparing=false
