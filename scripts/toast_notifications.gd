extends CanvasLayer
const COLORS={"info":Color("59dcea"),"success":Color("52e6ad"),"warning":Color("ffc96b"),"error":Color("ff728f")}
const HEADINGS={"info":"NOTICE","success":"DONE","warning":"CHECK","error":"ERROR"}
const MAX_VISIBLE=3
var game: Control
var overlay: Control
var items: Array=[]

class Icon extends Control:
    var tint=Color.WHITE
    var kind="info"
    func _draw():
        var c=size*.5
        draw_circle(c,18,Color(tint,.12)); draw_arc(c,18,0,TAU,40,Color(tint,.6),1.5,true)
        if kind=="success":
            draw_polyline(PackedVector2Array([c+Vector2(-8,0),c+Vector2(-2,6),c+Vector2(9,-7)]),tint,3,true)
        elif kind=="error":
            draw_line(c+Vector2(-6,-6),c+Vector2(6,6),tint,3,true)
            draw_line(c+Vector2(6,-6),c+Vector2(-6,6),tint,3,true)
        else:
            draw_line(c+Vector2(0,-8),c+Vector2(0,3),tint,3,true)
            draw_circle(c+Vector2(0,9),1.7,tint)

func _ready():
    layer=120
    overlay=Control.new(); overlay.name="ToastNotifications"; add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.theme=game.ui.theme
    set_process(false)

func severity(message: String) -> String:
    var text=message.to_lower()
    for phrase in ["could not","couldn't","cannot","invalid","failed","error","wrong song","do not fit","does not fit","would move","would leave","unsupported","not found","unable to"]:
        if phrase in text: return "error"
    for prefix in ["select ","choose ","copy a ","save or ","save your ","save before ","enter ","no ","all five ","this practice range has no"]:
        if text.begins_with(prefix): return "warning"
    for phrase in ["saved","stored","copied","pasted","duplicated","deleted","recovered","restored","imported","exported","kept","transformed","undone","cleared"]:
        if phrase in text: return "success"
    return "info"

func notify(message: String,kind: String="auto",seconds: float=-1.0):
    message=message.strip_edges()
    if message.is_empty(): return
    if kind=="auto" or not COLORS.has(kind): kind=severity(message)
    if not message.to_lower().begins_with("loading") and not message.to_lower().begins_with("importing"):
        clear_progress()
    var duration=seconds if seconds>0 else clampf(maxf(4.0 if kind in ["info","success"] else 6.0,message.length()/20.0+1.5),4,12)
    for item in items:
        if item.message==message and not item.hiding:
            item.remaining=duration; item.duration=duration; return
    if items.size()>=MAX_VISIBLE: dismiss(items.back(),false)
    var card=PanelContainer.new(); overlay.add_child(card); card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var tint: Color=COLORS[kind]
    var style=StyleBoxFlat.new(); style.bg_color=Color(.035,.045,.085,.97)
    style.border_color=Color(tint,.75); style.set_border_width_all(1); style.border_width_left=4
    style.set_corner_radius_all(16); style.shadow_color=Color(0,0,0,.45); style.shadow_size=14
    style.content_margin_left=16; style.content_margin_right=14; style.content_margin_top=14; style.content_margin_bottom=10
    card.add_theme_stylebox_override("panel",style)
    var column=VBoxContainer.new(); card.add_child(column); column.mouse_filter=Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation",10)
    var row=HBoxContainer.new(); column.add_child(row); row.mouse_filter=Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation",14)
    var icon=Icon.new(); row.add_child(icon); icon.kind=kind; icon.tint=tint
    icon.custom_minimum_size=Vector2(40,40); icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var words=VBoxContainer.new(); row.add_child(words); words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    words.mouse_filter=Control.MOUSE_FILTER_IGNORE; words.add_theme_constant_override("separation",5)
    var heading=Label.new(); words.add_child(heading); heading.text=HEADINGS[kind]
    heading.add_theme_font_size_override("font_size",13); heading.add_theme_color_override("font_color",tint)
    heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var body=Label.new(); words.add_child(body); body.text=message; body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size",20); body.add_theme_color_override("font_color",Color("f0f3ff"))
    body.custom_minimum_size.y=25; body.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var close=preload("res://scripts/settings_action.gd").new(); row.add_child(close)
    close.text="×"; close.caption_size=26; close.custom_minimum_size=Vector2(44,44); close.tooltip_text="Dismiss notification"
    var timer_track=Control.new(); column.add_child(timer_track); timer_track.custom_minimum_size.y=3
    timer_track.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var progress=ColorRect.new(); timer_track.add_child(progress); progress.color=Color(tint,.65)
    progress.mouse_filter=Control.MOUSE_FILTER_IGNORE; progress.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var item={"card":card,"message":message,"kind":kind,"duration":duration,"remaining":duration,"progress":progress,"hiding":false,"tween":null,"born":Engine.get_process_frames()}
    items.push_front(item); close.pressed.connect(dismiss.bind(item,true))
    var safe=available_area()
    card.position=Vector2(safe.position.x+(safe.size.x-minf(860,safe.size.x-32))*.5,safe.position.y+16)
    layout(0); card.modulate.a=0; card.position.y-=14
    item.tween=create_tween(); item.tween.tween_property(card,"modulate:a",1.0,.18)
    set_process(true)

