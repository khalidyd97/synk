extends Button
var library: Control
var entry: Dictionary={}
var selected=false
var amount=0.0
var hover_amount=0.0
var cover: TextureRect
var title_label: Label
var subtitle: Label
var status: Label
var edited: Label
var motion=preload("res://scripts/menu_button_motion.gd").new()
func text_label(font_size: int,tint: Color) -> Label:
    var n=Label.new(); add_child(n); n.add_theme_font_size_override("font_size",font_size)
    n.add_theme_color_override("font_color",tint); n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    n.mouse_filter=Control.MOUSE_FILTER_IGNORE; n.clip_text=true; n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    return n
func _ready() -> void:
    custom_minimum_size=Vector2(0,112); size_flags_horizontal=Control.SIZE_EXPAND_FILL
    mouse_filter=Control.MOUSE_FILTER_PASS; mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    cover=TextureRect.new(); add_child(cover); cover.position=Vector2(26,16); cover.size=Vector2(80,80)
    cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
    # Same voice as the song list: the name in the serif, everything else in the sans.
    var A=preload("res://scripts/arcade_style.gd")
    title_label=text_label(36,Color("f4f1ea")); title_label.add_theme_font_override("font",A.SERIF)
    subtitle=text_label(17,Color("d9d4ca")); subtitle.add_theme_font_override("font",A.mono())
    status=text_label(15,Color("f4f1ea")); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; status.add_theme_font_override("font",A.semi())
    edited=text_label(14,Color("bcb7ad")); edited.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; edited.add_theme_font_override("font",A.mono())
    resized.connect(layout); layout()
    button_down.connect(func(): preload("res://scripts/ui_sound.gd").play(self,"click"))
    button_down.connect(func(): if not disabled: motion.press=1.0)
func layout() -> void:
    if not title_label: return
    title_label.position=Vector2(122,17); title_label.size=Vector2(maxf(40,size.x-320),40)
    subtitle.position=Vector2(122,59); subtitle.size=Vector2(maxf(40,size.x-320),27)
    status.position=Vector2(size.x-190,26); status.size=Vector2(170,25)
    edited.position=Vector2(size.x-210,58); edited.size=Vector2(190,27)
func update_entry(value: Dictionary,data: Dictionary) -> void:
    entry=value; set_meta("song_id",entry.id)
    title_label.text=entry.title
    var count=data.versions.size()
    subtitle.text=entry.artist+" · "+("No charts yet" if count==0 else "%d chart version%s" % [count,"" if count==1 else "s"])
    cover.texture=library.game.lobby.cover_for(entry.id); library.game.lobby.style_cover(cover,entry.id,13)
    # A small coloured word instead of a badge box.
    status.text="●  Draft" if data.draft else ("●  Ready" if data.charted else "●  New")
    var tint=Color("ffd36a") if data.draft else (Color("9fd8b8") if data.charted else Color("ff8a5b"))
    status.add_theme_color_override("font_color",tint)
    edited.text=relative_time(int(data.modified))
    tooltip_text=entry.title+" · Select a chart version"
func relative_time(at: int) -> String:
    if at<=0: return "Built-in chart" if entry.id=="eclipse" else "Not edited yet"
    var elapsed=maxi(0,int(Time.get_unix_time_from_system())-at)
    if elapsed<60: return "Edited just now"
    if elapsed<3600: return "Edited %dm ago" % (elapsed/60)
    if elapsed<86400: return "Edited %dh ago" % (elapsed/3600)
    return "Edited %dd ago" % (elapsed/86400)
func set_selected(value: bool) -> void: selected=value
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    amount=lerpf(amount,1.0 if selected else 0.0,1-exp(-delta*16)); queue_redraw()
    hover_amount=lerpf(hover_amount,1.0 if is_hovered() or has_focus() else 0.0,1-exp(-delta*14))
    motion.advance(delta,selected or hover_amount>.01)
func _draw() -> void:
    # No box: a hairline separates songs; the chosen one sits on a frosted card that breathes.
    var wash=maxf(amount*(.11+.03*sin(Time.get_ticks_msec()/1000.0*2.0)),hover_amount*.05)
    if wash>.004:
        var plate=StyleBoxFlat.new(); plate.set_corner_radius_all(16); plate.bg_color=Color(1,1,1,wash); plate.anti_aliasing=true
        draw_style_box(plate,Rect2(Vector2(2,3),size-Vector2(4,6)))
    if amount<.98:
        draw_line(Vector2(16,size.y-1),Vector2(size.x-16,size.y-1),Color(1,1,1,.08*(1.0-amount)),1.0)

# Hidden widgets stop their per-frame update (screens keep many of them alive offscreen).
func _notification(what: int) -> void:
    if what==NOTIFICATION_VISIBILITY_CHANGED or what==NOTIFICATION_READY: set_process(is_visible_in_tree())
