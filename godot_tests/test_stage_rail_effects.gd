extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
    await create_timer(.15).timeout; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/stage-rail-"+name+".png")
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var f=g.features; var w=g.field.world; var fx=w.rail_atmosphere
    check(f.effect("Flowing edge energy")==0 and f.effect("Soft fading glow")==0,"New stage effects are optional by default")
    var note=SynkChart.note(4.4,4,"hold"); note.duration=1.3
    g.start_game([SynkChart.note(4.1,1),note,SynkChart.note(4.8,7,"flick"),SynkChart.note(4.1,8)],false)
    g.countdown=0; g.audio.stop(); g.song_time=3.5; g.visual_song_time=3.5
    f.set_effect("Lasers",0); f.set_effect("Particles",0)
    w.set_process(false); w._process(0)
    var camera=w.camera.transform; var size=g.note_size; var width=g.hold_trail_width
    check(not fx.visible,"Both disabled hides the effect geometry")
    f.set_effect("Flowing edge energy",1); fx.update(.2)
    check(fx.visible and fx.energy_nodes[0].visible and not fx.glow_nodes[0].visible,"Energy can be enabled alone")
    check(not w.ambient_streaks[0].visible,"New effects do not re-enable lasers")
    fx.clock=1.7; fx.update(0); await shot("energy")
    f.set_effect("Flowing edge energy",0); f.set_effect("Soft fading glow",1); fx.update(.2)
    check(not fx.energy_nodes[0].visible and fx.glow_nodes[0].visible,"Glow can be enabled alone")
    await shot("glow")
    f.set_effect("Flowing edge energy",1); fx.update(.2)
    check(fx.energy_nodes[1].visible and fx.glow_nodes[1].visible,"Both options can be enabled together")
    await shot("both")
    for node in fx.energy_nodes+fx.glow_nodes:
        check(absf(node.position.x)-node.mesh.size.x*.5>w.FRAME_HALF_WIDTH,"Effect geometry stays outside note lanes")
    g.toggle_pause(); var previous=fx.clock; fx.update(.5)
    check(fx.clock==previous and fx.visible,"Pause keeps the effect visible and freezes motion")
    g.set_mode("menu"); fx.update(.5); check(not fx.visible,"Stage effects hide in menus")
    g.open_lobby_settings(); g.settings_panel.show_page("visuals",false); g.settings_panel.show_section("stage",false)
    var switches=g.settings_panel.stage_effect_switches
    await process_frame; await process_frame
    g.settings_panel.pages.visuals.scroll.ensure_control_visible(switches["Flowing edge energy"])
    await shot("settings")
    switches["Flowing edge energy"].button_pressed=false; fx.update(0)
    check(f.effect("Flowing edge energy")==0 and f.effect("Soft fading glow")==1,"Settings switches work independently")
    var prefs=ConfigFile.new(); prefs.load("user://preferences.cfg")
    check(prefs.get_value("effects","Soft fading glow",0)==1,"Stage option persists")
    check(w.camera.transform==camera and g.note_size==size and g.hold_trail_width==width,"Stage options preserve camera and note geometry")
    w.cover_palette_active=true
    w.colors=[Color("31cfe3"),Color("de41d5"),Color("afff44")]
    g.set_mode("play"); fx.update(0)
    check(fx.glow_materials[1].get_shader_parameter("tint")==w.colors[1],"Atmosphere follows the active palette")
    g.queue_free(); await process_frame
    print("Stage rail options: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
