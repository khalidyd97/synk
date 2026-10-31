extends RefCounted
# SYNK's drawn icon set: one rounded line weight, so icons look the same on every phone
# instead of depending on which font has a glyph. Buttons swap a leading text symbol
# ("●  RECORD", "‹", "☷  SONG LIST") for the matching icon through split().
const GLYPHS={"●":"record","✎":"edit","‹":"back","›":"forward","☷":"list","↶":"retry","⟲":"retry","↻":"retry",
	"▶":"play","⏸":"pause","⌕":"search","★":"star","⌂":"home","✕":"close","×":"close","+":"add","−":"minus","⚙":"settings"}

# [icon, text, trailing icon]. Letter-spaced captions ("S O N G") are joined back up.
static func split(caption: String) -> Array:
	var text=caption.strip_edges(); var icon=""; var trailing=""
	if text.length()>0 and GLYPHS.has(text[0]):
		var first=text[0]; var rest=text.substr(1).strip_edges()
		# Stepper "+"/"−", numbers ("−10") and "× SPEED" stay text; "+ NEW" and a lone "×" become icons.
		var keep=(first in ["+","−"] and (rest.is_empty() or rest[0].is_valid_int())) or (first=="×" and not rest.is_empty())
		if not keep: icon=GLYPHS[first]; text=rest
	if text.ends_with("→"): trailing="forward_arrow"; text=text.substr(0,text.length()-1).strip_edges()
	return [icon,unspace(text),trailing]

# "S O N G   L I S T" -> "SONG LIST"; ordinary text is unchanged.
static func unspace(text: String) -> String:
	var words=text.split("   ",false)
	var joined=PackedStringArray()
	for word in words:
		var letters=word.strip_edges().split(" ",false)
		var spaced=letters.size()>1 and Array(letters).all(func(part): return part.length()==1)
		joined.append("".join(letters) if spaced else word.strip_edges())
	return " ".join(joined)

