extends Control

var game: Control
var world: Node3D
var viewport: SubViewport
var screen: TextureRect
var guide_art: Control
const PINK = Color("ed42ff")
const BLUE = Color("38baff")
const PURPLE = Color("a36aff")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new(); viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X if OS.has_feature("mobile") else Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	add_child(viewport)
	world = Node3D.new(); world.set_script(load("res://scripts/highway_3d.gd")); world.game = game
	viewport.add_child(world)
	screen = TextureRect.new(); screen.texture = viewport.get_texture()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
	float star_hash(vec2 cell) {
		return fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	}
	void fragment() {
		vec4 base = texture(TEXTURE,UV);
		vec3 bloom = vec3(0.0);
		for (int x=-1;x<=1;x++) {
			for (int y=-1;y<=1;y++) {
				if (x==0 && y==0) { continue; }
				vec3 sample_color = texture(TEXTURE,UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE*4.0).rgb;
				bloom += max(sample_color-vec3(0.45),vec3(0.0)) * (x==0 || y==0 ? 0.65 : 0.3);
			}
		}
		// Notes enter through a soft shadow at the distant end of the rail.
		float entry_fade = 1.0 - smoothstep(0.015, 0.22, UV.y);
		float rail_mask = 1.0 - smoothstep(0.23, 0.40, abs(UV.x - 0.5));
		vec3 scene_color = (base.rgb + bloom * 0.24) * (1.0 - entry_fade * rail_mask * 0.82);
		// Only faint stars beyond the rail edges: no colored nebula or ribbon gradients.
		float rail_half_width = 0.045 + 0.445 * UV.y;
		float outside = smoothstep(rail_half_width - 0.035, rail_half_width + 0.015, abs(UV.x - 0.5));
		vec2 star_grid = UV * vec2(145.0, 68.0);
		vec2 star_cell = floor(star_grid);
		float star = step(0.994, star_hash(star_cell))
			* exp(-dot(fract(star_grid) - 0.5, fract(star_grid) - 0.5) * 75.0)
			* (0.58 + 0.42 * sin(TIME * 1.8 + star_hash(star_cell + 7.0) * 6.283));
		vec3 backdrop = vec3(0.26, 0.24, 0.37) * star;
		scene_color += backdrop * outside;
		COLOR = vec4(scene_color,1.0);
	}"""
	var post = ShaderMaterial.new(); post.shader = shader; screen.material = post
	add_child(screen)
	resized.connect(resize_viewport); resize_viewport()
	var overlay = Control.new(); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(overlay)
	overlay.draw.connect(draw_overlay.bind(overlay))
	set_meta("overlay",overlay)
	build_asset_guide()

func build_asset_guide() -> void:
	guide_art = Control.new(); guide_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(guide_art); guide_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
	uniform bool recolor = false;
	uniform vec3 tint : source_color = vec3(1.0);
	void fragment() {
		vec4 art = texture(TEXTURE,UV);
		float peak = max(art.r,max(art.g,art.b));
		float white = min(art.r,min(art.g,art.b)) / max(peak,0.001);
		vec3 color = recolor ? mix(tint,vec3(1.0),white*white)*peak : art.rgb;
		COLOR = vec4(color,art.a*smoothstep(0.025,0.13,peak));
	}"""
	var filenames = ["Tap_Note_Blue","Hold_Note_Pink","Slide_Note_Pink","Flick_Up_Pink"]
	for i in 4:
		var texture = load("res://assets/neon/"+filenames[i]+".png") as Texture2D
		var cropped = AtlasTexture.new(); cropped.atlas = texture
		cropped.region = Rect2(0,0,texture.get_width(),texture.get_height()*([1.0,.91,.95,.96][i]))
		var art = TextureRect.new(); art.texture = cropped; art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide_art.add_child(art); art.anchor_left=.065+i*.24; art.anchor_right=.245+i*.24; art.anchor_top=.40; art.anchor_bottom=.70
		var mat = ShaderMaterial.new(); mat.shader = shader
		mat.set_shader_parameter("recolor",i>0)
		mat.set_shader_parameter("tint",Color("ffd447") if i==3 else PURPLE)
		art.material = mat
		if i==3:
			art.texture=load("res://assets/brand/flick_guide.svg")
			art.material=null

func resize_viewport() -> void:
	if viewport: viewport.size = Vector2i(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)))

func _process(_delta: float) -> void:
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if game.mode in ["menu","guide","library","editor"] else SubViewport.UPDATE_ALWAYS
	if screen: screen.visible = game.mode not in ["guide","menu","library"]
	if guide_art: guide_art.visible = game.mode == "guide"
	if has_meta("overlay"): get_meta("overlay").queue_redraw()
	queue_redraw()

func depth(time: float) -> float: return (time-game.song_time)/game.note_travel_seconds()
func project(lane: float, d: float) -> Vector2:
	return world.camera.unproject_position(Vector3(world.lane_x(lane),.035,-d*world.visible_length()))

func touch_world_position(p: Vector2) -> Vector3:
	var point=p*Vector2(viewport.size)
	var hit=Plane(Vector3.UP,.035).intersects_ray(world.camera.project_ray_origin(point),world.camera.project_ray_normal(point))
	return hit if hit!=null else Vector3(0,.035,0)

