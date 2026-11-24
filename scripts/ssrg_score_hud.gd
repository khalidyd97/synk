extends Control
const SOURCE=preload("res://scripts/ssrg_hud_source_data.gd")
# Source level10 top-left HUD artwork. Score/energy values remain SYNK's rules.
var game:Control
var digits:Array[Texture2D]=[]
var artwork:Dictionary=preload("res://scripts/ssrg_presentation_art.gd").TEXTURES
var caption:Texture2D=preload("res://assets/ssrg/imported/hud/text_score.png")
var backing:Texture2D=preload("res://assets/ssrg/imported/hud/UI_max_combo.png")
var gauge:Texture2D=preload("res://assets/ssrg/imported/hud/Fever_G_BG.png")
func _ready() -> void:
	name="SSRGScoreHud"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 10:digits.append(load("res://assets/ssrg/imported/hud/UI_score_%d.png" % i))
	visible=false
func _process(_delta:float) -> void:
	visible=game.uses_ssrg_gameplay() and game.mode in ["play","paused"]
	if visible:queue_redraw()
func hud_layout() -> Dictionary:
	# Supplied 1564x720 reference: gauge starts at x176, score at x206.
	# Anchor to the full stage, then convert into this safe-area control.
	var unit=game.size.y/game.field.world.ssrg_canvas_height()
	var anchor=game.get_global_transform_with_canvas()*Vector2(game.size.x*.1125,0)
	var origin=get_global_transform_with_canvas().affine_inverse()*anchor-Vector2(85*unit,0)
	origin.x=maxf(0,origin.x);origin.y=maxf(0,origin.y)
	return {"unit":unit,"origin":origin}
func _draw() -> void:
	if not visible:return
	# Match the stage's logical canvas while keeping the HUD inside safe-area bounds.
	var layout=hud_layout()
	var unit:float=layout.unit
	var origin:Vector2=layout.origin
	var alpha=float(game.score_panel.modulate.a)
	var color=Color(1,1,1,alpha)
	if not game.synk_mode():
		draw_texture_rect(backing,Rect2(origin+Vector2(-362,-8)*unit,Vector2(850,158)*unit),false,color)
		draw_texture_rect(caption,Rect2(origin+Vector2(68,62)*unit,Vector2(92,24)*unit),false,color)
	var presentation=game.ssrg_presentation
	var active= presentation and presentation.active
	# SYNK mode draws its own life bar, score and best with the game's font.
	if game.synk_mode():
		draw_synk_life(presentation,active,origin,unit,alpha)
		draw_synk_score(presentation,active,origin,unit,alpha)
		return
	var ultra=float(presentation.phase_weights[5]) if active else 0.0
	var gauge_rect=Rect2(origin+Vector2(85,42-2*ultra)*unit,Vector2(282,16+4*ultra)*unit)
	var fraction=float(presentation.shown_gauge) if active else clampf(float(game.score_panel.shown_energy),0,1)
	if game.synk_mode():draw_synk_life(presentation,active,origin,unit,alpha)
	else:draw_texture_rect(gauge,gauge_rect,false,Color(.22,.22,.22,alpha))
	for phase in (0 if game.synk_mode() else 6):
		var weight=float(presentation.phase_weights[phase]) if active else (1.0 if phase==0 else 0.0)
		if weight<.001:continue
		var phase_color=Color(1,1,1,alpha*weight)
		var fill_art:Texture2D=artwork.get("Fever_G_Energy",gauge)
		if phase==1:fill_art=artwork.get("Fever_G_Fever_0",gauge)
		elif phase>=2:
			var frame=1+clampi(int(fposmod(game.field.world.animation_time,1.0)*10),0,9)
			fill_art=artwork.get("Fever_G_Fever_%d-%d" % [phase-1,frame],artwork.get("Fever_G_Fever_5",gauge))
		var text_key="Fever_T_Energy" if phase<2 else "Fever_T_Fever_%d" % (phase-1)
		if artwork.has(text_key):draw_texture_rect(artwork[text_key],Rect2(origin+Vector2(88,16)*unit,Vector2(114,21)*unit),false,phase_color)
		if fraction>0:
			var region=Rect2(0,0,fill_art.get_width()*fraction,fill_art.get_height())
			var fill=Rect2(gauge_rect.position,Vector2(gauge_rect.size.x*fraction,gauge_rect.size.y))
			draw_texture_rect_region(fill_art,fill,region,phase_color)
	var value=str(maxi(0,roundi(game.displayed_score)))
	# Fixed, right-to-left authored slots; commas are independent widgets.
	for i in value.length():
		var right=SOURCE.SCORE_RIGHT_EDGES[i] if i<SOURCE.SCORE_RIGHT_EDGES.size() else 249.0-20*i-10*floori(i/3.0)
		var texture=digits[int(value[value.length()-1-i])]
		draw_texture_rect(texture,Rect2(origin+Vector2(right-30,84)*unit,Vector2(30,38)*unit),false,color)
	if value.length()>3:draw_texture_rect(SOURCE.SCORE_COMMA,Rect2(origin+Vector2(169,105)*unit,Vector2(16,19)*unit),false,color)
	if value.length()>6:draw_texture_rect(SOURCE.SCORE_COMMA,Rect2(origin+Vector2(99,105)*unit,Vector2(16,19)*unit),false,color)

	if presentation and presentation.active:draw_source_extras(presentation,origin,unit,color)
