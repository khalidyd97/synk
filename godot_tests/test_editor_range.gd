extends SceneTree
var failures=0
func check(value: bool,message: String) -> void:
    if not value: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func select_span(game: Control,a: float,b: float) -> void:
    game.studio.set_tool("range")
    var timeline=game.timeline
    timeline.reveal_time(a)
    var start=Vector2(timeline.lane_x(0),timeline.time_y(a))
    var end=Vector2(timeline.lane_x(8),timeline.time_y(b))
    timeline.begin(start); timeline.move_pointer(end); timeline.finish(end)
func touch(index: int,position: Vector2,pressed: bool) -> InputEventScreenTouch:
    var event=InputEventScreenTouch.new(); event.index=index; event.position=position; event.pressed=pressed; return event
func run():
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false); game.stage_intro_enabled=false
    game.document.settings.bpm=120.0; game.set_mode("editor"); game.zoom_seconds=8
    var tap=SynkChart.note(2,0)
    var hold=SynkChart.note(2.5,3,"hold"); hold.duration=.5; hold.checkpoints=[.25]
    var slide=SynkChart.note(3,1,"slide"); slide.duration=1.0; slide.end_lane=6
    slide.path=[{"offset":0.0,"lane":1.0},{"offset":.5,"lane":4.0},{"offset":1.0,"lane":6.0}]
    var flick=SynkChart.note(3.5,8,"flick"); flick.direction=3
    game.document.load_notes([tap,hold,slide,flick,SynkChart.note(4,9)])
    game.timeline.view_start=0
    select_span(game,2,4)
    check(game.timeline.range_indices.size()==4,"Range selects note starts across all lanes, excluding end boundary")
    check(game.studio.range_panel.visible and not game.studio.selected_actions.visible,"Range inspector replaces single-note controls")
    game.studio.duplicate_range()
    check(game.document.notes.size()==9,"Duplicates every selected note")
    check(is_equal_approx(game.document.notes[5].time,4.0),"Copy starts immediately after selected span")
    check(game.document.notes[6].checkpoints==[.25],"Hold checkpoints preserved")
    check(game.document.notes[7].path==slide.path and game.document.notes[7].end_lane==6,"Slide path and end lane preserved")
    check(game.document.notes[8].direction==3,"Flick direction preserved")
    game.document.notes[7].path[1].lane=5.0
    check(game.document.notes[2].path[1].lane==4.0,"Copied paths are independent")
    game.document.undo(); game.refresh_editor()
    check(game.document.notes.size()==5,"One undo reverses the whole duplication")
    game.document.redo(); game.refresh_editor()
    check(game.document.notes.size()==9,"One redo restores the whole duplication")
    select_span(game,2,4)
    game.cursor=10.0; game.studio.duplicate_range(true)
    check(game.document.notes.size()==13 and is_equal_approx(game.document.notes[9].time,10.0),"Paste anchors range to playhead")
    select_span(game,2,4)
    var count=game.document.notes.size(); var undo_count=game.document.undo_stack.size()
    game.cursor=game.length()-.1; game.studio.duplicate_range(true)
    check(game.document.notes.size()==count and game.document.undo_stack.size()==undo_count,"Out-of-bounds paste leaves chart and undo history unchanged")
    select_span(game,2,4)
    var start=game.timeline.range_start; var end=game.timeline.range_end
    game.timeline._gui_input(touch(0,Vector2(game.timeline.lane_x(0),game.timeline.time_y(1)),true))
    game.timeline._gui_input(touch(1,Vector2(game.timeline.lane_x(8),game.timeline.time_y(1)),true))
    game.timeline._gui_input(touch(1,Vector2.ZERO,false)); game.timeline._gui_input(touch(0,Vector2.ZERO,false))
    check(is_equal_approx(start,game.timeline.range_start) and is_equal_approx(end,game.timeline.range_end),"Two-finger navigation preserves range selection")
    game.studio.delete_selection()
    check(game.document.notes.size()==count-4,"Delete acts on range selection")
    game.document.undo(); game.refresh_editor()
    check(game.document.notes.size()==count,"Range delete is undoable")
    check(SynkChart.valid(game.document.notes),"Range copies remain valid chart data")
    game.timeline.view_start=0; game.cursor=2.0; game.refresh_editor()
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/vertical-range-preview.png")
    print("Range selection integration: ","PASS" if failures==0 else "%d FAILED" % failures)
    quit(0 if failures==0 else 1)
