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
	draw_texture_rect(backing,Rect2(origin+Vector2(-362,-8)*unit,Vector2(850,158)*unit),false,color)
	draw_texture_rect(caption,Rect2(origin+Vector2(68,62)*unit,Vector2(92,24)*unit),false,color)
	var presentation=game.ssrg_presentation
	var active= presentation and presentation.active
	var ultra=float(presentation.phase_weights[5]) if active else 0.0
	var gauge_rect=Rect2(origin+Vector2(85,42-2*ultra)*unit,Vector2(282,16+4*ultra)*unit)
	draw_texture_rect(gauge,gauge_rect,false,Color(.22,.22,.22,alpha))
	var fraction=float(presentation.shown_gauge) if active else clampf(float(game.score_panel.shown_energy),0,1)
	for phase in 6:
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
