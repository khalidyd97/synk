extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
    await create_timer(.8).timeout
    game.set_process(false)
    var movers: Array=[]
    for node in game.lobby.gateway.find_children("*","",true,false):
        if node.get_script() in [load("res://scripts/lobby_card.gd"),load("res://scripts/lobby_wordmark.gd")]:
            node.set_process(false); movers.append(node)
    DirAccess.make_dir_recursive_absolute("res://.tools/lobby-motion-frames")
    for i in 72:
        for node in movers: node._process(1.0/30.0)
        await process_frame
        await RenderingServer.frame_post_draw
        var frame=root.get_texture().get_image(); frame.resize(960,540,Image.INTERPOLATE_BILINEAR)
        frame.save_png("res://.tools/lobby-motion-frames/%03d.png" % i)
    game.queue_free(); await process_frame; print("Lobby motion preview: COMPLETE"); quit()
