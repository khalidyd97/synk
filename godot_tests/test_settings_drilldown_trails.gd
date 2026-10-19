extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
    await create_timer(.35).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/drilldown-"+name+".png")
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var s=g.settings_panel; var original=g.document.notes.duplicate(true); var chart_settings=g.document.settings.duplicate(true)
    g.open_lobby_settings(); s.show_page("visuals",false); s.show_section("stage",false)
    check(s.pages.visuals.sections.size()==5,"Visuals has Highway, Notes, Hit effects, Stage effects, and Colors")
    check(s.stage_effect_switches["Soft fading glow"].is_visible_in_tree(),"Stage options are on their own visible tab")
    check(not s.sizing_inputs.note_size.is_visible_in_tree(),"Notes are separated from stage options")
    await shot("stage")
    s.show_section("notes"); await create_timer(.3).timeout
    check(s.selected_sections.visuals=="notes" and s.page_hint.text.ends_with("NOTES"),"Tab selection updates the breadcrumb")
    s.trail_style_input.item_selected.emit(1)
    check(g.trail_style=="solid" and s.trail_style_input.selected==1,"Solid ribbon option applies immediately")
    s.show_page("audio",false); s.show_section("headset",false); s.show_page("visuals",false)
    check(s.selected_sections.visuals=="notes","Category remembers its selected drill-down tab")
    await shot("notes")
    root.size=Vector2i(1024,600)
    for category in s.pages:
        s.show_page(category,false)
        for key in s.SUBPAGES[category]:
            s.show_section(key,false); await process_frame; await process_frame
            var active=s.pages[category].sections[key]
            check(active.list.get_combined_minimum_size().x<=active.scroll.size.x+1,"Drill-down rows fit compact layout: "+category+"/"+key)
            var visible_count=0
            for other in s.pages[category].sections.values():
                if other.root.visible: visible_count+=1
            check(visible_count==1,"Only the selected drill-down page is visible")
    s.show_page("visuals",false); s.show_section("stage",false); await shot("compact")
    check(g.document.notes==original and g.document.settings==chart_settings,"Settings never change chart data")
    g.close_lobby_settings()
    var w=g.field.world; w.set_process(false)
    var slide=SynkChart.note(4,3,"slide"); slide.duration=1.5; slide.end_lane=7
    slide.path=[{"offset":0.0,"lane":3.0},{"offset":.45,"lane":3.0},{"offset":.58,"lane":7.0},{"offset":1.5,"lane":7.0}]
    check(w.solid_trail_offsets(slide)==[1.5],"Slide bends do not invent connector points")
    slide.checkpoints=[.35,.95]
    var hold=SynkChart.note(4.8,1,"hold"); hold.duration=1.4; hold.checkpoints=[.7]
    check(w.solid_trail_offsets(hold)==[.7,1.4],"Holds use their explicitly added points and endpoint")
    g.start_game([slide,hold],false); g.audio.stop(); g.countdown=0; g.song_time=3.8; g.visual_song_time=3.8
    w.colors[1]=Color("ffd056")
    w._process(0)
    var node=w.notes.play0.node
    check(node.get_child(1).mesh.surface_get_material(0).shader.resource_path.ends_with("solid_trail.gdshader"),"Solid style uses a filled ribbon shader")
    var joints=[]
    for child in node.get_children():
        if child.has_meta("solid_trail_joint"): joints.append(child)
    check(joints.size()==3 and w.solid_trail_offsets(slide)==[.35,.95,1.5],"Only recorded points and the endpoint have connector discs")
    w.set_trail_clip(node,-3)
    for joint in joints: check(joint.material_override.get_shader_parameter("clip_z")==-3,"Round joints obey hold clipping")
    w.set_trail_clip(node,1000)
    var camera=w.camera.transform; var note_size=g.note_size
    await shot("solid-ribbon")
    w.fade_missed_slide("play0",.8)
    for joint in joints:
        check(joint.material_override.get_shader_parameter("desaturate")==1.0 and joint.material_override.get_shader_parameter("ghost_fade")<1,"Solid joints fade and gray with a missed note")
    g.set_mode("record"); g.arranging=true; g.song_time=5.1
    var joint_offset=.95; var radius=w.TRAIL_HALF*.65*g.hold_trail_width*1.5
    var joint_edge=Vector3(w.lane_x(SynkChart.lane_at(slide,slide.time+joint_offset))+radius*.9,w.trail_height()+.015,(slide.time+joint_offset-g.song_time)*w.travel_speed())
    var touch=w.camera.unproject_position(joint_edge)/Vector2(g.field.viewport.size)
    check(g.arrange_note_distance(slide,touch)<.09,"Solid joint discs remain selectable across their full face")
    g.arranging=false; g.set_mode("play")
    g.change_trail_style("neon"); w._process(0)
    check(w.notes.play0.node.get_child(1).mesh.surface_get_material(0).shader.resource_path.ends_with("neon_asset.gdshader"),"Original neon trail remains available")
    check(w.camera.transform==camera and g.note_size==note_size,"Trail style preserves camera and note sizing")
    g.change_trail_style("solid"); var prefs=ConfigFile.new(); prefs.load("user://preferences.cfg")
    check(prefs.get_value("gameplay","trail_style","")=="solid","Trail style persists")
    g.queue_free(); await process_frame
    print("Settings drill-down and solid trails: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