static func draw(canvas: CanvasItem, kind: String, center: Vector2, size: float, color: Color) -> void:
	var r=size*.5; var w=maxf(1.6,size*.11); var c=center
	match kind:
		"record": canvas.draw_circle(c,r*.55,color)
		"edit":
			var a=c+Vector2(-r*.7,r*.7); var b=c+Vector2(r*.45,-r*.45)
			canvas.draw_line(a,b,color,w*1.6,true)
			canvas.draw_line(b+Vector2(-r*.2,-r*.2),b+Vector2(r*.2,r*.2),color,w,true)
			canvas.draw_line(a,a+Vector2(r*.35,0),color,w,true)
		"back": canvas.draw_polyline(PackedVector2Array([c+Vector2(r*.3,-r*.7),c+Vector2(-r*.35,0),c+Vector2(r*.3,r*.7)]),color,w,true)
		"forward": canvas.draw_polyline(PackedVector2Array([c+Vector2(-r*.3,-r*.7),c+Vector2(r*.35,0),c+Vector2(-r*.3,r*.7)]),color,w,true)
		"forward_arrow":
			canvas.draw_line(c+Vector2(-r*.75,0),c+Vector2(r*.7,0),color,w,true)
			canvas.draw_polyline(PackedVector2Array([c+Vector2(r*.15,-r*.55),c+Vector2(r*.72,0),c+Vector2(r*.15,r*.55)]),color,w,true)
		"list":
			for i in 3:
				var y=c.y+(i-1)*r*.55
				canvas.draw_line(Vector2(c.x-r*.75,y),Vector2(c.x+(r*.75 if i<2 else r*.25),y),color,w,true)
		"retry":
			canvas.draw_arc(c,r*.68,-PI*.95,PI*.6,32,color,w,true)
			var tip=c+Vector2.from_angle(-PI*.95)*r*.68
			canvas.draw_polyline(PackedVector2Array([tip+Vector2(-r*.05,-r*.42),tip,tip+Vector2(r*.42,r*.02)]),color,w,true)
		"play": canvas.draw_colored_polygon(PackedVector2Array([c+Vector2(-r*.45,-r*.65),c+Vector2(r*.65,0),c+Vector2(-r*.45,r*.65)]),color)
		"pause":
			canvas.draw_line(c+Vector2(-r*.3,-r*.6),c+Vector2(-r*.3,r*.6),color,w*1.3,true)
			canvas.draw_line(c+Vector2(r*.3,-r*.6),c+Vector2(r*.3,r*.6),color,w*1.3,true)
		"search":
			canvas.draw_arc(c+Vector2(-r*.12,-r*.12),r*.5,0,TAU,28,color,w,true)
			canvas.draw_line(c+Vector2(r*.25,r*.25),c+Vector2(r*.7,r*.7),color,w,true)
		"star":
			var points=PackedVector2Array()
			for i in 10: points.append(c+Vector2.from_angle(-PI*.5+i*PI/5.0)*(r*.8 if i%2==0 else r*.36))
			canvas.draw_colored_polygon(points,color)
		"home":
			canvas.draw_polyline(PackedVector2Array([c+Vector2(-r*.75,-r*.05),c+Vector2(0,-r*.7),c+Vector2(r*.75,-r*.05)]),color,w,true)
			canvas.draw_polyline(PackedVector2Array([c+Vector2(-r*.55,-r*.2),c+Vector2(-r*.55,r*.7),c+Vector2(r*.55,r*.7),c+Vector2(r*.55,-r*.2)]),color,w,true)
		"close":
			canvas.draw_line(c+Vector2(-r*.5,-r*.5),c+Vector2(r*.5,r*.5),color,w,true)
			canvas.draw_line(c+Vector2(r*.5,-r*.5),c+Vector2(-r*.5,r*.5),color,w,true)
		"add":
			canvas.draw_line(c+Vector2(-r*.6,0),c+Vector2(r*.6,0),color,w,true)
			canvas.draw_line(c+Vector2(0,-r*.6),c+Vector2(0,r*.6),color,w,true)
		"minus": canvas.draw_line(c+Vector2(-r*.6,0),c+Vector2(r*.6,0),color,w,true)
		"settings":
			canvas.draw_arc(c,r*.32,0,TAU,24,color,w,true)
			for i in 8:
				var d=Vector2.from_angle(i*PI/4.0)
				canvas.draw_line(c+d*r*.55,c+d*r*.82,color,w*1.4,true)
			canvas.draw_arc(c,r*.6,0,TAU,32,color,w,true)
		"folder":
			canvas.draw_polyline(PackedVector2Array([c+Vector2(-r*.8,r*.6),c+Vector2(-r*.8,-r*.55),c+Vector2(-r*.25,-r*.55),c+Vector2(-r*.05,-r*.3),c+Vector2(r*.8,-r*.3),c+Vector2(r*.8,r*.6),c+Vector2(-r*.8,r*.6)]),color,w,true)

# Draws an optional icon and caption centred together in rect; returns nothing.
static func draw_caption(canvas: CanvasItem, rect: Rect2, caption: String, font: Font, font_size: int, color: Color) -> void:
	var parts=split(caption); var icon: String=parts[0]; var text: String=parts[1]; var trailing: String=parts[2]
	var icon_size=float(font_size)*1.05; var gap=float(font_size)*.45
	var text_width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x if text!="" else 0.0
	var total=text_width+(icon_size+(gap if text!="" else 0.0) if icon!="" else 0.0)+(gap+icon_size if trailing!="" else 0.0)
	var x=rect.position.x+(rect.size.x-total)*.5; var mid=rect.position.y+rect.size.y*.5
	if icon!="":
		draw(canvas,icon,Vector2(x+icon_size*.5,mid),icon_size,color); x+=icon_size+(gap if text!="" else 0.0)
	if text!="":
		canvas.draw_string(font,Vector2(x,mid+(font.get_ascent(font_size)-font.get_descent(font_size))*.5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
		x+=text_width
	if trailing!="": draw(canvas,trailing,Vector2(x+gap+icon_size*.5,mid),icon_size,color)
