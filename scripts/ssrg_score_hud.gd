extends Control
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
func _draw() -> void:
	if not visible:return
	# Match the stage's logical canvas while keeping the HUD inside safe-area bounds.
	var unit=size.y/game.field.world.ssrg_canvas_height()
	var origin=Vector2(maxf(0.0,(size.x-1136.0*unit)*.5),0.0)
	var alpha=float(game.score_panel.modulate.a)
	var color=Color(1,1,1,alpha)
	draw_texture_rect(backing,Rect2(origin+Vector2(-362,-8)*unit,Vector2(850,158)*unit),false,color)
	draw_texture_rect(caption,Rect2(origin+Vector2(68,62)*unit,Vector2(92,24)*unit),false,color)
	var gauge_rect=Rect2(origin+Vector2(85,42)*unit,Vector2(282,16)*unit)
	draw_texture_rect(gauge,gauge_rect,false,Color(.22,.22,.22,alpha))
	var presentation=game.ssrg_presentation
	var phase=int(presentation.state) if presentation and presentation.active else 0
	var fraction=presentation.gauge_fraction() if presentation and presentation.active else clampf(float(game.score_panel.shown_energy),0,1)
	var fill_art:Texture2D=artwork.get("Fever_G_Energy",gauge)
	if phase==1:fill_art=artwork.get("Fever_G_Fever_0",gauge)
	elif phase>=2:
		var frame=1+clampi(int(fposmod(game.field.world.animation_time,1.0)*10),0,9)
		fill_art=artwork.get("Fever_G_Fever_%d-%d" % [phase-1,frame],artwork.get("Fever_G_Fever_5",gauge))
	var text_key="Fever_T_Energy" if phase<2 else "Fever_T_Fever_%d" % (phase-1)
	if artwork.has(text_key):draw_texture_rect(artwork[text_key],Rect2(origin+Vector2(88,16)*unit,Vector2(114,21)*unit),false,color)
	if fraction>0:
		var region=Rect2(0,0,fill_art.get_width()*fraction,fill_art.get_height())
		var fill=Rect2(gauge_rect.position,Vector2(gauge_rect.size.x*fraction,gauge_rect.size.y))
		draw_texture_rect_region(fill_art,fill,region,color)
	var value=str(maxi(0,roundi(game.displayed_score)))
	var cursor=origin+Vector2(84,84)*unit
	for character in value:
		var texture=digits[int(character)]
		var dimensions=Vector2(texture.get_width(),texture.get_height())*unit
		draw_texture_rect(texture,Rect2(cursor,dimensions),false,color)
		cursor.x+=dimensions.x

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
	var bonus=int(presentation.score_rules.pending_bonus)
	if bonus>0:
		if artwork.has("ui_rave_T"):draw_texture_rect(artwork.ui_rave_T,Rect2(origin+Vector2(84,190)*unit,Vector2(134,30)*unit),false,color)
		words("+"+game.format_score(bonus),origin+Vector2(84,247)*unit,maxi(12,roundi(24*unit)),color)
	if presentation.event_age<1.0:
		var key="text_bomb" if presentation.event_kind==2 else ("text_item_lv_up" if presentation.event_kind in [3,4] else "")
		if artwork.has(key):
			var texture:Texture2D=artwork[key];var dimensions=texture.get_size()*unit*.65
			draw_texture_rect(texture,Rect2(Vector2(size.x*.5,120*unit)-dimensions*.5,dimensions),false,Color(1,1,1,color.a*(1-presentation.event_age)))
