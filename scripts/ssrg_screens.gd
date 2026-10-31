extends Control
# Source-art pause/result presentation; actions reuse SYNK's existing run controls.
var game:Control
var pause_root:Control
var result_root:Control
var pause_icon:TextureButton
var pause_title:Label
var result_title:Label
var result_score:Label
var result_stats:Label
var result_counts:Label
var result_cover:TextureRect
var result_context:Label
var speed_label:Label
var result_info:Dictionary={}
var details_open=false
var age=0.0
var old_mode=""
func _ready() -> void:
	name="SSRGPresentationScreens";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	pause_icon=TextureButton.new();add_child(pause_icon)
	pause_icon.texture_normal=preload("res://assets/ssrg/imported/presentation/UI_pause.png")
	pause_icon.ignore_texture_size=true;pause_icon.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_icon.pressed.connect(game.toggle_pause);pause_icon.tooltip_text="Pause"
	pause_root=make_root();pause_root.hide()
	var card=Panel.new();pause_root.add_child(card);place(card,.17,.23,.66,.54)
	var style=StyleBoxFlat.new();style.bg_color=Color(.025,.025,.035,.97);style.border_color=Color(.2,.85,1,.7);style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel",style)
	pause_title=label(card,"PAUSED",.1,.08,.8,.2,40)
	make_button(card,"SONG LIST",.05,.43,.27,.36,leave_pause)
	make_button(card,"RETRY",.365,.43,.27,.36,game.restart_from_pause)
	make_button(card,"RESUME",.68,.43,.27,.36,game.toggle_pause)
	game.ssrg_playables.hold_speed(make_button(card,"−",.28,.83,.08,.14,func():pass),-.1)
	speed_label=label(card,"",.37,.83,.26,.14,18)
	game.ssrg_playables.hold_speed(make_button(card,"+",.64,.83,.08,.14,func():pass),.1)
	result_root=make_root();result_root.hide()
	var banner=TextureRect.new();result_root.add_child(banner);place(banner,.33,.055,.34,.10)
	banner.texture=preload("res://assets/ssrg/imported/presentation/stage_cleared.png")
	banner.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;banner.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_title=label(result_root,"",.15,.17,.7,.065,24)
	result_context=label(result_root,"",.15,.72,.7,.05,18)
	result_cover=TextureRect.new();result_root.add_child(result_cover);place(result_cover,.12,.28,.20,.40)
	result_cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;result_cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_score=label(result_root,"0",.35,.29,.53,.13,62)
	result_stats=label(result_root,"",.35,.45,.53,.10,24)
	result_counts=label(result_root,"",.35,.59,.53,.11,21)
	make_button(result_root,"SONG LIST",.08,.82,.24,.12,leave_results)
	make_button(result_root,"RETRY",.38,.82,.24,.12,retry)
	make_button(result_root,"DETAILS",.68,.82,.24,.12,show_details)
func make_root() -> Control:
	var root_control=Control.new();add_child(root_control);root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new();root_control.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(.012,.012,.025,.92);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return root_control
func place(control:Control,x:float,y:float,w:float,h:float) -> void:
	control.anchor_left=x;control.anchor_top=y;control.anchor_right=x+w;control.anchor_bottom=y+h
func label(parent:Control,value:String,x:float,y:float,w:float,h:float,font_size:int) -> Label:
	var node=Label.new();parent.add_child(node);place(node,x,y,w,h);node.text=value
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",font_size);node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return node
func make_button(parent:Control,value:String,x:float,y:float,w:float,h:float,action:Callable) -> Button:
	var button=preload("res://scripts/ssrg_action.gd").new();parent.add_child(button);place(button,x,y,w,h);button.caption=value;button.tooltip_text=value
	button.add_theme_font_size_override("font_size",20);button.add_theme_color_override("font_color",Color.WHITE)
	button.pressed.connect(action);return button
func change_speed(step:float) -> void:
	game.ssrg_playables.change_speed(step)
func _process(delta:float) -> void:
	if game.mode!="results":result_info.clear();details_open=false
	var source=game.uses_ssrg_gameplay()
	var pausing=source and game.mode=="paused"
	pause_icon.visible=source and game.mode=="play" and not game.finishing and not game.stage_intro.running()
	var safe=game.safe_rect_for(self)
	var side=clampf(safe.size.y*.105,42,80)
	pause_icon.position=safe.position+Vector2(10,10);pause_icon.size=Vector2.ONE*side
	pause_root.visible=pausing
	if source:
		game.pause_button.hide()
		if pausing:game.modal.hide();game.pause_backdrop.hide()
	speed_label.text="SPEED %.1f" % game.ssrg_speed_setting()
	result_root.visible=game.mode=="results" and result_info.get("ssrg",false) and not details_open
	if game.mode!=old_mode:age=0;old_mode=game.mode
	if pausing or result_root.visible:
		age+=delta
		var panel=pause_root if pausing else result_root
		panel.modulate.a=clampf(age/.18,0,1)
		# Keep all controls inside the same safe area as the gameplay HUD.
		panel.position=safe.position;panel.size=safe.size
func show_results(info:Dictionary) -> void:
	result_info=info.duplicate(true);details_open=false;age=0
	game.results_screen.hide()
	result_title.text=str(info.get("title",""))
	result_context.text="AUTO PLAY PREVIEW · SCORE NOT SAVED" if info.get("auto_play",false) else ("PRACTICE · SCORE NOT SAVED" if info.get("practice",false) else ("NEW BEST" if info.get("new_best",false) else ""))
	result_score.text=game.format_score(int(info.get("score",0)))
	result_stats.text="%s    %.1f%%    MAX COMBO %d" % [str(info.get("rank","")),float(info.get("accuracy",0)),int(info.get("max_combo",0))]
	var counts:Dictionary=info.get("counts",{})
	result_counts.text="S-PERFECT %d     PERFECT %d     GOOD %d     MISS %d" % [int(counts.get("PERFECT",0)),int(counts.get("GREAT",0)),int(counts.get("GOOD",0)),int(counts.get("MISS",0))]
	result_cover.texture=info.get("cover",null)
	result_root.show()
func restore_run() -> void:
	game.ssrg_playable_run=true;game.ssrg_lane_count=int(result_info.get("ssrg_lane_count",13))
	game.ssrg_playable_previous_style=str(result_info.get("ssrg_style","gold"));game.highway_style="ssrg"
func retry() -> void:
	details_open=false;restore_run();game.start_game(game.last_play_notes,game.auto_play,game.last_section)
func leave_pause() -> void:
	game.return_home();game.open_ssrg_playables()
func leave_results() -> void:
	result_info={};game.set_mode("menu");game.open_ssrg_playables()
func show_details() -> void:
	details_open=true;result_root.hide();game.results_screen.show_results(result_info)