func dismiss(item: Dictionary,animated: bool=true):
    if not items.has(item) or (item.hiding and animated): return
    if item.tween is Tween and item.tween.is_running(): item.tween.kill()
    if not animated:
        item.tween=null; items.erase(item); item.card.queue_free(); return
    item.hiding=true
    item.tween=create_tween(); item.tween.tween_property(item.card,"modulate:a",0.0,.18)
    item.tween.tween_callback(func():
        item.tween=null
        items.erase(item)
        if is_instance_valid(item.card): item.card.queue_free())

func clear_progress():
    for item in items.duplicate():
        if item.message.to_lower().begins_with("loading") or item.message.to_lower().begins_with("importing"):
            dismiss(item,false)

func available_area() -> Rect2:
    var area=game.safe_area_rect if game.safe_area_rect.has_area() else Rect2(Vector2.ZERO,game.size)
    if game.floating_text_input and game.floating_text_input.overlay.visible:
        area.size.y=maxf(100,minf(area.end.y,game.floating_text_input.panel.position.y-12)-area.position.y)
    return area

func layout(delta: float,immediate: bool=false):
    var safe=available_area()
    var width=minf(860,safe.size.x-32)
    var x=safe.position.x+(safe.size.x-width)*.5
    var y=safe.position.y+16
    var shown=0
    # Let container wrapping settle before deciding that older cards do not fit.
    var settled=items.is_empty() or Engine.get_process_frames()-int(items.front().born)>=3
    for item in items.duplicate():
        if item.hiding: continue
        var card: PanelContainer=item.card
        card.size.x=width
        card.size.y=maxf(88,card.get_combined_minimum_size().y)
        if settled and y+card.size.y>safe.end.y-8 and shown>0:
            dismiss(item,false); continue
        var target=Vector2(x,y)
        card.position=target if immediate else card.position.lerp(target,1.0-exp(-delta*18.0))
        y+=card.size.y+10
        shown+=1

func _process(delta: float):
    for item in items.duplicate():
        if item.hiding: continue
        item.remaining-=delta
        item.progress.anchor_right=clampf(item.remaining/item.duration,0,1)
        if item.remaining<=0: dismiss(item)
    layout(delta)
    if items.is_empty(): set_process(false)

func _exit_tree():
    for item in items:
        if item.tween is Tween and item.tween.is_running(): item.tween.kill()
        item.tween=null
    items.clear()