# SYNK mode's life bar: a slanted run of segments filling coral to amber, a cream outline,
# a bright leading segment, LIFE and the percentage above it, and a red pulse when low.
# During rave, a thin pink strip under it shows the fever gauge.
const SYNK_SEGMENTS=24
const SYNK_SLANT=7.0
const SYNK_CORAL=Color("ff6b3d")
const SYNK_AMBER=Color("ffc36b")
const SYNK_CREAM=Color("fff1dc")
const SYNK_DANGER=Color("ff2d4a")
func draw_synk_life(presentation:Node,active:bool,origin:Vector2,unit:float,alpha:float) -> void:
	var life=clampf(float(presentation.life)/100.0,0,1) if active else clampf(float(game.score_panel.shown_energy),0,1)
	var at=origin+Vector2(85,38)*unit
	var bar=Vector2(282,20)*unit
	var slant=SYNK_SLANT*unit
	var low=life<.25
	var pulse=(.5+.5*sin(game.field.world.animation_time*9.0)) if low else 0.0
	# Plate and outline.
	var plate=PackedVector2Array([at+Vector2(slant,0),at+Vector2(bar.x+slant,0),at+Vector2(bar.x,bar.y),at+Vector2(0,bar.y)])
	draw_colored_polygon(plate,Color(.07,.05,.09,.82*alpha))
	var outline=plate.duplicate();outline.append(plate[0])
	draw_polyline(outline,Color(SYNK_DANGER if low else SYNK_CREAM,(.45+.4*pulse)*alpha),maxf(1.0,1.6*unit),true)
	# Segments.
	var inset=3.0*unit;var gap=2.0*unit
	var inner=Vector2(bar.x-2*inset,bar.y-2*inset)
	var step=(inner.x+gap)/SYNK_SEGMENTS
	var lit=life*SYNK_SEGMENTS
	for i in SYNK_SEGMENTS:
		var amount=clampf(lit-i,0,1)
		if amount<=0:break
		var t=float(i)/(SYNK_SEGMENTS-1)
		var color:Color=SYNK_CORAL.lerp(SYNK_AMBER,t)
		if low:color=SYNK_DANGER.lerp(SYNK_CREAM,pulse*.35)
		var leading=lit-i<=1.0
		if leading:color=color.lerp(SYNK_CREAM,.55)
		var x0=inset+i*step;var w=(step-gap)*amount
		var top=at+Vector2(x0+slant*(1-inset/bar.y),inset);var bottom=at+Vector2(x0+slant*(inset/bar.y),bar.y-inset)
		var cell=PackedVector2Array([top,top+Vector2(w,0),bottom+Vector2(w,0),bottom])
		draw_colored_polygon(cell,Color(color,alpha))
	# Soft glow line along the top of the lit part.
	if lit>0:
		var end=inset+minf(lit,SYNK_SEGMENTS)*step-gap
		draw_line(at+Vector2(slant+inset,-1.5*unit),at+Vector2(slant+end,-1.5*unit),Color(SYNK_AMBER if not low else SYNK_DANGER,.35*alpha),2.0*unit)
	# LIFE and the percentage, above the bar.
	var font:Font=game.GAME_FONT
	var size_px=maxi(10,roundi(13*unit))
	spaced(font,at+Vector2(slant,-6*unit),"LIFE",size_px,4*unit,Color(SYNK_CREAM,.85*alpha))
	draw_string(font,at+Vector2(slant+bar.x-60*unit,-6*unit),"%d%%" % roundi(life*100),HORIZONTAL_ALIGNMENT_RIGHT,60*unit,size_px,Color(SYNK_DANGER if low else SYNK_AMBER,alpha))
	# Rave: the fever gauge as a thin pink strip under the bar.
	if active and int(presentation.state)>0:
		var fever=clampf(float(presentation.shown_gauge),0,1)
		var strip=Rect2(at+Vector2(0,bar.y+4*unit),Vector2(bar.x*fever,3*unit))
		draw_rect(strip,Color(Color("ff2d7a"),.9*alpha))

