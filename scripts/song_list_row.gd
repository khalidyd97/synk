extends Button
const Favorite=preload("res://scripts/song_favorite.gd")
const Arcade=preload("res://scripts/arcade_style.gd")
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
    cover_rect=TextureRect.new(); add_child(cover_rect); cover_rect.position=Vector2(26,16); cover_rect.size=Vector2(80,80)
    cover_rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover_rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    cover_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
    preload("res://scripts/screen_style.gd").round_cover(cover_rect,4)
    title_label=label("",31); artist_label=label("",15); artist_label.add_theme_color_override("font_color",Arcade.SUBTLE)
    title_label.add_theme_font_override("font",Arcade.SERIF)
    artist_label.add_theme_font_override("font",Arcade.mono())
    duration_label=label("",14); duration_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    duration_label.add_theme_color_override("font_color",Arcade.MUTED); duration_label.add_theme_font_override("font",Arcade.mono())
    heart=Favorite.new(); add_child(heart)
    heart.pressed.connect(func():
        if not preload("res://scripts/drag_scroll.gd").was_dragged(lobby.track_scroll): lobby.toggle_favorite_id(str(entry.id)))
    resized.connect(layout); layout()
    button_down.connect(func(): if not disabled: motion.press=1.0)
func layout() -> void:
    if title_label==null: return
    title_label.position=Vector2(122,19); title_label.size=Vector2(maxf(40,size.x-350),29)
    artist_label.position=Vector2(122,59); artist_label.size=Vector2(maxf(40,size.x-350),27)
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
    # Album Takeover row: no box. A hairline separates songs; the chosen one sits on a
    # frosted card that breathes softly, and hovering lifts a faint wash.
    var rect=Rect2(Vector2(2,3),size-Vector2(4,6)); var radius=16
    var wash=maxf(selection_amount*(.11+.03*sin(Time.get_ticks_msec()/1000.0*2.0)),hover_amount*.05)
    if wash>.004:
        var plate=StyleBoxFlat.new(); plate.set_corner_radius_all(radius); plate.bg_color=Color(1,1,1,wash); plate.anti_aliasing=true
        draw_style_box(plate,rect)
    if selection_amount<.98:
        draw_line(Vector2(16,size.y-1),Vector2(size.x-16,size.y-1),Color(1,1,1,.08*(1.0-selection_amount)),1.0)
    # A small equaliser beside the title while this song's preview plays.
    if selected and lobby and lobby.preview_player.playing:
        var t=Time.get_ticks_msec()/1000.0
        var font=title_label.get_theme_font("font"); var fs=title_label.get_theme_font_size("font_size")
        var x=title_label.position.x+minf(font.get_string_size(title_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x,title_label.size.x)+14
        for i in 4:
            var h=6+12*absf(sin(t*(5.0+i*1.7)+i*1.3))
            draw_rect(Rect2(x+i*7,46-h,4,h),Color(Arcade.TEXT,.8))
    # Difficulty pips.
    for i in 5:
        var lit=i<intensity
        draw_circle(Vector2(size.x-234+i*12,56),4.5,Color(Arcade.TEXT,.85) if lit else Color(1,1,1,.14),true,-1.0,true)
func bar_style(tint: Color) -> StyleBoxFlat:
    var style=StyleBoxFlat.new(); style.bg_color=tint; style.set_corner_radius_all(2); return style

# Hidden widgets stop their per-frame update (screens keep many of them alive offscreen).
func _notification(what: int) -> void:
    if what==NOTIFICATION_VISIBILITY_CHANGED or what==NOTIFICATION_READY: set_process(is_visible_in_tree())