func input_position(p: Vector2) -> Vector2:
	# The whole projected pad is interactive, including its near/far corners.
	# Resolve its actual ground position instead of measuring against the small
	# decorative marker or projecting every row onto the bar's center line.
	var screen_point=p*Vector2(viewport.size)
	var origin = world.camera.project_ray_origin(screen_point)
	var direction = world.camera.project_ray_normal(screen_point)
	var hit=Plane(Vector3.UP,.035).intersects_ray(origin,direction)
	var on_pad=hit!=null and absf(hit.z)<=world.JUDGMENT_DEPTH*.5+.001
	if on_pad:
		# Preserve the existing normalized input contract for capture and judging.
		p.y=clampf(p.y,.6001,.9199)
	else:
		# Keep the generous approach area and stable vertical-flick coordinates.
		screen_point=Vector2(p.x*viewport.size.x,project(world.CENTER_LANE,0).y)
		origin=world.camera.project_ray_origin(screen_point)
		direction=world.camera.project_ray_normal(screen_point)
		hit=Plane(Vector3.UP,0).intersects_ray(origin,direction)
	if hit != null: p.x = .07 + ((hit.x/world.LANE_WIDTH+world.CENTER_LANE)+.5)/SynkChart.LANES*.86
	if on_pad and absf(hit.x)<=world.PAD_HALF_WIDTH+.001:
		p.x=clampf(p.x,.070001,.929999)
	return p

func glow(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	for layer in [8,6,4,3,2]: draw_line(a,b,Color(color,color.a*.025),width*layer,true)
	draw_line(a,b,color,width,true); draw_line(a,b,Color(Color("f8eaff"),color.a),maxf(1,width*.22),true)

func draw_overlay(overlay: Control) -> void:
	if game.mode=="record" and game.arranging and not game.arrange_selection.is_empty():
		var note: Dictionary=game.arrange_selection.note
		if note.kind in ["hold","slide"]:
			var centers=world.trail_centers(note,clampi(ceili(float(note.duration)*32),16,256),true)
			var sides=world.trail_sides(centers)
			var shift=Vector3(0,0,(float(note.time)-game.song_time)*world.travel_speed())
			var width=world.TRAIL_HALF*.65*game.hold_trail_width
			for i in centers.size()-1:
				var a: Vector3=centers[i]+shift; var b: Vector3=centers[i+1]+shift
				if maxf(a.z,b.z)<-world.TRACK_LENGTH or minf(a.z,b.z)>world.JUDGMENT_DEPTH: continue
				if world.camera.is_position_behind(a) or world.camera.is_position_behind(b): continue
				for side in [-1,1]:
					var start=world.camera.unproject_position(a+sides[i]*width*side)
					var finish=world.camera.unproject_position(b+sides[i+1]*width*side)
					overlay.draw_line(start,finish,Color("7beaff",.8),2,true)
		var note_position=Vector3(world.lane_x(float(note.lane)),.2,(float(note.time)-game.song_time)*world.travel_speed())
		var center=world.camera.unproject_position(note_position)
		if Rect2(Vector2.ZERO,size).has_point(center):
			var pulse=.5+.5*sin(Time.get_ticks_msec()/1000.0*4.0)
			overlay.draw_arc(center,31+pulse*3,0,TAU,48,Color("45d5ff",.6+pulse*.3),3.0,true)

func _draw() -> void:
	if game != null and game.mode == "guide":
		draw_rect(Rect2(Vector2.ZERO,size),Color("06091e")); draw_guide()

func guide_text(text: String, position: Vector2, width: float, font_size: int) -> void:
	draw_string(ThemeDB.fallback_font,position,text,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,Color("eee9ff"))

func guide_bar(center: Vector2, width: float, color: Color) -> void:
	for spread in [12,8,4,0]:
		var style=StyleBoxFlat.new(); style.bg_color=Color(color,.055) if spread else color
		style.set_corner_radius_all(5+spread)
		if spread==0: style.border_color=Color("fff0ff"); style.set_border_width_all(2)
		draw_style_box(style,Rect2(center-Vector2(width*.5,9),Vector2(width,18)).grow(spread))

func draw_guide() -> void:
	draw_rect(Rect2(Vector2(0,size.y*.18),Vector2(size.x,size.y*.69)),Color("030713"))
	guide_text(str(SynkChart.LANES)+" LANES  /  FOLLOW THE LIGHT",Vector2(size.x*.1,size.y*.25),size.x*.8,28)
	var titles=["1. TAP NOTE","2. HOLD NOTE","3. SLIDE NOTE","4. FLICK NOTE"]
	var captions=["Tap when the note hits the line.","Keep holding until the tail ends.","Follow the trail all the way to its end.","Swipe in the arrow direction."]
	for i in 4:
		var x=size.x*(.045+i*.24)
		var w=size.x*.22
		var box=Rect2(Vector2(x,size.y*.3),Vector2(w,size.y*.52))
		var style=StyleBoxFlat.new(); style.bg_color=Color("0d1128"); style.border_color=[Color("52dfff"),Color("b58aff"),Color("b58aff"),Color("ffd447")][i]; style.set_border_width_all(2); style.set_corner_radius_all(18)
		draw_style_box(style,box)
		guide_text(titles[i],Vector2(x,size.y*.36),w,20)
		guide_text(captions[i],Vector2(x,size.y*.77),w,16)
