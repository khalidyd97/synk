extends SceneTree
const SHEET=preload("res://scripts/color_picker_sheet.gd")
var failures=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1564,720);AudioServer.set_bus_mute(0,true)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.set_process(false);game.app_login.hide()
 for child in game.get_children():
  if child is CanvasLayer and child.layer>=90:child.hide()
 game.open_lobby_settings();var settings=game.settings_panel
 game.change_highway_look("style","aurora");game.change_highway_look("colors","theme")
 check(settings.look_color_pickers.size()==3,"Highway and hit tabs all expose the shared full picker")
 game.change_highway_look("rail_color","a46bff");game.change_gameplay_color("rail","112233")
 var path="user://preferences.cfg";var before_hash=FileAccess.get_sha256(path)
 var sheet=settings.open_look_color_picker("rail_color","Rail color",settings.look_color_pickers.rail_color.color)
 check("112233" in sheet.recent_codes and "a46bff" in sheet.recent_codes,"Existing applied colors are available for reuse")
 sheet.set_color(Color("c8547a"))
 check(game.rail_color=="c8547a" and not game.gameplay_colors.has("rail"),"Live preview takes precedence over an older element override")
 check(FileAccess.get_sha256(path)==before_hash,"Dragging the picker never writes preferences")
 sheet.close(false);await create_timer(.2).timeout
 check(game.rail_color=="a46bff" and game.gameplay_colors.get("rail")=="112233","Cancel restores both the old global color and its element override")
 check(not "c8547a" in game.prefs.get_value("colors","recent",[]),"Cancelled colors never enter history")
 sheet=settings.open_look_color_picker("rail_color","Rail color",settings.look_color_pickers.rail_color.color)
 sheet.set_color(Color("c8547a"));sheet.close(true);await create_timer(.2).timeout
 check(game.rail_color=="c8547a" and not game.gameplay_colors.has("rail"),"Done saves the chosen rail color through the existing setting")
 var saved=ConfigFile.new();saved.load(path)
 check(saved.get_value("colors","recent",[])[0]=="c8547a","Recent colors persist on disk")
 var count=game.prefs.get_value("colors","recent",[]).size()
 settings.show_page("visuals",false);settings.show_section("hits",false)
 sheet=settings.open_look_color_picker("hit_color","Hit color",settings.look_color_pickers.hit_color.color)
 var recent:Button
 for child in sheet.recent_row.get_children():
  if child.get_meta("recent","")=="c8547a":recent=child
 check(recent!=null,"An applied rail color is offered in another tab")
 if recent:recent.pressed.emit()
 check(game.hit_color=="c8547a","Recent swatches preview on the current setting")
 sheet.close(false);await create_timer(.2).timeout
 check(game.hit_color=="","Cancel returns hit effects to automatic note colors")
 sheet=settings.open_look_color_picker("hit_color","Hit color",settings.look_color_pickers.hit_color.color)
 sheet.set_color(Color("c8547a"));sheet.close(true);await create_timer(.2).timeout
 check(game.prefs.get_value("colors","recent",[]).size()==count,"Reusing a color never duplicates its history entry")
 sheet=settings.open_look_color_picker("band_color","Judgment bar color",settings.look_color_pickers.band_color.color)
 sheet.set_color(Color("37ac91"));sheet.close(true);await create_timer(.2).timeout
 check(game.band_color=="37ac91","Judgment bar accepts arbitrary colors")
 settings.show_section("colors",false);settings.color_pickers.tap.pressed.emit()
 for child in settings.get_children():
  if child.get_script()==SHEET:sheet=child
 check(sheet.recent_codes[0]=="37ac91","Original Colors section shares the same recent history")
 sheet.set_color(Color("4399ee"))
 await create_timer(.35).timeout
 check(sheet.palette_scroll.position.y+sheet.palette_scroll.size.y<sheet.card.size.y-70,"Recent colors and presets stay above action buttons")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.tools/shared-picker-review/picker-history.png")
 var full_size=sheet.size
 sheet.size=Vector2(1024,360);sheet.layout()
 check(sheet.palette_scroll.position.y+sheet.palette_scroll.size.y<sheet.card.get_node("Done").position.y,"Compact landscape keeps history clear of action buttons")
 sheet.size=full_size;sheet.layout()
 sheet.close(true);await create_timer(.2).timeout
 check(game.gameplay_colors.get("tap")=="4399ee" and game.prefs.get_value("colors","recent",[])[0]=="4399ee","Colors section saves into the same history")
 settings.apply_look_color("rail_color","")
 check(game.rail_color=="" and "c8547a" in game.prefs.get_value("colors","recent",[]),"AUTO follows the style without erasing color history")
 var previous=game.prefs.get_value("colors","recent",[]).duplicate();var oversized:Array=[]
 for i in 32:oversized.append("%06x" % (i+1))
 oversized.push_front("invalid");oversized.push_front("#4399EE");oversized.push_front("4399ee")
 game.prefs.set_value("colors","recent",oversized)
 var bounded=SHEET.applied_colors(game)
 check(bounded.size()==SHEET.RECENT_LIMIT and bounded.count("4399ee")==1,"History is bounded, normalized and deduplicated")
 game.prefs.set_value("colors","recent",previous);game.prefs.save(path)
 game.queue_free();await process_frame
 var restored=load("res://scenes/main.tscn").instantiate();root.add_child(restored)
 await process_frame;await process_frame
 check(SHEET.applied_colors(restored)[0]=="4399ee" and restored.band_color=="37ac91" and restored.hit_color=="c8547a","Shared history and arbitrary colors survive restarting")
 restored.queue_free();await process_frame
 print("Shared color pickers, preview/cancel, cross-tab history and persistence failures: ",failures)
 quit(failures)
