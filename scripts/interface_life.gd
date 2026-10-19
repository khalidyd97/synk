extends Control

# Mounted only on interface scopes. Gameplay and the highway never receive a driver.
const Motion=preload("res://scripts/menu_button_motion.gd")
var motion=Motion.new()
var target: Control
var engagement=0.0
var selected_property=false
var primary_property=false
var variant_property=false
var slanted=false
var field=false

static func mount(scope: Node) -> void:
    watch(scope)

static func watch(node: Node) -> void:
    if not is_instance_valid(node) or node.has_meta("interface_life_watched") or node.has_meta("interface_life_decoration"): return
    node.set_meta("interface_life_watched",true)
    node.child_entered_tree.connect(func(child): watch.call_deferred(child))
    if node is Control and (node is BaseButton or node is LineEdit or node is TextEdit or node is PanelContainer or node is Panel):
        var decorate=true
        for property in node.get_property_list():
            if property.name=="menu_motion" and node.menu_motion: decorate=false
        if node.get_script()==load("res://scripts/art_button.gd"): decorate=false
        if decorate:
            var life=load("res://scripts/interface_life.gd").new()
            life.name="InterfaceLife"; life.target=node; life.set_meta("interface_life_decoration",true); node.add_child(life)
    for child in node.get_children(): watch(child)

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE; focus_mode=Control.FOCUS_NONE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for property in target.get_property_list():
        selected_property=selected_property or property.name=="selected"
        primary_property=primary_property or property.name=="primary"
        variant_property=variant_property or property.name=="variant"
    slanted=target.get_script()==load("res://scripts/neon_action.gd")
    field=target is LineEdit or target is TextEdit
    if target is BaseButton: target.button_down.connect(func(): if not target.disabled: motion.press=1.0)
    target.visibility_changed.connect(sync_visibility); sync_visibility()

func sync_visibility() -> void:
    set_process(target.is_visible_in_tree())
    if not target.is_visible_in_tree(): engagement=0; motion.press=0
    else:
        modulate.a=0
        var tween=create_tween(); tween.tween_property(self,"modulate:a",1.0,.28)

func _process(delta: float) -> void:
    var disabled=target is BaseButton and target.disabled
    var engaged=target.has_focus() or (target is BaseButton and target.is_hovered())
    engagement=lerpf(engagement,1.0 if engaged and not disabled else 0.0,1-exp(-delta*12))
    motion.advance(delta,not disabled)
    queue_redraw()

func _draw() -> void:
    if not target or size.x<12 or size.y<12: return
    if target is BaseButton and target.disabled: return
    var selected=bool(target.get("selected")) if selected_property else (target is BaseButton and target.toggle_mode and target.button_pressed)
    var primary=bool(target.get("primary")) if primary_property else false
    var variant=str(target.get("variant")) if variant_property else ""
    primary=primary or variant in ["primary","record"]
    var accent=Color("ff6489") if variant in ["record","danger"] else Color("70dbe9")
    var strength=maxf(engagement,.45 if selected else (.25 if primary else 0.0))
    if field:
        if engagement>.005:
            var reach=size.x*.5*engagement
            draw_line(Vector2(size.x*.5-reach,size.y-3),Vector2(size.x*.5+reach,size.y-3),Color(accent,engagement*.8),2,true)
    elif target is BaseButton:
        if slanted:
            var width=size.x*.76; var x=size.x*.12+fposmod(motion.phase*.3,1.0)*width
            if strength>.005: draw_line(Vector2(maxf(size.x*.12,x-20),size.y*.85),Vector2(x,size.y*.85),Color(accent,strength),2,true)
        else: motion.paint(self,accent,strength,14)
    else:
        # Small moving edge lights keep panels alive without shifting their contents.
        var x=size.x*.1+fposmod(motion.phase*.09,1.0)*size.x*.8
        draw_line(Vector2(maxf(size.x*.1,x-32),2),Vector2(x,2),Color(accent,.18),1.5,true)
