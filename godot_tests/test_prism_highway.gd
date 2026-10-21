extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.field.world.set_process(false)
    var w=g.field.world
    check(g.settings_panel.style_tiles.size()==3 and g.settings_panel.style_tiles.has("prism"),"Prism is the third selectable style")
    for style in ["prism","gold","neon","prism"]:
        g.highway_style=style; w.refresh_highway_look()
        check(w.prism_theme.visible==(style=="prism"),"Prism visibility follows selection")
        check(w.gold_nodes.all(func(n): return n.visible==(style=="gold")),"Gold rails switch independently")
        check(w.neon_nodes.all(func(n): return n.visible==(style=="neon")),"Neon rails switch independently")
    g.highway_colors="theme"; g.rail_color=""; g.gameplay_colors={}; w.refresh_highway_look()
    var base=w.prism_theme.floor_material.get_shader_parameter("color_a")
    g.highway_colors="adaptive"
    w.apply_palette({"notes":[Color("ff7020"),Color("20ff80"),Color("b020ff")],"from_cover":true,"stage":Color("201030")})
    var adapted=w.prism_theme.floor_material.get_shader_parameter("color_a")
    check(base!=adapted and adapted.is_equal_approx(Color("ff7020")),"Adaptive Prism follows song palette")
    check(w.find_children("*","CPUParticles3D",true,false).is_empty(),"Prism adds no ambient particle emitters")
    check(w.prism_theme.get_child_count()==1,"Prism displays the supplied image with one projected mesh")
    check(w.prism_theme.floor_material.get_shader_parameter("artwork").resource_path=="res://assets/neon/Prism_Stage.png","Prism uses the supplied artwork")
    g.queue_free(); await process_frame
    print("Prism theme switching and adaptive colors: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