# Text with extra space between its letters, drawn from its left end.
func spaced(font:Font,at:Vector2,text:String,px:int,gap:float,tint:Color) -> float:
	var x=at.x
	for i in text.length():
		draw_string(font,Vector2(x,at.y),text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,px,tint)
		x+=font.get_string_size(text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,px).x+gap
	return x-at.x-gap

# SYNK mode's score: a small spaced label, a clean number with a soft amber glow, and a
# thin amber rule under it that fades out to the left. The rave bonus sits on its own line
# beneath, and the best score in the top right.
const SYNK_SCORE_AMBER=Color("ff9a3c")
func draw_synk_score(presentation:Node,active:bool,origin:Vector2,unit:float,alpha:float) -> void:
	var font:Font=game.GAME_FONT
	var left=origin.x+85*unit
	var right=left+289*unit
	var baseline=origin.y+112*unit
	spaced(font,Vector2(left+7*unit,baseline-2*unit),"SCORE",maxi(10,roundi(13*unit)),5*unit,Color(SYNK_SCORE_AMBER,.9*alpha))
	var value:String=game.format_score(maxi(0,roundi(game.displayed_score)))
	var px=maxi(14,roundi(40*unit))
	var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	var at=Vector2(right-width,baseline)
	draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,maxi(2,roundi(9*unit)),Color(SYNK_SCORE_AMBER,.14*alpha))
	draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,maxi(1,roundi(4*unit)),Color(SYNK_SCORE_AMBER,.22*alpha))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color(1,.98,.94,alpha))
	var rule_y=baseline+10*unit
	draw_polyline_colors(PackedVector2Array([Vector2(left,rule_y),Vector2(right,rule_y)]),PackedColorArray([Color(SYNK_SCORE_AMBER,0),Color(SYNK_SCORE_AMBER,.95*alpha)]),maxf(1.0,1.6*unit),true)
	draw_circle(Vector2(right,rule_y),maxf(1.5,2.4*unit),Color(1,.95,.85,alpha))
	if not active:return
	# Rave bonus: the multiplier and what it has banked so far.
	var bonus=int(presentation.score_rules.current_pending_bonus())
	if bonus>0:
		var line="RAVE  x%d    +%s" % [clampi(int(presentation.state)-1,1,4),game.format_score(bonus)]
		var bonus_px=maxi(11,roundi(17*unit))
		var bonus_width=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,bonus_px).x
		draw_string(font,Vector2(right-bonus_width,rule_y+24*unit),line,HORIZONTAL_ALIGNMENT_LEFT,-1,bonus_px,Color(SYNK_AMBER,alpha))
	# Best score, top right.
	var edge=size.x-origin.x-120*unit
	var best:String=game.format_score(presentation.best_score)
	var best_px=maxi(12,roundi(20*unit))
	var best_width=font.get_string_size(best,HORIZONTAL_ALIGNMENT_LEFT,-1,best_px).x
	draw_string(font,Vector2(edge-best_width,47*unit),best,HORIZONTAL_ALIGNMENT_LEFT,-1,best_px,Color(1,.98,.94,alpha))
	var label_px=maxi(10,roundi(13*unit))
	var label_width=font.get_string_size("BEST",HORIZONTAL_ALIGNMENT_LEFT,-1,label_px).x+3*5*unit
	spaced(font,Vector2(edge-best_width-label_width-14*unit,46*unit),"BEST",label_px,5*unit,Color(SYNK_SCORE_AMBER,.9*alpha))

