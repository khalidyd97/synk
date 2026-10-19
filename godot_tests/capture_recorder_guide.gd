extends SceneTree
# Documentation fixture: isolated user data, real game widgets and viewport captures.
var game: Control
const OUT="res://docs/recorder/images/"
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
    await create_timer(.48).timeout
    await RenderingServer.frame_post_draw
    var error=root.get_texture().get_image().save_png(OUT+name+".png")
    if error!=OK: push_error("Screenshot failed: "+name); quit(1)
    print("Captured ",name)
func scroll_bottom(root_control: Node) -> void:
    for node in root_control.get_children():
        if node is ScrollContainer: node.scroll_vertical=100000
        scroll_bottom(node)
func hold(at: float,lane: int,duration: float) -> Dictionary:
    var n=SynkChart.note(at,lane,"hold"); n.duration=duration; return n
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
    await process_frame
    game.set_process(false); game.recorder.set_process(false); game.stage_intro_enabled=false
    await shot("01-lobby")
    game.open_editor(); await shot("02-chart-library")
    game.open_chart(0)
    game.document.load_notes([SynkChart.note(6,2),SynkChart.note(8,1),hold(10,4,1),SynkChart.note(14,7)],{"bpm":120.0,"beat_offset":0.0})
    game.refresh_editor(); game.seek_to(8); game.zoom_seconds=12; game.timeline.view_start=4
    await shot("03-chart-studio")
    game.features.open_tools("Grid"); await shot("05-chart-timing")
    game.features.close_tools(); game.studio.set_tool("range")
    game.timeline.range_active=true; game.timeline.range_start=8; game.timeline.range_end=16; game.timeline.update_range()
    game.refresh_editor(); await shot("06-select-range")
    var r=game.recorder
    r.use_range=true; r.loop_takes=true; r.pre_roll=1; r.quantize="soft"; r.division=4
    r.show_setup(); await shot("07-recording-setup")
    scroll_bottom(r.setup); await shot("08-passes-locks-guide")
    r.setup.queue_free(); r.setup=null
    game.record_here(); game.countdown=2; game.countdown_label.visible=true; game.countdown_label.text="2"; game.countdown_ring.visible=true
    await shot("09-countdown")
    game.countdown=0; game.countdown_label.visible=false; game.countdown_ring.visible=false; game.song_time=6
    game.record_info.text="PRE-ROLL · LISTEN\nREC AT 8.00 s"
    await shot("10-pre-roll")
    var slide=SynkChart.note(11,3,"slide"); slide.duration=1.5; slide.end_lane=6
    slide.path=[{"offset":0.0,"lane":3.0},{"offset":.6,"lane":4.0},{"offset":1.5,"lane":6.0}]
    var flick=SynkChart.note(14.5,7,"flick"); flick.direction=1
    game.capture.notes=[SynkChart.note(8.5,2),hold(9.5,5,.8),slide,flick]
    game.song_time=14.8; game.visual_song_time=14.8; game.record_info.text="● RECORDING  14.8 s\n4 NOTES / AUTO · TAKE 1"
    game.refresh_arrange_controls(); await shot("11-recording")
    game.toggle_arrange(); game.arrange_selection={"note":slide,"document":false,"index":2}; game.refresh_arrange_controls()
    await shot("12-correct-notes")
    game.arranging=false; game.arrange_button.text="CORRECT"; game.toggle_pause()
    await shot("13-recorder-pause")
    game.stop_take(); await shot("14-take-review")
    r.preview(); game.cursor=11.5; game.timeline.view_start=8
    await shot("15-take-replay")
    r.stop_preview()
    # A second controlled example attempt demonstrates comparison and splice controls.
    var second=game.capture.notes.duplicate(true); second[0].time=8.55; second[1].time=9.6
    second.append(SynkChart.note(15,4))
    r.takes.append({"notes":r.prepare(second),"raw":second.duplicate(true)})
    r.select_take(1); r.show_review(); await shot("16-compare-takes")
    scroll_bottom(r.review); await shot("17-combine-takes")
    r.keep(); game.studio.set_tool("select"); game.timeline.view_start=8
    game.save_editor(); await shot("18-save-chart")
    game.features.open_tools("Check"); await shot("19-validate-chart")
    game.features.close_tools(); game.set_mode("menu"); game.open_lobby_settings(); game.features.open_tools("Effects")
    await shot("20-note-appearance")
    game.features.close_tools(); game.queue_free(); await process_frame
    print("Recorder guide screenshots: COMPLETE"); quit()
