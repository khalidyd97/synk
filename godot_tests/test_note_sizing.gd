extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func body_width(world: Node,parent: Node3D,n: Dictionary) -> float:
    world.make_ribbon(parent,n,1)
    var mesh=parent.get_child(0).mesh
    return mesh.get_aabb().size.x
func run() -> void:
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.field.world.set_process(false)
    var world=g.field.world
    var original=g.document.notes.duplicate(true); var settings=g.document.settings.duplicate(true)
    g.note_shape="rectangle"; g.change_note_sizing("note_size",1)
    var normal=Node3D.new(); world.add_child(normal); world.make_cap(normal,4,0,0)
    var original_width=normal.get_child(0).mesh.size.x
    g.change_note_sizing("note_size",.6)
    var small=Node3D.new(); world.add_child(small); world.make_cap(small,4,0,0)
    check(is_equal_approx(small.get_child(0).mesh.size.x/original_width,.6),"Note heads follow visual size preference")
    check(normal.get_child(0).position.x==small.get_child(0).position.x,"Sizing leaves lane centers unchanged")
    g.note_shape="circle"; g.change_note_sizing("note_size",1)
    var circle=Node3D.new(); world.add_child(circle); world.make_cap(circle,4,0,0)
    g.change_note_sizing("note_size",1.25)
    var large_circle=Node3D.new(); world.add_child(large_circle); world.make_cap(large_circle,4,0,0)
    check(is_equal_approx(large_circle.get_child(0).mesh.size.x/circle.get_child(0).mesh.size.x,1.25),"Circle heads scale consistently")
    var hold=SynkChart.note(4,4,"hold"); hold.duration=1
    g.change_note_sizing("hold_trail_width",1)
    var full=Node3D.new(); world.add_child(full); var full_width=body_width(world,full,hold)
    g.change_note_sizing("hold_trail_width",.3)
    var thin=Node3D.new(); world.add_child(thin); var thin_width=body_width(world,thin,hold)
    check(is_equal_approx(thin_width/full_width,.3),"Hold ribbon has independent width control")
    var slide=hold.duplicate(true); slide.kind="slide"
    var first=Node3D.new(); world.add_child(first); var slide_width=body_width(world,first,slide)
    g.change_note_sizing("hold_trail_width",1.5)
    var second=Node3D.new(); world.add_child(second)
    check(is_equal_approx(body_width(world,second,slide),slide_width),"Hold width does not change slides")
    check(g.document.notes==original and g.document.settings==settings,"Sizing never modifies chart data")
    var prefs=ConfigFile.new(); prefs.load("user://preferences.cfg")
    check(prefs.get_value("gameplay","note_size")==1.25 and prefs.get_value("gameplay","hold_trail_width")==1.5,"Visual preferences persist globally")
    g.set_mode("menu"); g.open_lobby_settings(); g.features.open_tools("Effects")
    var box=g.features.tabs.get_tab_control(3).get_child(0)
    var size_slider=box.get_node("NoteSize"); var width_slider=box.get_node("HoldTrailWidth")
    size_slider.value=.8; width_slider.value=.5
    check(is_equal_approx(g.note_size,.8) and is_equal_approx(g.hold_trail_width,.5),"Both Settings controls update their independent renderer properties")
    await create_timer(.5).timeout
    await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://.tools/note-size-settings.png")
    g.features.close_tools(); g.queue_free(); await process_frame
    print("Note sizing and trail widths: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
