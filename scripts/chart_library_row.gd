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
    custom_minimum_size=Vector2(0,124); size_flags_horizontal=Control.SIZE_EXPAND_FILL
    mouse_filter=Control.MOUSE_FILTER_PASS; mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    cover=TextureRect.new(); add_child(cover); cover.position=Vector2(12,16); cover.size=Vector2(92,92)
    cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_label=text_label(27,Color("f4f2ff")); subtitle=text_label(18,Color("aaaecb"))
    status=text_label(14,Color("4bdaed")); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    edited=text_label(14,Color("aaaecb")); edited.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    resized.connect(layout); layout()
    button_down.connect(func(): preload("res://scripts/ui_sound.gd").play(self,"click"))
    button_down.connect(func(): if not disabled: motion.press=1.0)
func layout() -> void:
    if not title_label: return
    title_label.position=Vector2(124,27); title_label.size=Vector2(maxf(40,size.x-302),32)
    subtitle.position=Vector2(124,65); subtitle.size=Vector2(maxf(40,size.x-302),27)
    status.position=Vector2(size.x-154,33); status.size=Vector2(135,25)
    edited.position=Vector2(size.x-175,64); edited.size=Vector2(156,27)
func update_entry(value: Dictionary,data: Dictionary) -> void:
    entry=value; set_meta("song_id",entry.id)
    title_label.text=entry.title
    var count=data.versions.size()
    subtitle.text=entry.artist+" · "+("No charts yet" if count==0 else "%d chart version%s" % [count,"" if count==1 else "s"])
    cover.texture=library.game.lobby.cover_for(entry.id); library.game.lobby.style_cover(cover,entry.id,13)
    status.text="DRAFT" if data.draft else ("READY" if data.charted else "NEW")
    var tint=Color("a9a5c9") if data.draft else (Color("4bdaed") if data.charted else Color("d36ef2"))
    status.add_theme_color_override("font_color",tint)
    var style=StyleBoxFlat.new(); style.bg_color=Color(tint,.07); style.border_color=Color(tint,.45)
    style.set_border_width_all(1); style.set_corner_radius_all(9); status.add_theme_stylebox_override("normal",style)
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
    var style=StyleBoxFlat.new(); style.set_corner_radius_all(18); style.set_border_width_all(1)
    style.bg_color=Color("090c1c").lerp(Color("092032"),amount)
    style.bg_color=style.bg_color.lightened(hover_amount*.04)
    style.border_color=Color("263047").lerp(Color("4bdaed"),amount)
    style.shadow_color=Color(.05,.75,.9,.12*amount); style.shadow_size=8
    draw_style_box(style,Rect2(Vector2.ONE,size-Vector2.ONE*2))
    motion.paint(self,Color("4bdaed"),maxf(amount*.65,hover_amount),18)
