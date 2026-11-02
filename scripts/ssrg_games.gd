extends Control
const CATALOG=preload("res://scripts/ssrg_game_catalog.gd")
const Action=preload("res://scripts/settings_action.gd")
var host:Control
var list:VBoxContainer
var scroll:ScrollContainer
var search:LineEdit
var add_dialog:ConfirmationDialog
var name_input:LineEdit
var image_picker:FileDialog
var icon_game=""
var message:Label
func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 host.action(self,"‹  BACK",.02,.03,.12,.12,host.close,"nav")
 host.text(self,"GAMES",.15,.025,.6,.09,32)
 host.text(self,"Select a game to see its songs.",.15,.09,.7,.14,16,host.MUTED)
 host.action(self,"+ ADD GAME",.78,.035,.98,.12,func():name_input.clear();add_dialog.popup_centered(),"primary")
 search=LineEdit.new();host.place(search,self,.02,.17,.98,.24);search.placeholder_text="Search games";search.clear_button_enabled=true;search.text_changed.connect(func(_value):refresh())
 scroll=ScrollContainer.new();host.place(scroll,self,.02,.27,.98,.92);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 preload("res://scripts/drag_scroll.gd").attach(scroll)
 list=VBoxContainer.new();scroll.add_child(list);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12)
 message=host.text(self,"",.02,.94,.98,.99,14,host.MUTED)
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
  var row=HBoxContainer.new();row.custom_minimum_size.y=94;list.add_child(row);row.add_theme_constant_override("separation",12)
  var button=Button.new();row.add_child(button);button.custom_minimum_size.y=94;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.focus_mode=Control.FOCUS_NONE
  button.add_theme_stylebox_override("normal",host.box(Color("17171f"),Color(1,1,1,.12),20))
  button.add_theme_stylebox_override("hover",host.box(Color("24212f"),Color(entry.color,.5),20))
  button.add_theme_stylebox_override("pressed",host.box(Color("302939"),Color(entry.color),20))
  var icon=Panel.new();button.add_child(icon);icon.position=Vector2(16,11);icon.size=Vector2(72,72);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.add_theme_stylebox_override("panel",host.box(Color(entry.color,.12),Color(entry.color,.35),18))
  var path=CATALOG.icon_path(entry.id)
  if FileAccess.file_exists(path):
   var texture=TextureRect.new();icon.add_child(texture);texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.texture=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)));texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
  else:
   var badge=Label.new();icon.add_child(badge);badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);badge.text=entry.badge;badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;badge.add_theme_font_size_override("font_size",18 if badge.text.length()>3 else 24);badge.add_theme_color_override("font_color",Color(entry.color));badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var title=Label.new();button.add_child(title);title.position=Vector2(112,14);title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);title.offset_left=112;title.offset_right=-40;title.offset_top=14;title.offset_bottom=48;title.text=entry.name;title.add_theme_font_size_override("font_size",24);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  var info=Label.new();button.add_child(info);info.position=Vector2(112,54);info.text="%d song%s   ›" % [int(entry.count),"" if int(entry.count)==1 else "s"];info.add_theme_color_override("font_color",host.MUTED);info.mouse_filter=Control.MOUSE_FILTER_IGNORE
  button.pressed.connect(func():if not preload("res://scripts/drag_scroll.gd").was_dragged(scroll):host.open_game(entry.id))
  var edit=Action.new();row.add_child(edit);edit.text="ICON";edit.caption_size=15;edit.custom_minimum_size=Vector2(90,94)
  edit.pressed.connect(func():if not Action.was_dragged(edit):choose_icon(entry.id))
 message.text="%d games  ·  Add a game or choose ICON to use your own artwork." % count
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
