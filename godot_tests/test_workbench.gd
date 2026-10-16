extends SceneTree
var failures=0
func check(value: bool,message: String) -> void:
    if not value: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false); game.set_mode("editor")
    var service=game.features
    game.document.load_notes([SynkChart.note(2,3),SynkChart.note(4,6,"flick")])
    game.document.dirty=true
    check(service.autosave()==OK and FileAccess.file_exists(service.draft_path()),"Draft autosave writes recoverable file")
    check(not FileAccess.file_exists(service.chart_path()),"Autosave does not publish a chart")
    game.document.load_notes([]); service.recovery_checked=""
    check(service.recover() and game.document.notes.size()==2 and game.document.dirty,"Recovery restores draft")
    service.choose_variant(1)
    check(service.current_variant=="easy" and game.document.notes.is_empty(),"Difficulties have independent notes")
    game.document.add(6,1); game.save_editor()
    check(FileAccess.file_exists(service.chart_path()) and not FileAccess.file_exists(service.draft_path()),"Saving publishes only current variant")
    service.choose_variant(0)
    check(game.document.notes.size()==2,"Switching back recovers original draft")
    var path="user://sharing_fixture.json"
    check(service.export_chart(path)==OK,"Chart export succeeds")
    var data=JSON.parse_string(FileAccess.get_file_as_string(path))
    check(data.song_id=="eclipse" and data.notes.size()==2 and not data.has("audio"),"Share file identifies song and excludes audio")
    game.document.load_notes([])
    check(service.import_chart(path)==OK and game.document.notes.size()==2,"Exported chart round-trips")
    game.document.undo(); check(game.document.notes.is_empty(),"Import is undoable")
    data.song_id="wrong-song"
    SynkLibrary.atomic_write(path,data)
    check(service.import_chart(path)==ERR_INVALID_DATA and game.document.notes.is_empty(),"Wrong-song import rejected atomically")
    data.song_id="eclipse"; data.notes[0].time=9999
    SynkLibrary.atomic_write(path,data)
    check(service.import_chart(path)==ERR_INVALID_DATA and game.document.notes.is_empty(),"Out-of-song notes rejected")
    game.features.open_tools("Sharing")
    await create_timer(.25).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/workbench-sharing.png")
    game.features.close_tools()
    game.document.add(3,2); game.close_editor()
    check(game.mode=="library" and FileAccess.file_exists(service.draft_path()),"Leaving editor keeps an unpublished draft")
    print("Drafts, versions and chart sharing: ","PASS" if failures==0 else "%d FAILED" % failures)
    game.queue_free(); await process_frame
    quit(0 if failures==0 else 1)
