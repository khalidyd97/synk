extends SceneTree
var failures=0
func check(condition: bool, message: String) -> void:
    if not condition: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func wait_for_song(game: Control) -> void:
    for i in 200:
        game.poll_song_worker()
        if game.loading_song_index<0 and game.worker_song_id.is_empty(): return
        await process_frame
    check(false,"Song loader timed out")
func run():
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.stage_intro_enabled=false
    var lobby=game.lobby
    lobby.show_play_browser()
    lobby.preview_player.volume_db=-80
    game.demo_stream.save_to_wav("user://songs/carousel_fixture.wav")
    game.library.songs=[]
    var names=["Midnight Drive","Neon Skyline","Afterglow","Satellite"]
    var colors=[Color("38baff"),Color("f84bbd"),Color("ffad55"),Color("73f2c8")]
    for i in names.size():
        var id=str(i+1).repeat(64)
        game.library.songs.append({"id":id,"title":names[i],"bpm":120+i*8,"file":"carousel_fixture.wav"})
        game.song_metadata[id]={"duration":96.0,"waveform":game.waveform,"notes":[],"has_chart":false,"note_count":0}
        var image=Image.create(64,64,false,Image.FORMAT_RGBA8); image.fill(colors[i])
        game.song_cover_textures[id]=ImageTexture.create_from_image(image)
    lobby.refresh()
    check(lobby.filtered_entries.size()==5,"All songs populate carousel")
    lobby.carousel.step(1)
    await wait_for_song(game)
    check(game.song.title=="Midnight Drive","Carousel next selects and loads song")
    check(lobby.carousel.current==1,"Selection stays aligned after async load")
    lobby.carousel.begin_drag(Vector2(350,100))
    lobby.carousel.finish_drag(Vector2(150,100))
    await wait_for_song(game)
    check(game.song.title=="Neon Skyline","Left swipe selects next song")
    lobby.search.text="SATELLITE"
    lobby.search.text_changed.emit(lobby.search.text)
    await wait_for_song(game)
    check(lobby.filtered_entries.size()==1 and game.song.title=="Satellite","Search matches case-insensitively and selects matching track")
    lobby.search.text="no matching song"
    lobby.search.text_changed.emit(lobby.search.text)
    check(lobby.filtered_entries.is_empty() and lobby.empty_label.visible,"Empty search shows helpful state")
    check(not lobby.play_button.visible and not lobby.create_chart_button.visible,"Empty search hides play actions")
    lobby.search.text=""
    lobby.search.text_changed.emit(lobby.search.text)
    lobby.toggle_favorite()
    lobby.set_filter("favorites")
    check(lobby.filtered_entries.size()==1,"Favorites filter shows starred track")
    lobby.toggle_favorite()
    check(lobby.filtered_entries.is_empty(),"Removing the last favorite shows empty state")
    lobby.set_filter("all")
    lobby.toggle_grid()
    check(lobby.track_scroll.visible and not lobby.carousel.visible,"Grid switches from carousel")
    lobby.select_grid_track(0)
    await wait_for_song(game)
    check(not lobby.grid_mode and game.song.id=="eclipse","Grid selection returns to carousel")
    lobby.begin_preview()
    check(lobby.preview_player.playing and lobby.preview_player.stream==game.audio.stream,"Preview uses actual stream and waveform")
    game.set_mode("editor")
    check(not lobby.preview_player.playing,"Preview stops when leaving lobby")
    game.set_mode("menu")
    lobby.show_play_browser()
    lobby.press_auto()
    lobby.press_play()
    check(game.auto_play,"Autoplay toggle applies to carousel Play action")
    game.set_mode("menu")
    lobby.show_play_browser()
    lobby.refresh()
    for i in 35: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/carousel-library-preview.png")
    lobby.toggle_grid()
    for i in 4: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/carousel-grid-preview.png")
    print("Carousel integration: ","PASS" if failures==0 else "%d FAILED" % failures)
    quit(0 if failures==0 else 1)
