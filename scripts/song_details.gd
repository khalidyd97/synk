extends Control
# Song details, opened from the song browser: title, artist, album, track number, album art
# and the gameplay background shown behind the highway. Nothing is written until SAVE.
const Action = preload("res://scripts/settings_action.gd")
const TEXT = Color("eef0ff")
const MUTED = Color("a7aac6")
const ACCENT = Color("50daec")

var game: Control
var song_id = ""
var canvas: Control
var heading: Label
var fields: Dictionary = {}
var cover_preview: TextureRect
var cover_note: Label
var background_preview: TextureRect
var background_black: ColorRect
var background_note: Label
var remove_cover_button: Button
var remove_background_button: Button
var choose_cover_button: Button
var message: Label
var picker: FileDialog
var picking = ""
# Pending edits: an Image to save, "remove", or null for unchanged.
var pending_cover: Variant = null
var pending_background: Variant = null

func style(fill: Color=Color("0c0d21"),edge: Color=Color("2c2d44"),radius: int=22) -> StyleBoxFlat:
	var box=StyleBoxFlat.new(); box.bg_color=fill; box.border_color=edge; box.set_corner_radius_all(radius); box.set_border_width_all(1); return box
func place(node: Control,parent: Control,x: float,y: float,w: float,h: float) -> Control:
	parent.add_child(node); node.position=Vector2(x,y); node.size=Vector2(w,h); return node
func label(parent: Control,value: String,x: float,y: float,w: float,h: float,font_size: int,tint: Color=TEXT) -> Label:
	var n=Label.new(); place(n,parent,x,y,w,h); n.text=value
	n.add_theme_font_size_override("font_size",font_size); n.add_theme_color_override("font_color",tint)
	n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	return n
func action(parent: Control,value: String,x: float,y: float,w: float,h: float,callback: Callable,primary: bool=false) -> Button:
	var n=Action.new(); n.text=value; n.primary=primary; n.caption_size=20; place(n,parent,x,y,w,h)
	n.pressed.connect(func(): if not Action.was_dragged(n): callback.call())
	return n

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	var background=ColorRect.new(); add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var mat=preload("res://scripts/background_motion.gd").attach(background,preload("res://scripts/song_browser_background.gdshader"))
	mat.set_shader_parameter("ambience",Color(.1,.07,.24))
	preload("res://scripts/screen_backdrop.gd").video(self,0.08,.5)  # magenta stage
	canvas=Control.new(); add_child(canvas); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme_local=Theme.new(); theme_local.default_font=ThemeDB.fallback_font; canvas.theme=theme_local
	for type in ["Label","Button","LineEdit"]: theme_local.set_font("font",type,ThemeDB.fallback_font)
	resized.connect(layout); game.safe_area_changed.connect(layout); layout()
	var back=action(canvas,"‹",48,36,84,84,cancel); back.caption_size=34
	label(canvas,"S O N G   D E T A I L S",144,33,600,24,14,ACCENT)
	heading=label(canvas,"",144,57,900,52,40)
	var bold=FontVariation.new(); bold.base_font=ThemeDB.fallback_font; bold.variation_embolden=.5
	heading.add_theme_font_override("font",bold)
	# Text details.
	var info=place(Panel.new(),canvas,48,150,620,520); info.add_theme_stylebox_override("panel",style())
	label(info,"Details",28,20,560,40,26)
	var rows=[["title","Title","Song title"],["artist","Artist","Artist name"],["album","Album","Album name"],["track","Track number","e.g. 3"]]
	for i in rows.size():
		var y=78+i*106
		label(info,rows[i][1],28,y,560,26,17,MUTED)
		var input=LineEdit.new(); place(input,info,28,y+30,564 if i<3 else 200,62)
		input.placeholder_text=rows[i][2]; input.add_theme_font_size_override("font_size",22)
		var box=style(Color("09091c"),Color("302a42"),15); box.content_margin_left=18; box.content_margin_right=14
		input.add_theme_stylebox_override("normal",box)
		var focus=box.duplicate(); focus.border_color=ACCENT; input.add_theme_stylebox_override("focus",focus)
		input.text_submitted.connect(func(_text): input.release_focus())
		fields[rows[i][0]]=input
	fields.track.max_length=4
	fields.track.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	fields.track.text_changed.connect(func(value):
		var digits=""
		for c in value: if c>="0" and c<="9": digits+=c
		if digits!=value:
			fields.track.text=digits; fields.track.caret_column=digits.length())
	# Artwork.
	var art=place(Panel.new(),canvas,696,150,712,520); art.add_theme_stylebox_override("panel",style())
	label(art,"Artwork",28,20,640,40,26)
	label(art,"Album art",28,78,300,26,17,MUTED)
	var cover_frame=place(Panel.new(),art,28,110,180,180); cover_frame.add_theme_stylebox_override("panel",style(Color("09091c"),Color("302a42"),18))
	cover_frame.clip_contents=true
	cover_preview=TextureRect.new(); place(cover_preview,cover_frame,0,0,180,180)
	cover_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preload("res://scripts/screen_style.gd").round_cover(cover_preview,18)
	choose_cover_button=action(art,"CHOOSE IMAGE",230,110,210,64,func(): pick("cover"))
	remove_cover_button=action(art,"REMOVE",452,110,140,64,func(): pending_cover="remove"; refresh_previews())
	cover_note=label(art,"",230,186,450,100,15,MUTED); cover_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cover_note.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	label(art,"Gameplay background",28,306,400,26,17,MUTED)
	var bg_frame=place(Panel.new(),art,28,338,288,162); bg_frame.add_theme_stylebox_override("panel",style(Color("09091c"),Color("302a42"),14))
	bg_frame.clip_contents=true
	background_black=ColorRect.new(); place(background_black,bg_frame,1,1,286,160); background_black.color=Color.BLACK
	background_preview=TextureRect.new(); place(background_preview,bg_frame,1,1,286,160)
	background_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; background_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	action(art,"CHOOSE IMAGE",338,338,210,64,func(): pick("background"))
	remove_background_button=action(art,"REMOVE",560,338,124,64,func(): pending_background="remove"; refresh_previews())
	background_note=label(art,"",338,410,350,90,15,MUTED); background_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	background_note.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	message=label(canvas,"",48,690,900,40,17,Color("ff9bb5"))
	action(canvas,"CANCEL",1010,690,180,84,cancel)
	action(canvas,"SAVE",1210,690,198,84,save,true).caption_size=24
	picker=FileDialog.new(); add_child(picker)
	picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE; picker.access=FileDialog.ACCESS_FILESYSTEM; picker.use_native_dialog=true
	picker.filters=PackedStringArray(["*.png,*.jpg,*.jpeg;Images;image/png,image/jpeg"])
	picker.file_selected.connect(picked)
	visible=false

