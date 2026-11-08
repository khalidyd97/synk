extends Control
const CATALOG=preload("res://scripts/ssrg_game_catalog.gd")
const Action=preload("res://scripts/settings_action.gd")
var host:Control
var list:HFlowContainer
var scroll:ScrollContainer
var search:LineEdit
var add_dialog:ConfirmationDialog
var name_input:LineEdit
var image_picker:FileDialog
var icon_game=""
var message:Label
func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 # Album Takeover: the same soft cover-coloured light as every other menu, no stage photo.
 var stage=ColorRect.new();add_child(stage);stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);stage.color=Color.WHITE;stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
 # Bleed past the safe area so the light reaches every edge of the phone.
 stage.offset_left=-800;stage.offset_right=800;stage.offset_top=-400;stage.offset_bottom=400
 preload("res://scripts/background_motion.gd").attach(stage,preload("res://scripts/song_browser_background.gdshader"))
 host.action(self,"‹  Back",.02,.03,.12,.12,host.close,"nav")
 var heading=host.text(self,"Games",.15,.015,.6,.1,46,Color("f4f1ea"));heading.add_theme_font_override("font",preload("res://scripts/arcade_style.gd").SERIF)
 host.text(self,"Select a game to see its songs.",.15,.09,.7,.14,18,Color("bcb7ad"))
 host.action(self,"+ Add game",.78,.035,.98,.12,func():name_input.clear();add_dialog.popup_centered(),"primary")
 search=LineEdit.new();host.place(search,self,.02,.17,.98,.24);search.placeholder_text="Search games";search.clear_button_enabled=true;search.text_changed.connect(func(_value):refresh())
 scroll=ScrollContainer.new();host.place(scroll,self,.02,.28,.98,.92);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 preload("res://scripts/drag_scroll.gd").attach(scroll)
 # Album Takeover: games stand on a shelf as large cover tiles, not as boxed rows.
 list=HFlowContainer.new();scroll.add_child(list);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 list.add_theme_constant_override("h_separation",34);list.add_theme_constant_override("v_separation",26)
 message=host.text(self,"",.02,.94,.98,.99,16,host.MUTED)
 add_dialog=ConfirmationDialog.new();add_child(add_dialog);add_dialog.title="Add a game";add_dialog.ok_button_text="ADD GAME";add_dialog.min_size=Vector2i(440,140)
 preload("res://scripts/modal_input.gd").register(add_dialog)
 name_input=LineEdit.new();add_dialog.add_child(name_input);name_input.placeholder_text="Game name";name_input.max_length=80
 add_dialog.confirmed.connect(add_game)
 image_picker=FileDialog.new();add_child(image_picker);image_picker.use_native_dialog=true;image_picker.access=FileDialog.ACCESS_FILESYSTEM;image_picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;image_picker.filters=PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Game icon"])
 preload("res://scripts/modal_input.gd").register(image_picker);image_picker.file_selected.connect(save_icon)
 visibility_changed.connect(func():if not visible:add_dialog.hide();image_picker.hide())
func refresh():
 for child in list.get_children():list.remove_child(child);child.queue_free()
 var needle=search.text.strip_edges().to_lower();var count=0
 for entry in CATALOG.entries(host.game):
  if not needle.is_empty() and not (str(entry.name)+" "+str(entry.id)).to_lower().contains(needle):continue
  count+=1
  list.add_child(tile(entry))
 message.text="%d game%s  ·  Add a game, or use Icon on a tile to set its artwork." % [count,"" if count==1 else "s"]
