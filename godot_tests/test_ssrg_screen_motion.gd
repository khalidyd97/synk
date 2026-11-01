extends SceneTree
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1564,720)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.set_process(false);game.app_login.hide()
 game.prefs.set_value("ssrg","preview",false)
 for child in game.get_children():
  if child is CanvasLayer and child.layer>=90:child.hide()
 for i in 4:
  game.library.songs.append({"id":"motion_fixture_%d" % i,"title":["Eclipse","Moonlight","Starfall","Afterglow"][i],"artist":"Motion review","album":"SSRG","ssrg":[4,7,13],"length":160.0,"ssrg_charts":[{"keys":4,"variant":"lv4","notes":120,"density":2.0},{"keys":7,"variant":"lv7","notes":240,"density":4.0},{"keys":13,"variant":"lv13","notes":420,"density":7.0}]})
 game.open_ssrg_playables()
 var browser=game.ssrg_playables
 await create_timer(.45).timeout
 var row=browser.rows[browser.selected_id].row
 var start=row.scale
 browser.style_row(row,false)
 assert(row.scale==start,"Selection changes without snapping")
 await create_timer(.10).timeout
 assert(row.scale.x<start.x and row.scale.x>.96,"Selection interpolates")
 browser.select_song("motion_fixture_1")
 browser.select_song("motion_fixture_2")
 var art1=GradientTexture2D.new();var art2=GradientTexture2D.new()
 browser.change_backdrop(art1)
 await create_timer(.08).timeout
 var layer=browser.backdrop;var opacity=layer.modulate.a
 browser.change_backdrop(art2)
 assert(layer.modulate.a==opacity,"Interrupted artwork fades preserve current opacity")
 await create_timer(.5).timeout
 assert(browser.backdrop_layers.size()==1,"Obsolete backdrop layers are released")
 assert(is_equal_approx(browser.backdrop.modulate.a,.32),"Artwork settles to its normal brightness")
 assert(browser.selected_id=="motion_fixture_2" and browser.detail.get_child_count()<15,"Rapid selection keeps the latest controls only")
 browser.change_backdrop(game.cover_texture_for_id("eclipse"))
 await create_timer(.5).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/ssrg-motion-review/song-select.png")
 browser.close()
 game.ssrg_playable_run=true;game.mode="results"
 game.ssrg_screens.show_results({"ssrg":true,"title":"Eclipse","score":1234567,"accuracy":98.4,"rank":"S","max_combo":321,"cover":game.cover_texture_for_id("eclipse")})
 await create_timer(.5).timeout
 assert(is_equal_approx(game.ssrg_screens.result_score.modulate.a,1.0),"Results entrance settles without a residual fade")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/ssrg-motion-review/results.png")
 game.queue_free();await process_frame
 print("SSRG motion, rapid selection, backdrop cleanup and results: PASS")
 quit()
