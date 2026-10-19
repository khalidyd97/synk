extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var id="test_song_details_"+str(Time.get_ticks_usec())
    # Fallback chain: background, then album art, then plain black.
    check(g.stage_backdrop_for_id(id)==null,"A song with no artwork has a plain black stage")
    check(g.stage_backdrop_for_id("eclipse")==g.cover_texture_for_id("eclipse"),"Without a background the stage uses the album art")
    var wide=Image.create(320,180,false,Image.FORMAT_RGBA8); wide.fill(Color.RED)
    check(g.save_background_image(id,wide)=="","Gameplay background saves")
    var backdrop: Texture2D=g.stage_backdrop_for_id(id)
    check(backdrop!=null and backdrop.get_width()==320 and backdrop.get_height()==180,"The background wins and keeps its shape")
    g.remove_background(id)
    check(not g.has_background(id) and g.stage_backdrop_for_id(id)==null,"Removing the background falls back again")
    var big=Image.create(4000,1000,false,Image.FORMAT_RGBA8)
    g.save_background_image(id,big)
    check(g.background_texture_for_id(id).get_width()==1920,"Large backgrounds are scaled to 1920 px")
    g.remove_background(id)
    # Black stage in the shader.
    g.field.world.set_cover(null,Color.WHITE)
    check(g.field.world.cover_backdrop.visible and g.field.world.cover_material.get_shader_parameter("plain"),"No artwork draws a black backdrop")
    g.field.world.set_cover(g.cover_texture_for_id("eclipse"),Color.WHITE)
    check(not g.field.world.cover_material.get_shader_parameter("plain"),"Artwork turns the black backdrop off")
    # The details screen opens from the menu and stages edits until SAVE.
    g.open_song_details("eclipse")
    check(not g.song_details.visible,"The Play song browser has no song details")
    check(not g.lobby.browser.panel.find_children("*","Button",true,false).any(func(b): return "DETAILS" in b.text),"No DETAILS button in the Play browser")
    g.set_mode("library"); g.chart_library.select_entry("eclipse")
    check(g.chart_library.panel.find_children("*","Button",true,false).any(func(b): return "DETAILS" in b.text),"Chart Studio song list has a DETAILS button")
    g.open_song_details("eclipse")
    check(g.song_details.visible and not g.chart_library.visible,"Song details opens from the Chart Studio song list")
    check(g.song_details.fields.title.text==str(g.eclipse_song().title),"Details screen shows the current title")
    g.song_details.fields.track.text="12a"; g.song_details.fields.track.text_changed.emit("12a")
    check(g.song_details.fields.track.text=="12","Track number accepts digits only")
    g.song_details.pending_background=wide; g.song_details.refresh_previews()
    check(not g.has_background("eclipse"),"Picked images are not saved before SAVE")
    g.song_details.cancel()
    check(not g.song_details.visible and g.chart_library.visible,"Cancel returns to the Chart Studio song list")
    var studio_row=g.chart_library.chart_cards.filter(func(r): return r.entry.id=="eclipse")[0]
    var play_entry=g.lobby.all_entries().filter(func(e): return e.id=="eclipse")[0]
    check(studio_row.entry.title==play_entry.title and studio_row.entry.artist==play_entry.artist,"Play and Chart Studio show the same song details")
    var raw_id=g.library.songs[0].id if not g.library.songs.is_empty() else ""
    if raw_id!="":
        var original_title=str(g.library.songs[0].title); g.library.songs[0].title="Band_-_Song_(mp3.pm)"
        g.open_song_details(raw_id)
        check(g.song_details.fields.title.text=="Band - Song","Title field is pre-filled with the cleaned-up title")
        g.song_details.cancel(); g.library.songs[0].title=original_title
    check(g.lobby.artist_line({"id":"x","artist":"Artist","album":"Album"})=="Artist  ·  Album","Browser shows artist and album")
    check(g.lobby.artist_line({"id":"x","artist":"","album":"Album"})=="Album","Empty artist falls back to the album")
    check(g.lobby.artist_line({"id":"x","artist":"Nova Kai","album":"Nova Kai"})=="Nova Kai","Matching artist and album show once")
    check(ThemeDB.fallback_font.resource_path.ends_with("FiraSans-Regular.ttf"),"The game font is Fira Sans")
    g.queue_free(); await process_frame
    print("Song details: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