func words(value:String,at:Vector2,font_size:int,tint:Color) -> void:
	draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
func draw_source_extras(presentation:Node,origin:Vector2,unit:float,color:Color) -> void:
	var right=size.x-origin.x-200*unit
	words("BEST  "+game.format_score(presentation.best_score),Vector2(right-80*unit,47*unit),maxi(12,roundi(17*unit)),color)
	# Album art is shown by play_cover.gd; the old portrait card box is gone.
	var mission=int(presentation.metadata.get("mission_score",0))
	if mission>0:
		if artwork.has("ui_mission"):draw_texture_rect(artwork.ui_mission,Rect2(origin+Vector2(84,132)*unit,Vector2(80,20)*unit),false,color)
		words("%s / %s" % [game.format_score(game.score),game.format_score(mission)],origin+Vector2(84,174)*unit,maxi(12,roundi(16*unit)),color)
	if presentation.collected>0:
		words("COLLECTED  %d" % presentation.collected,Vector2(right-20*unit,320*unit),maxi(12,roundi(18*unit)),color)
	var bonus=presentation.score_rules.current_pending_bonus()
	if bonus>0:
		draw_rave_bonus(bonus,int(presentation.state),origin,unit,color)
	if presentation.event_age<1.0:
		var key="text_bomb" if presentation.event_kind==2 else ("text_item_lv_up" if presentation.event_kind in [3,4] else "")
		if artwork.has(key):
			var texture:Texture2D=artwork[key];var dimensions=texture.get_size()*unit*.65
			draw_texture_rect(texture,Rect2(Vector2(size.x*.5,120*unit)-dimensions*.5,dimensions),false,Color(1,1,1,color.a*(1-presentation.event_age)))

func draw_rave_bonus(value:int,phase:int,origin:Vector2,unit:float,color:Color) -> void:
	# level10 ravebonus + UINumber Fixed_LeftAlign, including its next-slot offset.
	draw_texture_rect(artwork.ui_rave_T,Rect2(origin+Vector2(238,59)*unit,Vector2(134,30)*unit),false,color)
	var multiplier=clampi(phase-1,1,4)
	if SOURCE.RAVE_MULTIPLIERS.has(multiplier):
		draw_texture_rect(SOURCE.RAVE_MULTIPLIERS[multiplier],Rect2(origin+Vector2(372,64)*unit,Vector2(32,22)*unit),false,color)
	var digits_value=str(maxi(0,value))
	var count=digits_value.length()
	var offset:float=SOURCE.RAVE_DIGIT_CENTERS[count] if count<SOURCE.RAVE_DIGIT_CENTERS.size() else 0.0
	var leading=0.0
	for i in count:
		var index=count-1-i
		var authored:float=SOURCE.RAVE_DIGIT_CENTERS[index] if index<SOURCE.RAVE_DIGIT_CENTERS.size() else 14.0-18*(index-6)
		var center=Vector2(253+.8*(9+authored-offset),100)
		if i==0:leading=center.x
		draw_texture_rect(artwork["ui_rave_T_"+digits_value[i]],Rect2(origin+(center-Vector2(13,16)*.8)*unit,Vector2(26,32)*.8*unit),false,color)
	var plus_center=Vector2(leading-23*.8,100)
	draw_texture_rect(artwork.ui_rave_T_plus,Rect2(origin+(plus_center-Vector2(13,16)*.8)*unit,Vector2(26,32)*.8*unit),false,color)
	for group in [1,2]:
		if count<=group*3:continue
		var center=Vector2(253+.8*((94 if group==1 else 33)-offset),107.2)
		draw_texture_rect(artwork.ui_rave_T_com,Rect2(origin+(center-Vector2(6,11)*.8)*unit,Vector2(12,22)*.8*unit),false,color)
