extends "res://scripts/song_browser_button.gd"
# The lobby Play note's polished layers, fitted to the song action's rectangle.
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
var time = 0.0

func _ready() -> void:
    primary=false
    super._ready()
    primary=true

func _process(delta: float) -> void:
    super._process(delta)
    time+=delta

func plate(rect: Rect2, edge: Color, light: Color, radius: float) -> void:
    for i in 17:
        var t=float(i)/16.0
        var box=StyleBoxFlat.new()
        box.bg_color=edge.lerp(light,t)
        box.set_corner_radius_all(roundi(maxf(2,radius-t*3)))
        var inset=Vector2(2,3)*t
        draw_style_box(box,Rect2(rect.position+inset,rect.size-inset*2))

func _draw() -> void:
    # The song's main action: the cream primary plate, with a drawn play icon.
    var Soft=preload("res://scripts/soft_button.gd")
    Soft.draw_plate(self,size,"primary",hover_amount,press_amount,0.0,disabled)
    preload("res://scripts/ui_icons.gd").draw_caption(self,Rect2(0,2*press_amount-1,size.x,size.y),text,BOLD,caption_size,Soft.text_color("primary",0.0,disabled))
