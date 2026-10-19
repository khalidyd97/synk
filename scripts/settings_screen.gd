extends Control

# Full-page settings opened from the lobby gear. BACK returns to the lobby.
const Action = preload("res://scripts/settings_action.gd")
const TEXT = Color("eef0ff")
const MUTED = Color(0.8,0.82,0.95,.78)
const ACCENT = Color("50daec")

var game: Control
var note_speed_input: Stepper
var highway_angle_input: Stepper
var timing_input: Stepper
var bluetooth_toggle: Switch
var bluetooth_latency_input: Stepper
var song_preview_toggle: Switch
var metronome_toggle: Switch
var shape_tiles: Dictionary = {}
var style_tiles: Dictionary = {}
var color_pickers: Dictionary = {}
var color_reset_buttons: Dictionary = {}
var rail_glow_input: Stepper
var rail_swatches: Array = []
var band_swatches: Array = []
var highway_opacity_input: Stepper
var color_mode_tiles: Dictionary = {}
# Swatch colors offered for the rails and the judgment band; "" follows the chosen style.
const LOOK_COLORS = ["","fff3dc","ffd257","ff9a3d","ff4d6d","ff5fc8","a46bff","4f7dff","4fd8ff","4dff9a","ffffff"]

# A − value + control. Setting `value` (in code or with the buttons) emits value_changed.
class Stepper extends Control:
    signal value_changed(value: float)
    var min_value = 0.0
    var max_value = 1.0
    var step = 1.0
    var suffix = ""
    var decimals = 0
    var minus: Button
    var plus: Button
    var readout: Label
    var _value = 0.0
    var value: float:
        get: return _value
        set(v):
            v = clampf(v,min_value,max_value)
            var changed = not is_equal_approx(v,_value)
            _value = v; refresh()
            if changed: value_changed.emit(v)
    var editable = true:
        set(v):
            editable = v
            if is_inside_tree():
                var old=get_meta("disabled_tween") if has_meta("disabled_tween") else null
                if old is Tween: old.kill()
                var tween=create_tween(); tween.tween_property(self,"modulate:a",1.0 if v else .35,.18)
                set_meta("disabled_tween",tween)
            else: modulate.a=1.0 if v else .35
            refresh()

    func _init(low: float, high: float, increment: float, start: float, unit: String, places: int) -> void:
        min_value = low; max_value = high; step = increment; suffix = unit; decimals = places; _value = start
        mouse_filter = Control.MOUSE_FILTER_PASS
        minus = Action.new(); minus.text = "−"; minus.caption_size = 30
        plus = Action.new(); plus.text = "+"; plus.caption_size = 30
        readout = Label.new(); readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        readout.add_theme_font_size_override("font_size",24); readout.add_theme_color_override("font_color",TEXT)
        var value_style=StyleBoxFlat.new(); value_style.bg_color=Color("121212")
        value_style.set_corner_radius_all(16); value_style.border_color=Color("2d3048"); value_style.set_border_width_all(1)
        readout.add_theme_stylebox_override("normal",value_style)
        for node in [minus,readout,plus]: add_child(node)
        anchor(minus,0,.24); anchor(readout,.26,.74); anchor(plus,.76,1)
        minus.pressed.connect(func(): if editable and not Action.was_dragged(self): value -= step)
        plus.pressed.connect(func(): if editable and not Action.was_dragged(self): value += step)
        refresh()

    func anchor(node: Control, left: float, right: float) -> void:
        node.anchor_left = left; node.anchor_right = right; node.anchor_top = 0; node.anchor_bottom = 1
        node.offset_left = 0; node.offset_right = 0; node.offset_top = 0; node.offset_bottom = 0

    func refresh() -> void:
        if readout == null: return
        readout.text = (("%." + str(decimals) + "f") % _value) + suffix
        minus.disabled = not editable or _value <= min_value
        plus.disabled = not editable or _value >= max_value

    func sync_value(v: float) -> void:
        _value=clampf(v,min_value,max_value); refresh()