func layout() -> void:
	if not canvas: return
	var available=game.safe_rect_for(self)
	var k=maxf(.1,minf(available.size.x/1456.0,available.size.y/819.0))
	canvas.scale=Vector2.ONE*k; canvas.size=Vector2(1456,819)
	canvas.position=available.position+(available.size-Vector2(1456,819)*k)*.5

func open(id: String) -> void:
	song_id=id; pending_cover=null; pending_background=null; message.text=""
	var entry: Dictionary=game.song_details_entry(id)
	# Show the same cleaned-up title the song lists use (no underscores or file tags).
	var clean_title=preload("res://scripts/lobby.gd").display_title(str(entry.get("title","")))
	heading.text=clean_title; fields.title.text=clean_title
	fields.artist.text=str(entry.get("artist",""))
	fields.album.text=str(entry.get("album",""))
	fields.track.text=str(int(entry.track)) if int(entry.get("track",0))>0 else ""
	refresh_previews()

# The album art and background previews show exactly what gameplay will use after SAVE.
func refresh_previews() -> void:
	var cover: Texture2D=null
	if pending_cover is Image: cover=ImageTexture.create_from_image(pending_cover)
	elif pending_cover==null and game.has_custom_cover(song_id): cover=game.cover_texture_for_id(song_id)
	var built_in=song_id=="eclipse" and cover==null
	if built_in: cover=game.ECLIPSE_COVER
	cover_preview.texture=cover if cover else preload("res://scripts/song_browser.gd").PLACEHOLDER
	remove_cover_button.disabled=not (pending_cover is Image or (pending_cover==null and game.has_custom_cover(song_id)))
	cover_note.text="Built-in cover. Choose an image to replace it." if built_in else ("Square images work best; others are cropped to the center." if cover else "No album art yet.")
	var background: Texture2D=null
	if pending_background is Image: background=ImageTexture.create_from_image(pending_background)
	elif pending_background==null and game.has_background(song_id): background=game.background_texture_for_id(song_id)
	remove_background_button.disabled=background==null
	if background:
		background_preview.texture=background; background_preview.modulate=Color.WHITE
		background_note.text="Shown behind the highway during play."
	elif cover:
		background_preview.texture=cover; background_preview.modulate=Color(1,1,1,.55)
		background_note.text="Not set: gameplay uses the album art."
	else:
		background_preview.texture=null
		background_note.text="Not set: gameplay uses a solid black background."

func pick(kind: String) -> void:
	picking=kind; message.text=""
	if OS.get_name()=="iOS":
		picker.access=FileDialog.ACCESS_USERDATA; picker.current_dir="user://"
	picker.popup_centered_ratio(.75)

func picked(path: String) -> void:
	var result: Variant=game.load_picked_image(path)
	if result is String: message.text=result; return
	if picking=="cover": pending_cover=result
	else: pending_background=result
	refresh_previews()

func save() -> void:
	var error=""
	if pending_cover is Image: error=game.save_cover_image(song_id,pending_cover)
	elif pending_cover=="remove": game.remove_cover(song_id)
	if error.is_empty():
		if pending_background is Image: error=game.save_background_image(song_id,pending_background)
		elif pending_background=="remove": game.remove_background(song_id)
	if not error.is_empty(): message.text=error; return
	game.update_song_details(song_id,{"title":fields.title.text,"artist":fields.artist.text,"album":fields.album.text,"track":int(fields.track.text) if fields.track.text.is_valid_int() else 0})
	game.close_song_details()
	game.tell("Song details saved.")

func cancel() -> void:
	game.close_song_details()