# One game: its artwork (or a colour wash with its initials in the serif), the name below,
# and how many songs it holds. Hovering lifts the tile a little.
func tile(entry:Dictionary) -> Control:
 var A=preload("res://scripts/arcade_style.gd")
 var side=320.0
 var holder=Control.new();holder.custom_minimum_size=Vector2(side,side+96)
 var button=Button.new();holder.add_child(button);button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);button.focus_mode=Control.FOCUS_ALL;button.flat=true
 for state in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 preload("res://scripts/ui_motion.gd").bind_button(button)
 button.pressed.connect(func():if not preload("res://scripts/drag_scroll.gd").was_dragged(scroll):host.open_game(entry.id))
 var art=TextureRect.new();button.add_child(art);art.position=Vector2.ZERO;art.size=Vector2(side,side);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 var path=CATALOG.icon_path(entry.id)
 if FileAccess.file_exists(path):
  art.texture=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
 else:
  var hue=float(posmod(str(entry.id).hash(),360))/360.0
  var ramp=Gradient.new();ramp.set_color(0,Color.from_hsv(hue,.6,.85));ramp.set_color(1,Color.from_hsv(fmod(hue+.2,1.0),.75,.5))
  var wash=GradientTexture2D.new();wash.gradient=ramp;wash.width=64;wash.height=64;wash.fill_from=Vector2(0,0);wash.fill_to=Vector2(1,1)
  art.texture=wash
  var initials=Label.new();art.add_child(initials);initials.text=str(entry.badge);initials.position=Vector2(20,side-104);initials.size=Vector2(side-40,96)
  initials.add_theme_font_override("font",A.SERIF);initials.add_theme_font_size_override("font_size",76);initials.add_theme_color_override("font_color",Color(1,1,1,.92))
  initials.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;initials.mouse_filter=Control.MOUSE_FILTER_IGNORE
 preload("res://scripts/screen_style.gd").round_cover(art,14)
 var shadow=Panel.new();button.add_child(shadow);button.move_child(shadow,0);shadow.position=Vector2.ZERO;shadow.size=Vector2(side,side);shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var drop=StyleBoxFlat.new();drop.bg_color=Color(0,0,0,.25);drop.set_corner_radius_all(14);drop.shadow_color=Color(0,0,0,.45);drop.shadow_size=26;drop.shadow_offset=Vector2(0,14)
 shadow.add_theme_stylebox_override("panel",drop)
 var title=Label.new();button.add_child(title);title.position=Vector2(2,side+12);title.size=Vector2(side-4,40);title.text=entry.name
 title.add_theme_font_override("font",A.SERIF);title.add_theme_font_size_override("font_size",32);title.add_theme_color_override("font_color",A.TEXT)
 title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.clip_text=true;title.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var info=Label.new();button.add_child(info);info.position=Vector2(3,side+54);info.size=Vector2(side,28)
 info.text="%d song%s" % [int(entry.count),"" if int(entry.count)==1 else "s"]
 info.add_theme_font_override("font",A.mono());info.add_theme_font_size_override("font_size",17);info.add_theme_color_override("font_color",A.MUTED);info.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var edit=Action.new();holder.add_child(edit);edit.text="Icon";edit.caption_size=14;edit.position=Vector2(side-86,12);edit.size=Vector2(74,40);edit.tooltip_text="Use your own artwork for this game"
 edit.pressed.connect(func():if not Action.was_dragged(edit):choose_icon(entry.id))
 return holder
func add_game():
 var value=name_input.text.strip_edges()
 if value.is_empty():message.text="Enter a game name.";return
 var names=host.game.prefs.get_value("ssrg_games","custom",[])
 if not names is Array:names=[]
 var id=CATALOG.normalize(value)
 if not CATALOG.entries(host.game).any(func(entry):return entry.id==id):names.append(value)
 host.game.prefs.set_value("ssrg_games","custom",names);host.game.prefs.save("user://preferences.cfg");refresh();host.open_game(id)
func choose_icon(id:String):
 icon_game=id
 if NativeFilePicker.open_image(func(paths):if visible:save_icon(paths[0])):return
 image_picker.popup_centered_ratio(.75)
func save_icon(path:String):
 var image=host.game.load_picked_image(path)
 if image is String:message.text=image;return
 image.resize(256,256,Image.INTERPOLATE_LANCZOS)
 DirAccess.make_dir_recursive_absolute("user://ssrg_games")
 if image.save_png(CATALOG.icon_path(icon_game))!=OK:message.text="Could not save the game icon.";return
 refresh()