# An on/off switch. Uses Button's toggle mode, so button_pressed and toggled work as usual.
class Switch extends Button:
    var knob=0.0
    var engagement=0.0
    func _init() -> void:
        toggle_mode=true; focus_mode=Control.FOCUS_ALL
        mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
        for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
        button_down.connect(func(): preload("res://scripts/ui_sound.gd").play(self,"click"))
    func _process(delta: float) -> void:
        if not is_visible_in_tree(): return
        knob=lerpf(knob,1.0 if button_pressed else 0.0,1-exp(-delta*15))
        engagement=lerpf(engagement,1.0 if is_hovered() or has_focus() else 0.0,1-exp(-delta*16))
        queue_redraw()
    func _draw() -> void:
        var style=StyleBoxFlat.new(); style.set_corner_radius_all(18); style.set_border_width_all(1)
        style.bg_color=Color("141414").lerp(Color("12313d"),knob*.65)
        style.border_color=Color("34364f").lerp(Color("50daec"),maxf(knob*.7,engagement))
        draw_style_box(style,Rect2(Vector2.ONE,size-Vector2.ONE*2))
        var font=ThemeDB.fallback_font; var caption="ON" if button_pressed else "OFF"
        draw_string(font,Vector2(16,size.y*.5+6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c7cee4").lerp(Color("7ae7f4"),knob))
        var track=Rect2(size.x-79,(size.y-32)*.5,64,32)
        var pill=StyleBoxFlat.new(); pill.set_corner_radius_all(16); pill.bg_color=Color("34364f").lerp(Color("2b9aaf"),knob)
        draw_style_box(pill,track)
        draw_circle(Vector2(track.position.x+16+knob*32,track.get_center().y),11,Color("b1aec6").lerp(Color("ebfdff"),knob))

# A selectable tile previewing a note shape.
# One color choice; an empty color is the "auto" swatch that follows the style.
class Swatch extends Button:
    var color_code = ""
    var selected = false:
        set(v): selected = v; queue_redraw()
    func _init(code: String) -> void:
        color_code = code; focus_mode = Control.FOCUS_ALL
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        custom_minimum_size = Vector2(52,52)
        tooltip_text = "Style default" if code=="" else "#"+code
        for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    func _draw() -> void:
        var center = size*.5; var r = minf(size.x,size.y)*.36
        if selected: draw_arc(center,r+6,0,TAU,40,Color("50daec"),3,true)
        elif is_hovered() or has_focus(): draw_arc(center,r+6,0,TAU,40,Color("a499e8"),2,true)
        if color_code=="":
            draw_circle(center,r,Color("1e1e1e"))
            draw_arc(center,r,0,TAU,40,Color(1,1,1,.5),1.5,true)
            var font = ThemeDB.fallback_font
            var w = font.get_string_size("A",HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
            draw_string(font,center+Vector2(-w*.5,7),"A",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
        else:
            draw_circle(center,r,Color.from_string(color_code,Color.WHITE))
            draw_arc(center,r,0,TAU,40,Color(1,1,1,.35),1.5,true)

# A highway style choice drawn as a tiny rail pair and band.
class StyleTile extends Button:
    var style_name = "gold"
    var selected = false:
        set(v): selected = v; queue_redraw()
    func _init(kind: String) -> void:
        style_name = kind; focus_mode = Control.FOCUS_ALL
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    func _draw() -> void:
        var box = StyleBoxFlat.new(); box.set_corner_radius_all(18)
        box.bg_color = Color("10313f") if selected else Color("121212")
        box.border_color = Color("50daec") if selected else Color("30364e")
        if is_hovered() or has_focus(): box.border_color=Color("a499e8")
        box.set_border_width_all(2 if selected else 1)
        draw_style_box(box,Rect2(Vector2.ZERO,size))
        var gold = style_name=="gold"
        var top = size.y*.14; var bottom = size.y*.66
        var a = Vector2(size.x*.40,top); var b = Vector2(size.x*.60,top)
        var c = Vector2(size.x*.86,bottom); var d = Vector2(size.x*.14,bottom)
        draw_colored_polygon(PackedVector2Array([a,b,c,d]),Color("050505") if gold else Color("151515"))
        var band_top = lerpf(top,bottom,.72)
        draw_colored_polygon(PackedVector2Array([a.lerp(d,.72),b.lerp(c,.72),c,d]),Color(1.0,.86,.34) if gold else Color(.60,.36,1.0,.85))
        for rail in [[a,d,Color("38baff")],[b,c,Color("b35cff")]]:
            if gold: draw_line(rail[0],rail[1],Color(1.0,.96,.88),6,true)
            else:
                draw_line(rail[0],rail[1],Color(rail[2],.3),8,true)
                draw_line(rail[0],rail[1],rail[2],2,true)
        var font = ThemeDB.fallback_font; var caption = style_name.to_upper()
        var width = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
        draw_string(font,Vector2((size.x-width)*.5,size.y*.88),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE if selected else Color(1,1,1,.65))

# Theme colors (fixed swatches) or adaptive colors (drawn from a cover-like gradient).
class ModeTile extends Button:
    var mode = "theme"
    var selected = false:
        set(v): selected = v; queue_redraw()
    func _init(kind: String) -> void:
        mode = kind; focus_mode = Control.FOCUS_ALL
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    func _draw() -> void:
        var box = StyleBoxFlat.new(); box.set_corner_radius_all(18)
        box.bg_color = Color("10313f") if selected else Color("121212")
        box.border_color = Color("50daec") if selected else Color("30364e")
        if is_hovered() or has_focus(): box.border_color=Color("a499e8")
        box.set_border_width_all(2 if selected else 1)
        draw_style_box(box,Rect2(Vector2.ZERO,size))
        var center = Vector2(size.x*.5,size.y*.38)
        if mode == "theme":
            var swatches = [Color(1.0,.96,.88),Color(1.0,.86,.34),Color("38baff"),Color("b35cff")]
            for i in swatches.size(): draw_circle(center+Vector2((i-1.5)*30,0),11,swatches[i])
        else:
            # A small "artwork" whose colors flow into the swatches beside it.
            var art = Rect2(center-Vector2(62,20),Vector2(40,40))
            draw_polygon(PackedVector2Array([art.position,art.position+Vector2(art.size.x,0),art.end,art.position+Vector2(0,art.size.y)]),
                PackedColorArray([Color("ff7a59"),Color("ffd166"),Color("7b2cbf"),Color("e0457b")]))
            draw_line(center+Vector2(-14,0),center+Vector2(2,0),Color(1,1,1,.7),2,true)
            for i in 3: draw_circle(center+Vector2(18+i*24,0),9,[Color("ff7a59"),Color("ffd166"),Color("e0457b")][i])
        var font = ThemeDB.fallback_font; var caption = mode.to_upper()
        var width = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
        draw_string(font,Vector2((size.x-width)*.5,size.y*.86),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE if selected else Color(1,1,1,.65))

class ShapeTile extends Button:
    var shape = "rectangle"
    var selected = false:
        set(v): selected = v; queue_redraw()
    var selected_amount=0.0
    func _process(delta: float) -> void:
        if not is_visible_in_tree(): return
        selected_amount=lerpf(selected_amount,1.0 if selected else 0.0,1-exp(-delta*16)); queue_redraw()
    func _init(kind: String) -> void:
        shape = kind; focus_mode = Control.FOCUS_ALL
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    func _draw() -> void:
        var style = StyleBoxFlat.new(); style.set_corner_radius_all(18)
        style.bg_color = Color("121212").lerp(Color("10313f"),selected_amount)
        style.border_color = Color("30364e").lerp(Color("50daec"),selected_amount)
        if is_hovered() or has_focus(): style.border_color=Color("a499e8")
        style.set_border_width_all(2 if selected else 1)
        draw_style_box(style,Rect2(Vector2.ZERO,size))
        var center = Vector2(size.x*.5,size.y*.42)
        var tint = Color("38baff")
        if shape == "circle":
            # Preview the raised puck and white/cyan rim used on the highway.
            draw_set_transform(center,0,Vector2(1,.42))
            var r = size.x*.25
            draw_circle(Vector2.ZERO,r*1.18,Color(tint,.14))
            draw_circle(Vector2(0,r*.20),r,Color("063a9c"))
            draw_arc(Vector2(0,r*.20),r*.96,0,TAU,48,Color(tint,.9),r*.045,true)
            draw_circle(Vector2.ZERO,r,Color("0750cf"))
            draw_arc(Vector2.ZERO,r*.89,0,TAU,48,Color(tint,.8),r*.095,true)
            draw_arc(Vector2.ZERO,r*.94,0,TAU,48,Color.WHITE,r*.055,true)
            draw_set_transform(Vector2.ZERO)
        else:
            var bar = Rect2(center-Vector2(size.x*.3,size.y*.08),Vector2(size.x*.6,size.y*.16))
            var glow = StyleBoxFlat.new(); glow.set_corner_radius_all(int(bar.size.y*.5)); glow.bg_color = Color(tint,.18)
            draw_style_box(glow,bar.grow(size.y*.04))
            var body = StyleBoxFlat.new(); body.set_corner_radius_all(int(bar.size.y*.35)); body.bg_color = tint.lerp(Color.WHITE,.25)
            body.border_color = Color.WHITE; body.set_border_width_all(2)
            draw_style_box(body,bar)
        var font = ThemeDB.fallback_font
        var caption = shape.to_upper()
        var font_size = 18
        var width = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
        draw_string(font,Vector2((size.x-width)*.5,size.y*.86),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE if selected else Color(1,1,1,.65))


var canvas: Control
var page_host: Panel
var pages: Dictionary={}
var nav_buttons: Dictionary={}
var selected_page="gameplay"
var page_title: Label
var page_hint: Label
var page_tween: Tween
var sizing_inputs: Dictionary={}
var effect_inputs: Dictionary={}
var stage_effect_switches: Dictionary={}
var authoring_switches: Dictionary={}
var speed_button: Button
var back_button: Button
var subtab_buttons: Dictionary={}
var selected_sections: Dictionary={}
var trail_style_input: OptionButton
const PAGE_NAMES={"gameplay":"Gameplay","audio":"Audio & sync","visuals":"Visual effects","editor":"Editor preferences"}
const SUBPAGES={"gameplay":{"play":"Play","browsing":"Browsing"},"audio":{"timing":"Timing","headset":"Headset"},"visuals":{"highway":"Highway","notes":"Notes","hits":"Hit effects","stage":"Stage effects","colors":"Colors"},"editor":{"recording":"Recording","guides":"Guides & audio"}}
const SUBPAGE_HINTS={"colors":"Choose Theme in Highway to use custom colors. Adaptive keeps your choices saved.","play":"Tune how notes travel while you play.","browsing":"Choose how the song library behaves.","timing":"Match the judgment timing to your music.","headset":"Compensate for wireless audio delay.","highway":"Choose the rail style, colors, and viewing angle.","notes":"Choose note shapes, trail styles, and sizes.","hits":"Tune hit feedback and particle intensity.","stage":"Choose your stage atmosphere. Combine effects freely.","recording":"Personal recording aids and playback preferences.","guides":"Listen for the rhythm while you create charts."}
const PAGE_HINTS={"gameplay":"Tune your highway and browsing experience.","audio":"Match your taps to the music and your headset.","visuals":"Customize the highway, note sizes and stage effects.","editor":"Personal preferences for every chart you create."}

func style(fill: Color=Color("101010"),edge: Color=Color("2c2d44"),radius: int=22) -> StyleBoxFlat:
    var box=StyleBoxFlat.new(); box.bg_color=fill; box.border_color=edge; box.set_corner_radius_all(radius); box.set_border_width_all(1); return box
func place(node: Control,parent: Control,x: float,y: float,w: float,h: float) -> void:
    parent.add_child(node); node.position=Vector2(x,y); node.size=Vector2(w,h)
func label(parent: Node,value: String,font_size: int=20,tint: Color=TEXT) -> Label:
    var n=Label.new(); parent.add_child(n); n.text=value
    font_size=roundi(font_size*1.15)
    n.add_theme_font_size_override("font_size",font_size); n.add_theme_color_override("font_color",tint)
    n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; n.mouse_filter=Control.MOUSE_FILTER_IGNORE
    n.custom_minimum_size.y=font_size+8
    n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    return n
func action(parent: Node,value: String,callback: Callable,primary: bool=false) -> Button:
    var n=Action.new(); n.text=value; n.primary=primary; n.caption_size=23
    n.custom_minimum_size=Vector2(0,84); parent.add_child(n)
    n.pressed.connect(func(): if not Action.was_dragged(n): callback.call())
    return n
func connect_switch(control: Switch,callback: Callable) -> void:
    control.toggled.connect(func(on):
        if Action.was_dragged(control): control.set_pressed_no_signal(not on)
        else: callback.call(on))
func row(parent: Node,title: String,hint: String,height: float=132) -> PanelContainer:
    var panel=PanelContainer.new(); parent.add_child(panel); panel.custom_minimum_size=Vector2(0,height)
    panel.add_theme_stylebox_override("panel",style(Color("141414"),Color("292c43"),18))
    var margin=MarginContainer.new(); panel.add_child(margin)
    for edge in ["left","right"]: margin.add_theme_constant_override("margin_"+edge,24)
    for edge in ["top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
    var line=HBoxContainer.new(); margin.add_child(line); line.add_theme_constant_override("separation",20)
    var captions=VBoxContainer.new(); line.add_child(captions); captions.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    captions.size_flags_vertical=Control.SIZE_SHRINK_CENTER; captions.add_theme_constant_override("separation",6)
    label(captions,title,22)
    var sub=label(captions,hint,15,Color("a7aac6")); sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    sub.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    panel.set_meta("control_line",line); return panel
func add_control(panel: PanelContainer,control: Control,width: float=316) -> void:
    var line: HBoxContainer=panel.get_meta("control_line"); line.add_child(control)
    control.custom_minimum_size=Vector2(width,72); control.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    if control is Stepper: control.readout.add_theme_font_size_override("font_size",28)
func page(category: String,key: String) -> VBoxContainer:
    if not pages.has(category):
        var wrapper=Control.new(); page_host.add_child(wrapper); wrapper.position=Vector2(28,105); wrapper.size=Vector2(1044,461)
        pages[category]={"root":wrapper,"sections":{}}
        subtab_buttons[category]={}
        var count=SUBPAGES[category].size(); var width=(1044.0-(count-1)*12)/count; var index=0
        for section_key in SUBPAGES[category]:
            var id: String=section_key
            var tab=action(wrapper,SUBPAGES[category][id],func(): show_section(id))
            tab.custom_minimum_size=Vector2.ZERO; tab.position=Vector2(index*(width+12),0); tab.size=Vector2(width,64); tab.caption_size=22
            subtab_buttons[category][id]=tab; index+=1
    var content=Control.new(); pages[category].root.add_child(content); content.position=Vector2(0,78); content.size=Vector2(1044,383)
    var title=label(content,SUBPAGES[category][key],24); title.position=Vector2.ZERO; title.size=Vector2(1044,34)
    var hint=label(content,SUBPAGE_HINTS[key],14,Color("a7aac6")); hint.position=Vector2(0,36); hint.size=Vector2(1044,24)
    var scroll=ScrollContainer.new(); content.add_child(scroll); scroll.position=Vector2(0,68); scroll.size=Vector2(1044,315)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.scroll_deadzone=12
    var drag=preload("res://scripts/song_list_scroll.gd").new(); drag.name="DragScroll"; drag.scroll=scroll; scroll.add_child(drag)
    var rail=StyleBoxFlat.new(); rail.bg_color=Color(0,0,0,0); scroll.get_v_scroll_bar().add_theme_stylebox_override("scroll",rail)
    var grip=style(Color(.6,.55,.8,.22),Color(0,0,0,0),3)
    for state in ["grabber","grabber_highlight","grabber_pressed"]: scroll.get_v_scroll_bar().add_theme_stylebox_override(state,grip)
    scroll.get_v_scroll_bar().custom_minimum_size.x=5
    var items=VBoxContainer.new(); scroll.add_child(items); items.size_flags_horizontal=Control.SIZE_EXPAND_FILL; items.add_theme_constant_override("separation",12)
    pages[category].sections[key]={"root":content,"list":items,"scroll":scroll}
    return items
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    var background=ColorRect.new(); add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var mat=preload("res://scripts/background_motion.gd").attach(background,preload("res://scripts/song_browser_background.gdshader"))
    mat.set_shader_parameter("ambience",Color(0.116,0.116,0.116))
    preload("res://scripts/screen_backdrop.gd").video(self,0.17,.5)  # violet stage
    canvas=Control.new(); add_child(canvas); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var theme_local=Theme.new(); theme_local.default_font=ThemeDB.fallback_font; canvas.theme=theme_local
    for type in ["Label","Button","PopupMenu"]: theme_local.set_font("font",type,ThemeDB.fallback_font)
    resized.connect(layout); game.safe_area_changed.connect(layout); layout()
    back_button=action(canvas,"‹",game.close_lobby_settings); back_button.caption_size=34; back_button.position=Vector2(48,36); back_button.size=Vector2(84,84)
    var eyebrow=label(canvas,"G A M E   S E T T I N G S",12,ACCENT); eyebrow.position=Vector2(144,33); eyebrow.size=Vector2(600,24)
    var heading=label(canvas,"Make it your rhythm",36); heading.position=Vector2(144,57); heading.size=Vector2(700,52)
    var save=label(canvas,"Changes save automatically",15,Color("a7aac6")); save.position=Vector2(1100,53); save.size=Vector2(308,32); save.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    var rail=Panel.new(); place(rail,canvas,48,168,232,590); rail.add_theme_stylebox_override("panel",style())
    var y=26
    for key in PAGE_NAMES:
        var n=action(rail,PAGE_NAMES[key],func(): show_page(key)); n.caption_size=21
        n.position=Vector2(14,y); n.size=Vector2(204,84); nav_buttons[key]=n; y+=94
    var scope=label(rail,"GLOBAL PREFERENCES",11,Color("7acbda")); scope.position=Vector2(22,491); scope.size=Vector2(194,24)
    var scope_hint=label(rail,"Applies across all songs\nand chart versions.",14,Color("a7aac6")); scope_hint.position=Vector2(22,520); scope_hint.size=Vector2(194,52)
    page_host=Panel.new(); place(page_host,canvas,308,168,1100,590); page_host.add_theme_stylebox_override("panel",style())
    page_title=label(page_host,"",28); page_title.position=Vector2(28,23); page_title.size=Vector2(1044,39)
    page_hint=label(page_host,"",16,Color("a7aac6")); page_hint.position=Vector2(28,66); page_hint.size=Vector2(1044,28)
    build_gameplay(page("gameplay","play"),page("gameplay","browsing"))
    build_audio(page("audio","timing"),page("audio","headset"))
    build_highway(page("visuals","highway")); build_notes(page("visuals","notes"))
    build_hit_effects(page("visuals","hits")); build_stage_effects(page("visuals","stage")); build_colors(page("visuals","colors"))
    build_editor(page("editor","recording"),page("editor","guides"))
    show_page("gameplay",false); refresh()
    visibility_changed.connect(func():
        if is_visible_in_tree(): animate_page())
func layout() -> void:
    if not canvas: return
    var available=game.safe_rect_for(self)
    var k=maxf(.1,minf(available.size.x/1456.0,available.size.y/819.0)); canvas.scale=Vector2.ONE*k
    canvas.position=available.position+(available.size-Vector2(1456,819)*k)*.5; canvas.size=Vector2(1456,819)
func show_page(key: String,animated: bool=true) -> void:
    if not pages.has(key): return
    if page_tween: page_tween.kill()
    for name in pages:
        pages[name].root.visible=name==key
        nav_buttons[name].set_selected(name==key)
    selected_page=key; page_title.text=PAGE_NAMES[key]
    var selected: String=selected_sections.get(key,SUBPAGES[key].keys()[0])
    show_section(selected,animated)
func show_section(key: String,animated: bool=true) -> void:
    if not pages.has(selected_page) or not pages[selected_page].sections.has(key): return
    if page_tween: page_tween.kill()
    selected_sections[selected_page]=key
    for name in pages[selected_page].sections:
        var data=pages[selected_page].sections[name]
        data.root.visible=name==key; data.root.position=Vector2(0,78); data.root.modulate.a=1
        subtab_buttons[selected_page][name].set_selected(name==key)
    var active=pages[selected_page].sections[key]
    pages[selected_page]["list"]=active.list; pages[selected_page]["scroll"]=active.scroll
    page_hint.text="SETTINGS / "+PAGE_NAMES[selected_page].to_upper()+" / "+SUBPAGES[selected_page][key].to_upper()
    if animated: animate_page()
func animate_page() -> void:
    if not pages.has(selected_page) or not selected_sections.has(selected_page): return
    if page_tween: page_tween.kill()
    var root: Control=pages[selected_page].sections[selected_sections[selected_page]].root
    root.position.x=12; root.modulate.a=0
    page_tween=create_tween().set_parallel(true)
    page_tween.tween_property(root,"position:x",0,.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    page_tween.tween_property(root,"modulate:a",1,.22)
func build_gameplay(items: VBoxContainer,browsing: VBoxContainer) -> void:
    note_speed_input=Stepper.new(.5,3,.25,game.note_speed,"×",2)
    add_control(row(items,"Note speed","Same feel on every song: notes take 2.6 s ÷ speed to reach the line."),note_speed_input)
    note_speed_input.value_changed.connect(game.change_note_speed)
    var match_display=Switch.new(); add_control(row(items,"Match display refresh rate","Run at your screen's own rate (%d Hz) for the smoothest motion." % game.display_refresh_rate()),match_display,152)
    var fps=Stepper.new(30,120,30,float(game.frame_rate_setting() if game.frame_rate_setting()>0 else 60),"fps",0)
    add_control(row(items,"Frame rate limit","Used when matching the display is off."),fps)
    match_display.button_pressed=game.frame_rate_setting()<=0; fps.editable=not match_display.button_pressed
    connect_switch(match_display,func(on): fps.editable=not on; game.change_frame_rate(0 if on else roundi(fps.value)))
    fps.value_changed.connect(func(v): if not match_display.button_pressed: game.change_frame_rate(roundi(v)))
    extras_switch(items,"judgement","Easy judging","Wider timing windows for PERFECT, GREAT and GOOD.",true)
    extras_switch(items,"touch_assist","Touch assist","A tap just beside an empty lane still hits the nearby note.")
    extras_switch(items,"lane_hints","Lane lines","Show faint lane lines while you play.")
    extras_switch(items,"window_preview","Timing window preview","Show the PERFECT and GREAT zones on the line during the countdown.")
    extras_switch(items,"mirror","Mirror","Flip every chart left to right.")
    extras_switch(items,"hidden","Hidden","Notes fade out as they near the line.")
    extras_switch(items,"sudden","Sudden","Notes appear late, partway down the highway.")
    song_preview_toggle=Switch.new(); add_control(row(browsing,"Song previews","Play a short preview while browsing songs."),song_preview_toggle,152)
    song_preview_toggle.button_pressed=game.lobby.preview_enabled; connect_switch(song_preview_toggle,game.lobby.set_preview_enabled)
# A switch bound to a gameplay_extras setting. judgement maps on/off to "easy"/"normal".
func extras_switch(items: VBoxContainer,key: String,title: String,hint: String,judgement: bool=false) -> Switch:
    var control=Switch.new(); add_control(row(items,title,hint),control,152)
    var value=game.extras.settings.get(key,false)
    control.button_pressed=(str(value)=="easy") if judgement else bool(value)
    connect_switch(control,func(on): game.extras.set_setting(key,("easy" if on else "normal") if judgement else on))
    return control
func build_audio(items: VBoxContainer,headset: VBoxContainer) -> void:
    var hits=Stepper.new(0,100,10,float(game.extras.settings.hit_volume)*100,"%",0)
    add_control(row(items,"Hit sounds","A soft tick on every hit. 0% turns it off."),hits)
    hits.value_changed.connect(func(v): game.extras.set_setting("hit_volume",v/100))
    extras_switch(items,"vibration","Vibration","A short buzz on PERFECT hits and flicks.")
    var music=Stepper.new(0,100,10,game.menu_music.volume*100,"%",0)
    add_control(row(items,"Menu music","Background music on the menus. 0% turns it off."),music)
    music.value_changed.connect(func(v): game.menu_music.set_volume(v/100))
    timing_input=Stepper.new(-200,200,5,game.timing_ms," ms",0)
    add_control(row(items,"Timing offset","Move notes earlier (−) or later (+) to match the music."),timing_input)
    timing_input.value_changed.connect(game.change_audio_offset)
    bluetooth_toggle=Switch.new(); add_control(row(headset,"Bluetooth headset mode","Compensate for wireless audio delay."),bluetooth_toggle,152)
    bluetooth_toggle.button_pressed=game.bluetooth_mode; connect_switch(bluetooth_toggle,game.change_bluetooth_mode)
    bluetooth_latency_input=Stepper.new(0,600,5,game.bluetooth_latency_ms," ms",0)
    add_control(row(headset,"Extra headset delay","Enable headset mode to adjust its additional delay."),bluetooth_latency_input)
    bluetooth_latency_input.editable=game.bluetooth_mode; bluetooth_latency_input.value_changed.connect(game.change_bluetooth_latency)
    action(items,"OPEN AUDIO SYNC HELPER  →",game.open_sync_helper,true)
func sizing_row(items: VBoxContainer,key: String,title: String,hint: String,low: float,high: float,current: float) -> void:
    var control=Stepper.new(low,high,5,current*100,"%",0); sizing_inputs[key]=control
    add_control(row(items,title,hint),control)
    control.value_changed.connect(func(v): game.change_note_sizing(key,v/100))
func swatch_row(items: VBoxContainer,key: String,title: String,hint: String,list: Array) -> void:
    var panel=row(items,title,hint,128)
    var line=HBoxContainer.new(); line.add_theme_constant_override("separation",4)
    add_control(panel,line,LOOK_COLORS.size()*56)
    for code in LOOK_COLORS:
        var swatch=Swatch.new(code); line.add_child(swatch); list.append(swatch)
        swatch.pressed.connect(func(): if not Action.was_dragged(swatch): game.change_highway_look(key,code))
# A heading that starts a group of related settings on a page.
func section(items: VBoxContainer,title: String) -> void:
    var spacer=Control.new(); spacer.custom_minimum_size.y=6; items.add_child(spacer)
    var heading=label(items,title,13,ACCENT); heading.custom_minimum_size.y=26
func build_highway(items: VBoxContainer) -> void:
    highway_angle_input=Stepper.new(18,44,2,game.highway_angle,"°",0)
    add_control(row(items,"Highway angle","Choose how flat or steep the highway looks."),highway_angle_input)
    highway_angle_input.value_changed.connect(game.change_highway_angle)
    var preview=preload("res://scripts/highway_look_preview.gd").new(); preview.game=game; items.add_child(preview)
    var styles=row(items,"Highway style","Glossy gold rails or glowing neon rails.",166)
    var tile_row=HBoxContainer.new(); tile_row.add_theme_constant_override("separation",12)
    add_control(styles,tile_row,440)
    for kind in ["gold","neon"]:
        var tile=StyleTile.new(kind); tile_row.add_child(tile); tile.custom_minimum_size=Vector2(208,136)
        tile.pressed.connect(func(): if not Action.was_dragged(tile): game.change_highway_look("style",kind))
        style_tiles[kind]=tile
    var modes=row(items,"Colors","Theme keeps the style's colors. Adaptive takes them from the song's artwork.",148)
    var mode_row=HBoxContainer.new(); mode_row.add_theme_constant_override("separation",12)
    add_control(modes,mode_row,440)
    for kind in ["theme","adaptive"]:
        var tile=ModeTile.new(kind); mode_row.add_child(tile); tile.custom_minimum_size=Vector2(208,120)
        tile.pressed.connect(func(): if not Action.was_dragged(tile): game.change_highway_look("colors",kind))
        color_mode_tiles[kind]=tile
    swatch_row(items,"rail_color","Rail color","A follows the colors above.",rail_swatches)
    swatch_row(items,"band_color","Judgment band color","Where notes are hit.",band_swatches)
    highway_opacity_input=Stepper.new(30,160,10,game.highway_opacity*100,"%",0)
    add_control(row(items,"Highway darkness","How much of the stage shows through the highway."),highway_opacity_input)
    highway_opacity_input.value_changed.connect(func(v): game.change_highway_look("opacity",v/100))
    action(items,"RESET HIGHWAY LOOK",game.reset_highway_look)
func build_colors(items: VBoxContainer) -> void:
    action(items,"USE CUSTOM COLORS",func(): game.change_highway_look("colors","theme"),true)
    var rail_hint=label(items,"Choose any color for each element. Defaults follow the theme; rail glow follows the rails.",15,MUTED)
    rail_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for group in SynkGameplayColors.GROUPS:
        section(items,group)
        for key in SynkGameplayColors.GROUPS[group]:
            var panel=row(items,SynkGameplayColors.GROUPS[group][key],"Follows the rail color." if key=="glow" else "Choose a color, or restore the theme default.",104)
            var controls=HBoxContainer.new(); controls.add_theme_constant_override("separation",12); add_control(panel,controls,316)
            var picker=ColorPickerButton.new(); picker.custom_minimum_size=Vector2(132,72); picker.edit_alpha=false
            controls.add_child(picker); color_pickers[key]=picker
            picker.color_changed.connect(func(color): game.change_gameplay_color(key,color.to_html(false)))
            var reset=action(controls,"FOLLOW RAIL" if key=="glow" else "DEFAULT",func(): game.change_gameplay_color(key,""))
            reset.custom_minimum_size=Vector2(172,72); reset.caption_size=17; color_reset_buttons[key]=reset
    rail_glow_input=Stepper.new(0,30,1,game.rail_glow_opacity*100,"%",0)
    add_control(row(items,"Highway backdrop glow","Soft color across the top and outer rails, gently following the beat."),rail_glow_input)
    rail_glow_input.value_changed.connect(func(value): game.change_rail_glow_opacity(value/100))
    action(items,"RESET CUSTOM COLORS",game.reset_gameplay_colors)

func build_notes(items: VBoxContainer) -> void:
    var shapes=row(items,"Note shape","Choose the note style you see on the highway.",166)
    var tile_row=HBoxContainer.new(); tile_row.add_theme_constant_override("separation",12)
    add_control(shapes,tile_row,440)
    for kind in ["rectangle","circle"]:
        var tile=ShapeTile.new(kind); tile_row.add_child(tile); tile.custom_minimum_size=Vector2(208,136)
        tile.pressed.connect(func(): if not Action.was_dragged(tile): game.change_note_shape(kind))
        shape_tiles[kind]=tile
    var preview=preload("res://scripts/note_appearance_preview.gd").new(); preview.game=game; items.add_child(preview)
    sizing_row(items,"note_size","Note size","Adjust the visual size of note heads.",60,125,game.note_size)
    var trail=row(items,"Trail style","A filled band with round connectors at the points you add in the recorder.")
    trail_style_input=OptionButton.new(); trail_style_input.add_item("Neon trail"); trail_style_input.add_item("Solid ribbon")
    trail_style_input.add_theme_font_size_override("font_size",21); trail_style_input.get_popup().add_theme_font_size_override("font_size",21)
    trail_style_input.get_popup().add_theme_constant_override("v_separation",16)
    var picker_style=style(Color("121212"),Color("373c55"),14)
    picker_style.content_margin_left=18; picker_style.content_margin_right=18
    trail_style_input.add_theme_stylebox_override("normal",picker_style)
    var focus=picker_style.duplicate(); focus.border_color=ACCENT
    for state in ["focus","hover","pressed"]: trail_style_input.add_theme_stylebox_override(state,focus)
    add_control(trail,trail_style_input)
    trail_style_input.item_selected.connect(func(index): game.change_trail_style("solid" if index==1 else "neon"))
    sizing_row(items,"hold_trail_width","Hold & slide trail width","Adjust both trail widths independently of note size.",30,150,game.hold_trail_width)
    action(items,"RESET NOTE SIZES",func():
        for control in sizing_inputs.values(): control.value=100)
func effect_row(items: VBoxContainer,key: String,hint: String) -> void:
    var control=Stepper.new(0,100,5,game.features.effect(key)*100,"%",0); effect_inputs[key]=control
    add_control(row(items,key,hint,96),control)
    control.value_changed.connect(func(v): game.features.set_effect(key,v/100))
func build_hit_effects(items: VBoxContainer) -> void:
    effect_row(items,"Hit flashes","Set the brightness of hit flashes and impact rings.")
    effect_row(items,"Particles","Set particle density for hit sparks and ambient motes.")
    action(items,"RESET HIT EFFECTS",func():
        for key in ["Hit flashes","Particles"]: effect_inputs[key].value=100)
func build_stage_effects(items: VBoxContainer) -> void:
    for key in game.features.OPTIONAL_STAGE_EFFECTS:
        var control=Switch.new(); stage_effect_switches[key]=control
        var hint="Light packets travel toward the judgment line." if key=="Flowing edge energy" else "Gentle color drifts outside the highway."
        add_control(row(items,key,hint,96),control,152)
        control.set_pressed_no_signal(game.features.effect(key)>0)
        connect_switch(control,func(on): game.features.set_effect(key,1.0 if on else 0.0))
    effect_row(items,"Lasers","Control the original ambient laser streaks.")
    effect_row(items,"Background brightness","Adjust artwork brightness behind the highway.")
    action(items,"RESET STAGE EFFECTS",func():
        for key in ["Lasers","Background brightness"]: effect_inputs[key].value=100
        for key in stage_effect_switches:
            game.features.set_effect(key,game.features.effect_default(key)); stage_effect_switches[key].set_pressed_no_signal(false))
func editor_switch(items: VBoxContainer,key: String,title: String,hint: String,value: bool,callback: Callable) -> Switch:
    var control=Switch.new(); add_control(row(items,title,hint),control,152)
    control.button_pressed=value; connect_switch(control,callback); authoring_switches[key]=control; return control
func build_editor(items: VBoxContainer,guides: VBoxContainer) -> void:
    metronome_toggle=editor_switch(guides,"metronome","Metronome","Click to the beat while editing or recording.",game.beat_clock.enabled,func(on):
        if game.beat_clock.enabled!=on: game.beat_clock.toggle())
    editor_switch(guides,"mr","MR vocal reduction","Reduce center vocals while mapping the rhythm.",game.mr.enabled,func(on):
        if game.mr.enabled!=on: game.mr.toggle())
    editor_switch(items,"ghost","Ghost guides","See your existing notes while recording a new take.",game.ghost_recording,func(on):
        if game.ghost_recording!=on: game.toggle_ghost_recording())
    editor_switch(items,"lines","Alignment lines","Show note alignment guides in the recorder.",game.note_lines,func(on):
        if game.note_lines!=on: game.toggle_note_lines())
    speed_button=action(items,"RECORD SPEED  ·  "+str(game.record_speed)+"×",func():
        game.cycle_record_speed(); speed_button.text="RECORD SPEED  ·  "+str(game.record_speed)+"×")
    action(items,"RECORDER PREFERENCES  →",func(): game.recorder.show_setup(true))
func refresh() -> void:
    for key in color_pickers:
        var picker: ColorPickerButton=color_pickers[key]
        picker.disabled=game.highway_colors=="adaptive"
        picker.color=Color.from_string(str(game.gameplay_colors[key]),Color.WHITE) if game.gameplay_colors.has(key) else SynkGameplayColors.preview_default(game,key)
        color_reset_buttons[key].disabled=picker.disabled
        color_reset_buttons[key].set_selected(not game.gameplay_colors.has(key))
    if rail_glow_input: rail_glow_input.sync_value(game.rail_glow_opacity*100)
    if trail_style_input: trail_style_input.select(1 if game.trail_style=="solid" else 0)
    for kind in shape_tiles: shape_tiles[kind].selected=kind==game.note_shape
    for kind in style_tiles: style_tiles[kind].selected=kind==game.highway_style
    for kind in color_mode_tiles: color_mode_tiles[kind].selected=kind==game.highway_colors
    for swatch in rail_swatches: swatch.selected=swatch.color_code==game.rail_color and (game.highway_colors=="adaptive" or not game.gameplay_colors.has("rail"))
    for swatch in band_swatches: swatch.selected=swatch.color_code==game.band_color and (game.highway_colors=="adaptive" or not game.gameplay_colors.has("band"))
    if highway_opacity_input: highway_opacity_input.sync_value(game.highway_opacity*100)
    if not song_preview_toggle: return
    song_preview_toggle.set_pressed_no_signal(game.lobby.preview_enabled)
    metronome_toggle.set_pressed_no_signal(game.beat_clock.enabled)
    bluetooth_toggle.set_pressed_no_signal(game.bluetooth_mode); bluetooth_latency_input.editable=game.bluetooth_mode
    note_speed_input.sync_value(game.note_speed); highway_angle_input.sync_value(game.highway_angle)
    timing_input.sync_value(game.timing_ms); bluetooth_latency_input.sync_value(game.bluetooth_latency_ms)
    for key in sizing_inputs: sizing_inputs[key].sync_value((game.note_size if key=="note_size" else game.hold_trail_width)*100)
    for key in effect_inputs: effect_inputs[key].sync_value(game.features.effect(key)*100)
    for key in stage_effect_switches: stage_effect_switches[key].set_pressed_no_signal(game.features.effect(key)>0)
    authoring_switches.mr.set_pressed_no_signal(game.mr.enabled)
    authoring_switches.ghost.set_pressed_no_signal(game.ghost_recording)
    authoring_switches.lines.set_pressed_no_signal(game.note_lines)
    speed_button.text="RECORD SPEED  ·  "+str(game.record_speed)+"×"
