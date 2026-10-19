extends Button
const Favorite=preload("res://scripts/song_favorite.gd")
var lobby: Control
var entry: Dictionary={}
var selected=false
var selection_amount=0.0
var hover_amount=0.0
var cover_rect: TextureRect
var title_label: Label
var artist_label: Label
var duration_label: Label
var heart: Button
var intensity=0
var accent=Color("46dcec")
var motion=preload("res://scripts/menu_button_motion.gd").new()
func label(value: String,font_size: int) -> Label:
    var result=Label.new(); add_child(result); result.text=value
    result.add_theme_font_size_override("font_size",font_size); result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    result.clip_text=true; result.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    result.mouse_filter=Control.MOUSE_FILTER_IGNORE; return result
func _ready() -> void:
    text=""; custom_minimum_size=Vector2(0,112); size_flags_horizontal=Control.SIZE_EXPAND_FILL
    mouse_filter=Control.MOUSE_FILTER_PASS; mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    cover_rect=TextureRect.new(); add_child(cover_rect); cover_rect.position=Vector2(12,16); cover_rect.size=Vector2(80,80)
    cover_rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover_rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    cover_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
    preload("res://scripts/screen_style.gd").round_cover(cover_rect,12)
    title_label=label("",25); artist_label=label("",18); artist_label.add_theme_color_override("font_color",Color("aca6c3"))
    var medium=FontVariation.new(); medium.base_font=ThemeDB.fallback_font; medium.variation_embolden=.35
    title_label.add_theme_font_override("font",medium)
    duration_label=label("",17); duration_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    duration_label.add_theme_color_override("font_color",Color("d5cee9"))
    heart=Favorite.new(); add_child(heart)
    heart.pressed.connect(func():
        if not preload("res://scripts/drag_scroll.gd").was_dragged(lobby.track_scroll): lobby.toggle_favorite_id(str(entry.id)))
    resized.connect(layout); layout()
    button_down.connect(func(): if not disabled: motion.press=1.0)
func layout() -> void:
    if title_label==null: return
    title_label.position=Vector2(110,21); title_label.size=Vector2(maxf(40,size.x-350),29)
    artist_label.position=Vector2(110,59); artist_label.size=Vector2(maxf(40,size.x-350),27)
    duration_label.position=Vector2(size.x-144,40); duration_label.size=Vector2(60,32)
    heart.position=Vector2(size.x-76,20); heart.size=Vector2(72,72)
func update_entry(value: Dictionary) -> void:
    entry=value; set_meta("song_id",entry.id); set_meta("song_index",entry.index)
    title_label.text=entry.title; artist_label.text=entry.artist+(" · "+str(entry.genre) if not str(entry.genre).is_empty() else "")
    cover_rect.texture=lobby.cover_for(entry.id)
    lobby.style_cover(cover_rect,entry.id,12)
    duration_label.text=lobby.duration_text(float(entry.duration))
    intensity=int(entry.rating); accent=entry.accent
    heart.active=lobby.favorites.has(str(entry.id)); heart.tooltip_text="Remove favorite" if heart.active else "Favorite song"
    tooltip_text=entry.title+" · "+entry.artist
func set_selected(value: bool) -> void: selected=value
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    selection_amount=lerpf(selection_amount,1.0 if selected else 0.0,1-exp(-delta*16)); queue_redraw()
    hover_amount=lerpf(hover_amount,1.0 if is_hovered() or has_focus() else 0.0,1-exp(-delta*14))
    motion.advance(delta,selected or hover_amount>.01)
func _draw() -> void:
    var style=StyleBoxFlat.new(); style.set_corner_radius_all(18)
    style.bg_color=Color(.027,.023,.065,.9).lerp(Color(.025,.11,.15,.92),selection_amount)
    style.bg_color=style.bg_color.lightened(hover_amount*.035)
    style.border_color=Color(.19,.17,.27,.5).lerp(Color("4bd6e7"),selection_amount)
    style.set_border_width_all(1)
    if selection_amount>.01: style.shadow_color=Color(.05,.75,.9,.10*selection_amount); style.shadow_size=9
    draw_style_box(style,Rect2(Vector2.ONE,size-Vector2.ONE*2))
    motion.paint(self,accent,maxf(selection_amount*.65,hover_amount),18)
    for i in 5:
        var h=8+i*3
        draw_style_box(bar_style(accent if i<intensity else Color("343040")),Rect2(size.x-238+i*12,66-h,8,h))
func bar_style(tint: Color) -> StyleBoxFlat:
    var style=StyleBoxFlat.new(); style.bg_color=tint; style.set_corner_radius_all(2); return style
