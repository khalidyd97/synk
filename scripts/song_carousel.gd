extends Control
signal song_selected(index: int)
const Tile=preload("res://scripts/record_tile.gd")
var entries: Array=[]
var cards: Array=[]
var current=0
var shown=0.0
var drag_start=Vector2.ZERO
var dragging=false
var drag_origin=0.0
var drag_velocity=0.0
var last_drag=Vector2.ZERO
var last_drag_ms=0
var pointer_id=-2
var vertical_drag=false

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP; clip_contents=true
    resized.connect(layout_cards)
    visibility_changed.connect(func():
        if not is_visible_in_tree(): dragging=false; pointer_id=-2; drag_velocity=0)
func set_songs(value: Array,selected_id: String,game: Control) -> void:
    var previous_ids=entries.map(func(e): return str(e.id))
    var next_ids=value.map(func(e): return str(e.id))
    var same=previous_ids==next_ids
    var existing: Dictionary={}
    for card in cards: existing[str(card.get_meta("song_id"))]=card
    entries=value.duplicate(true); cards=[]
    var selected=0
    for i in entries.size():
        var entry=entries[i]; var id=str(entry.id)
        if id==selected_id: selected=i
        var tinted=id!="eclipse" and not game.has_custom_cover(id)
        var tint=game.cover_tint_for_id(id) if tinted else Color.WHITE
        var card=existing.get(id)
        if card==null:
            card=Tile.new(str(entry.title),str(entry.badge),game.cover_texture_for_id(id),tint)
            card.compact=true; add_child(card); card.mouse_filter=Control.MOUSE_FILTER_IGNORE
            card.set_meta("song_id",id)
        else:
            existing.erase(id); card.title_label.text=entry.title; card.badge_label.text=entry.badge
            card.cover_rect.texture=game.cover_texture_for_id(id); card.cover_rect.self_modulate=tint
        cards.append(card)
    for card in existing.values(): remove_child(card); card.queue_free()
    current=selected
    if not same:
        dragging=false; pointer_id=-2; drag_velocity=0; shown=float(current)
    layout_cards()
func select_id(id: String) -> void:
    for i in entries.size():
        if str(entries[i].id)==id: current=i; return
func choose(index: int) -> void:
    if entries.is_empty(): return
    var next=clampi(index,0,entries.size()-1)
    if next==current: return
    current=next; song_selected.emit(int(entries[current].index))
func step(direction: int) -> void:
    dragging=false; pointer_id=-2; drag_velocity=0
    choose(current+direction)
func _process(delta: float) -> void:
    if not is_visible_in_tree() or dragging: return
    shown=lerpf(shown,float(current),1-exp(-delta*14))
    if absf(shown-current)<.0005: shown=float(current)
    layout_cards()
func spacing() -> float: return maxf(1,minf(size.y-52,size.x*.43)*.83)
func layout_cards() -> void:
    var side=maxf(1,minf(size.y-52,size.x*.43))
    for i in cards.size():
        var offset=float(i)-shown; var card=cards[i]
        card.visible=absf(offset)<2.8
        if not card.visible: continue
        var emphasis=1-minf(absf(offset),1)*.24; var edge=side*emphasis
        var dimensions=Vector2(edge,edge+36)
        if card.size.distance_to(dimensions)>.1: card.size=dimensions
        card.position=Vector2(size.x*.5+offset*spacing()-edge*.5,size.y*.5-edge*.5+absf(offset)*12)
        card.modulate=Color(1,1,1,1-minf(absf(offset),2)*.28)
        card.selected=i==current; card.title_label.visible=absf(offset)>.5
        card.title_label.position=Vector2(12,card.cover_rect.position.y+card.cover_rect.size.y-34)
        card.title_label.size=Vector2(maxf(1,edge-24),28)
        card.z_index=10-int(absf(offset)*3)
func begin_drag(point: Vector2,id: int=-1) -> void:
    if dragging or entries.is_empty(): return
    dragging=true; pointer_id=id; drag_start=point; last_drag=point
    drag_origin=shown; drag_velocity=0; vertical_drag=false; last_drag_ms=Time.get_ticks_msec()
func move_drag(point: Vector2) -> void:
    if not dragging: return
    var travel=point-drag_start
    if absf(travel.y)>20 and absf(travel.y)>absf(travel.x)*1.3: vertical_drag=true
    if vertical_drag: return
    var now=Time.get_ticks_msec(); var dt=maxf(.008,float(now-last_drag_ms)/1000)
    if point.distance_to(last_drag)>.1:
        var velocity=-(point.x-last_drag.x)/spacing()/dt
        drag_velocity=lerpf(drag_velocity,velocity,.55)
        last_drag=point; last_drag_ms=now
    var raw=drag_origin-travel.x/spacing()
    shown=clampf(raw,0,entries.size()-1)
    if raw<0: shown=-minf(.25,-raw*.22)
    elif raw>entries.size()-1: shown=entries.size()-1+minf(.25,(raw-entries.size()+1)*.22)
    layout_cards()
func finish_drag(point: Vector2,canceled: bool=false) -> void:
    if not dragging: return
    move_drag(point); dragging=false; pointer_id=-2
    if canceled or vertical_drag: drag_velocity=0; return
    var distance=point.x-drag_start.x
    if absf(distance)>12:
        if Time.get_ticks_msec()-last_drag_ms>100: drag_velocity=0
        var target=roundi(shown+clampf(drag_velocity*.12,-.65,.65))
        if target==current and absf(distance)>spacing()*.18: target+=-1 if distance>0 else 1
        choose(target)
    else:
        var nearest=-1; var best=INF
        for i in cards.size():
            if cards[i].visible and Rect2(cards[i].position,cards[i].size).has_point(point):
                var delta=absf(point.x-(cards[i].position.x+cards[i].size.x*.5))
                if delta<best: best=delta; nearest=i
        if nearest>=0: choose(nearest)
    drag_velocity=0; accept_event()
func _gui_input(event: InputEvent) -> void:
    if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1: return
    if event is InputEventScreenTouch:
        if event.pressed: begin_drag(event.position,event.index)
        elif dragging and pointer_id==event.index: finish_drag(event.position,event.canceled)
    elif event is InputEventScreenDrag:
        if dragging and pointer_id==event.index: move_drag(event.position)
    elif event is InputEventMouseButton:
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed: step(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
        elif event.button_index==MOUSE_BUTTON_LEFT:
            if event.pressed: begin_drag(event.position)
            elif dragging and pointer_id==-1: finish_drag(event.position)
    elif event is InputEventMouseMotion and dragging and pointer_id==-1: move_drag(event.position)
    accept_event()
