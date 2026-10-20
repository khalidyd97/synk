extends SceneTree
var failures=0
func check(value: bool,message: String) -> void:
    if not value: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game); await process_frame
    game.set_process(false); game.stage_intro_enabled=false
    var features=game.features
    for key in features.EFFECT_NAMES: features.set_effect(key,1)
    game.start_game([SynkChart.note(2,4)])
    var world=game.field.world
    world.spawn_hit(4,"tap"); world.animate_effects(.08)
    var burst=world.bursts[-1]
    check(float(burst.flash.material_override.get_shader_parameter("opacity"))>0,"Default hit effect is visible")
    features.set_effect("Hit flashes",0); world.animate_effects(.01)
    check(is_zero_approx(float(burst.flash.material_override.get_shader_parameter("opacity"))) and is_zero_approx(float(burst.fill.material_override.get_shader_parameter("opacity"))),"Zero hit intensity hides flash and fill")
    check(is_zero_approx(burst.ring.material_override.albedo_color.a),"Hit intensity also controls impact ring")
    features.set_effect("Particles",0); world.animate_effects(.01); world.update_ambient_particles(0)
    for particle in burst.particles: check(not particle.node.visible,"Particles can be turned off")
    check(not world.ambient_motes.visible,"Ambient particles can be turned off")
    features.set_effect("Lasers",0); world.update_ambient_particles(0)
    for stream in world.ambient_streaks: check(not stream.visible,"Laser streams can be turned off independently")
    features.set_effect("Background brightness",.35); world.update_ambient_particles(0)
    check(is_equal_approx(float(world.cover_material.get_shader_parameter("brightness")),.35),"Background brightness reaches shader")
    features.set_effect("Hit flashes",.5); features.set_effect("Particles",.5); features.set_effect("Lasers",.5)
    world.animate_effects(.01); world.update_ambient_particles(0)
    var visible_count=0
    for particle in burst.particles:
        if particle.node.visible: visible_count+=1
    check(visible_count==burst.particles.size()/2,"Particle density follows intensity")
    check(world.ambient_streaks[0].visible,"Restoring laser intensity shows streams again")
    var prefs=ConfigFile.new(); prefs.load("user://preferences.cfg")
    check(is_equal_approx(float(prefs.get_value("effects","Background brightness")),.35),"Intensity persists in preferences")
    game.set_mode("menu"); game.open_lobby_settings(); features.open_tools("Effects")
    check(features.tabs.current_tab==3,"Settings opens Effects tab")
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/effects-settings.png")
    for key in features.EFFECT_NAMES: features.effect_sliders[key].value=1
    check(features.effect("Particles")==1 and features.effect("Background brightness")==1,"Reset controls restore defaults")
    features.close_tools(); game.close_lobby_settings()
    print("Customizable effects integration: ","PASS" if failures==0 else "%d FAILED" % failures)
    game.queue_free(); await process_frame
    quit(0 if failures==0 else 1)
