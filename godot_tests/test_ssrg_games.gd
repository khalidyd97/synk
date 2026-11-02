extends SceneTree
const F=preload("res://godot_tests/ssrg_import_fixtures.gd")
const TX=preload("res://scripts/ssrg_import_transaction.gd")
const JOB=preload("res://scripts/ssrg_import_job.gd")
const CATALOG=preload("res://scripts/ssrg_game_catalog.gd")
var failures=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1564,720);AudioServer.set_bus_mute(0,true)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.set_process(false);game.app_login.hide()
 for child in game.get_children():
  if child is CanvasLayer and child.layer>=90:child.hide()
 game.library.songs=[];game.prefs.set_value("ssrg_games","custom",[]);game.prefs.set_value("ssrg","preview",false)
 game.open_ssrg_playables();var screen=game.ssrg_playables
 check(screen.games_page.visible and not screen.song_page.visible,"SSRG opens on Games")
 check(CATALOG.entries(game).is_empty(),"No hardcoded games appear in an empty library")
 for key in ["YG","STAYC"]:
  game.library.songs.append({"id":key.sha256_text(),"title":key+" track","file":"none.wav","album":key,"ssrg":[],"ssrg_charts":[{"keys":7,"variant":"7k","notes":1,"density":1,"length":60}]})
 screen.games_page.refresh()
 check(CATALOG.entries(game).size()==2 and screen.games_page.list.get_child_count()==2,"Imported games populate the list dynamically")
 screen.open_game("YG")
 for i in 5:await process_frame
 check(screen.selected_game=="SSYG" and screen.shown_songs().size()==1,"Selecting a game shows only its songs")
 screen.open_import();check(screen.import_wizard.target_game=="SSYG" and screen.import_wizard.job.target_game=="SSYG","Import is locked to the selected game")
 screen.import_wizard.hide();screen.show_games();screen.games_page.name_input.text="My Rhythm Game";screen.games_page.add_game()
 check(screen.selected_game=="MY RHYTHM GAME" and screen.shown_songs().is_empty(),"Custom games can be added before importing songs")
 var config=ConfigFile.new();config.load("user://preferences.cfg")
 check("My Rhythm Game" in config.get_value("ssrg_games","custom",[]),"Custom games persist")
 screen.show_games()
 var image=Image.create(64,64,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL);image.save_png("user://game-icon.png")
 screen.games_page.icon_game="MY RHYTHM GAME";screen.games_page.save_icon("user://game-icon.png")
 check(FileAccess.file_exists(CATALOG.icon_path("MY RHYTHM GAME")),"Custom game icons persist")
 var folder=F.folder("ssrg-game-mapping");var source=F.source(folder.path_join("source"));var store=folder.path_join("library");var library=SynkLibrary.new(store)
 var job=JOB.new();job.root=store;job.target_game="SSYG";job.scan(PackedStringArray([source.audio,source.chart]),[])
 for i in 600:
  job.poll()
  if not job.busy():break
  await process_frame
 check(job.plan.size()==1 and job.plan[0].game=="SSYG" and job.plan[0].target_game=="SSYG","Scanner assigns files to selected game instead of source folder")
 var item=job.plan[0];var prepared=TX.prepare(store,item,[]);var saved=TX.commit(store,prepared,[])
 check(saved.has("songs") and saved.songs[0].ssrg_game=="SSYG","Game assignment commits with the imported song")
 var songs=saved.songs;var first_id=str(songs[0].id);songs[0].album="Recognized album"
 check(CATALOG.category(songs[0])=="SSYG","Album recognition cannot change game membership")
 item=item.duplicate(true);item.target_game="SSSTAYC";item.game="SSSTAYC"
 var second=TX.commit(store,TX.prepare(store,item,songs),songs)
 check(second.has("songs") and second.songs.size()==2 and str(second.id)!=first_id,"Identical audio imported into another game remains separate")
 check(FileAccess.file_exists(store.path_join("charts/"+first_id+"_lv4.json")),"Other game's chart remains intact")
 check(TX.prepare(store,item,second.songs).get("skipped",false),"Reimport within one game preserves existing charts")
 job.shutdown();screen.show_games();await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.tools/ssrg-games/games.png")
 game.queue_free();await process_frame
 print("Dynamic SSRG games and import mapping failures: ",failures);quit(failures)
