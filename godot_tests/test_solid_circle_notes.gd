extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func frame(g):
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return g.field.viewport.get_texture().get_image()
func run():
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    g.start_game([SynkChart.note(20,4)],false); g.countdown=0; g.song_time=10
    var w=g.field.world; w.set_process(false)
    for child in w.get_children():
        if child is WorldEnvironment:
            child.environment.background_mode=Environment.BG_COLOR; child.environment.background_color=Color.BLACK
        elif child is Node3D and child!=w.camera: child.hide()
    w.cover_backdrop.hide()
    var group=Node3D.new(); w.add_child(group)
    w.make_circle_cap(group,Vector3(0,0,-4),1,1)
    var head=group.get_child(0)
    var themed_shift=head.material_override.get_shader_parameter("hue_shift")
    head.material_override.set_shader_parameter("hue_shift",0.0)
    var original=await frame(g)
    head.material_override.set_shader_parameter("hue_shift",.24)
    var themed=await frame(g)
    for uv in [Vector2(.12,.55),Vector2(.25,.72),Vector2(.5,.85),Vector2(.5,.5)]:
        var point=head.to_global(Vector3((uv.x-.5)*head.mesh.size.x,(.5-uv.y)*head.mesh.size.y,0))
        var pixel=Vector2i(w.camera.unproject_position(point))
        var a=original.get_pixelv(pixel); var b=themed.get_pixelv(pixel)
        check(absf(a.v-b.v)<.04 and absf(a.s-b.s)<.04,"Theme preserves the artwork's local shading and saturation")
    head.material_override.set_shader_parameter("hue_shift",themed_shift)
    var before=await frame(g)
    var plane=PlaneMesh.new(); plane.size=Vector2(2,7)
    var material=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
    material.albedo_color=Color(0,1,0,1); material.render_priority=2
    var trail=MeshInstance3D.new(); trail.mesh=plane; trail.material_override=material
    group.add_child(trail); trail.position=Vector3(0,.1,-4)
    var after=await frame(g)
    for x in [-.5,0.0,.5]:
        var sample=w.camera.unproject_position(Vector3(x,.38,-4))
        var a=before.get_pixelv(Vector2i(sample)); var b=after.get_pixelv(Vector2i(sample))
        check(Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))<.03,"Supplied note artwork occludes the bright trail behind its filled center")
    var visible=w.camera.unproject_position(Vector3(0,.1,-1))
    check(after.get_pixelv(Vector2i(visible)).g>.6,"Occlusion fixture trail remains visible outside the note")
    check(group.get_child(0).material_override.get_shader_parameter("artwork").resource_path.ends_with("Circle_Note_Reference.png"),"Circle heads use the supplied artwork")
    after.save_png("res://.tools/solid-note-occlusion.png")
    g.queue_free(); await process_frame
    print("Solid circle note occlusion: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
