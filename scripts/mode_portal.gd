extends Button
var kind="play"
var hover=0.0
var accent=Color("55ddff")
func _ready() -> void:
    text=""; focus_mode=Control.FOCUS_NONE; mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    tooltip_text="Choose a song and play" if kind=="play" else "Edit charts, import music, and record notes"
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    hover=move_toward(hover,1.0 if is_hovered() else 0.0,delta*5)
    queue_redraw()
func _draw() -> void:
    var inset=8.0; var cut=26.0
    var outline=PackedVector2Array([Vector2(cut,inset),Vector2(size.x-inset,inset),Vector2(size.x-inset,size.y-cut),Vector2(size.x-cut,size.y-inset),Vector2(inset,size.y-inset),Vector2(inset,cut)])
    draw_colored_polygon(outline,Color("081327").lerp(Color(accent*.22,1),hover))
    var border=outline.duplicate(); border.append(outline[0])
    draw_polyline(border,Color(accent,.6+hover*.4),2,true)
    draw_line(Vector2(cut+8,inset),Vector2(size.x*.52,inset),accent,4,true)
    draw_line(Vector2(size.x*.1,size.y*.89),Vector2(size.x*.9,size.y*.89),Color(accent,.25),2,true)
    draw_line(Vector2(size.x*.1,size.y*.89),Vector2(size.x*(.3+hover*.6),size.y*.89),accent,3,true)
    for i in 4:
        var x=size.x*.82+i*9
        draw_line(Vector2(x,22),Vector2(x-6,31),Color(accent,.55),2,true)
    var font=ThemeDB.fallback_font
    draw_string(font,Vector2(size.x*.10,size.y*.14),"01 / EXPERIENCE" if kind=="play" else "02 / CREATION",HORIZONTAL_ALIGNMENT_LEFT,-1,14,accent)
    var center=Vector2(size.x*.21,size.y*.38)
    var r=minf(size.x,size.y)*.135
    if kind=="play":
        draw_arc(center,r*1.35,-PI*.7,PI*.7,48,Color(accent,.3),2,true)
        draw_circle(center,r,Color(accent,.1))
        draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.32,-r*.54),center+Vector2(r*.62,0),center+Vector2(-r*.32,r*.54)]),accent)
    else:
        var rect=Rect2(center-Vector2(r,r),Vector2(r*2,r*2))
        draw_rect(rect,Color(accent,.12)); draw_rect(rect,accent,false,2)
        for i in 3:
            var x=rect.position.x+r*.5+i*r*.5
            draw_line(Vector2(x,rect.position.y+6),Vector2(x,rect.end.y-6),Color(accent,.35),1,true)
            draw_line(Vector2(x-7,center.y+(i-1)*r*.45),Vector2(x+7,center.y+(i-1)*r*.45),accent,6,true)
    for i in 15:
        var x=size.x*(.46+float(i)*.028)
        var h=(.08+.13*absf(sin(float(i)*.8)))*size.y
        if kind=="play": draw_line(Vector2(x,size.y*.38-h*.5),Vector2(x,size.y*.38+h*.5),Color(accent,.22+hover*.12),3,true)
        else:
            var y=size.y*(.26+float(i%5)*.055)
            draw_line(Vector2(x,y),Vector2(x+size.x*.018,y),Color(accent,.30),3,true)
    draw_string(font,Vector2(size.x*.10,size.y*.67),"PLAY" if kind=="play" else "CREATE CHARTS",HORIZONTAL_ALIGNMENT_LEFT,-1,int(minf(40,size.x*.075)),Color("f4efff"))
    draw_string(font,Vector2(size.x*.10,size.y*.80),"Find your track. Chase your best." if kind=="play" else "Build the rhythm. Make it yours.",HORIZONTAL_ALIGNMENT_LEFT,-1,int(minf(17,size.x*.033)),Color("b4a9ce"))
    draw_line(Vector2(size.x*.86,size.y*.66),Vector2(size.x*.91,size.y*.66),accent,2,true)
    draw_line(Vector2(size.x*.89,size.y*.63),Vector2(size.x*.91,size.y*.66),accent,2,true)
    draw_line(Vector2(size.x*.89,size.y*.69),Vector2(size.x*.91,size.y*.66),accent,2,true)
