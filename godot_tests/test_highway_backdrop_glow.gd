extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func sample(image: Image,rect: Rect2) -> float:
    var total=0.0; var count=0
    for y in range(int(rect.position.y*image.get_height()),int(rect.end.y*image.get_height()),3):
        for x in range(int(rect.position.x*image.get_width()),int(rect.end.x*image.get_width()),3):
            var c=image.get_pixel(x,y); total+=c.r+c.g+c.b; count+=1
    return total/maxi(1,count)
func snapshot() -> Image:
    await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var w=g.field.world; w.set_process(false)
    g.set_mode("play"); g.change_highway_look("colors","theme"); g.change_gameplay_color("glow","ee2288")
    var original_camera=w.camera.transform; var original_fov=w.camera.fov
    var texture=Image.create(32,32,false,Image.FORMAT_RGB8); texture.fill(Color("12121a"))
    w.set_cover(ImageTexture.create_from_image(texture),Color.WHITE)
    g.ui.visible=false
    w.ambient_motes.visible=false
    for motes in w.ambient_side_motes+w.ambient_streaks: motes.visible=false
    for size in [Vector2i(1280,720),Vector2i(1200,540)]:
        root.size=size; await process_frame; w.update_cover_backdrop()
        g.change_rail_glow_opacity(0); var before=await snapshot()
        g.change_rail_glow_opacity(.2); var after=await snapshot()
        var top=sample(after,Rect2(.025,.025,.2,.18))-sample(before,Rect2(.025,.025,.2,.18))
        var bottom=sample(after,Rect2(.025,.78,.2,.18))-sample(before,Rect2(.025,.78,.2,.18))
        var road=sample(after,Rect2(.45,.5,.1,.18))-sample(before,Rect2(.45,.5,.1,.18))
        check(top>.04,"Glow visibly illuminates the upper background")
        check(top>bottom*2,"Backdrop haze fades toward the bottom like the reference")
        check(top>road*2,"Highway stays dark beneath the glow")
        after.save_png("res://.tools/video-glow-preview-"+str(size.x)+".png")
    check(w.camera.transform==original_camera and w.camera.fov==original_fov,"Glow never changes highway geometry or camera")
    g.audio.play(); g.song_time=0; w.update_cover_backdrop()
    var peak=float(w.cover_material.get_shader_parameter("glow_beat"))
    g.song_time=30.0/g.chart_bpm(); w.update_cover_backdrop()
    check(peak>float(w.cover_material.get_shader_parameter("glow_beat")),"Glow swells smoothly with the beat")
    g.paused_mode="play"; g.set_mode("paused"); var held=w.cover_material.get_shader_parameter("glow_beat")
    g.song_time+=1; w.update_cover_backdrop()
    check(w.cover_material.get_shader_parameter("glow_beat")==held,"Paused glow remains still")
    g.audio.stop(); g.set_mode("record"); g.apply_stage_cover()
    check(is_zero_approx(w.cover_material.get_shader_parameter("rail_glow_opacity")),"Recorder remains unchanged")
    print("Highway backdrop glow: "+("PASS" if failures==0 else "FAIL"))
    g.queue_free(); await process_frame; quit(failures)
