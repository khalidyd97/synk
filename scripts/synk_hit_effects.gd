extends Node3D
# SYNK artwork on SSRG's frame clock and sustain lifecycle.
const SOURCE=preload("res://scripts/ssrg_highway.gd")
const FPS=SOURCE.HIT_FPS
const LIFE=SOURCE.HIT_LIFE
const RETRIGGER=SOURCE.HOLD_RETRIGGER
var world:Node3D
var hits:Array=[]
var pool:Array=[]

func make_hit() -> Dictionary:
	var mesh=QuadMesh.new();mesh.size=Vector2(620,372)*world.SSRG_UNIT
	var material=ShaderMaterial.new();material.shader=preload("res://scripts/synk_hit_burst.gdshader");material.render_priority=6
	var node=world.mesh_node(mesh,self,material);node.hide()
	return {"node":node,"material":material,"age":0.0,"sustain_entry":{},"pointer_id":-999,"x":0.0}

func prefill(count:int=24) -> void:
	while hits.size()+pool.size()<count:pool.append(make_hit())

func contact_x(hit:Dictionary) -> float:
	var entry:Dictionary=hit.sustain_entry
	var owner=int(entry.get("pointer",hit.pointer_id))
	if owner!=-999:hit.pointer_id=owner
	if world.game.pointers.has(hit.pointer_id):
		var contact:Dictionary=world.game.pointers[hit.pointer_id]
		if contact.has("world"):hit.x=float(contact.world.x)
	return float(hit.x)

static func sustained(entry:Dictionary,at:float) -> bool:
	if entry.is_empty():return false
	var note:Dictionary=entry.get("note",{})
	var until=float(note.get("time",-INF))+float(note.get("duration",0))
	if entry.has("missed_at"):until=-INF
	return SOURCE.sustain_effect_active({"done":entry.get("done",false),"ssrg_effect_until":until},at,true)

func position_hit(hit:Dictionary) -> void:
	hit.node.position=Vector3(hit.x,.035+SOURCE.FLASH_PULL,0)
	hit.node.rotation=world.camera.rotation
	hit.node.scale=Vector3.ONE*world.game.note_size

func spawn(lane:float,kind:String,entry:Dictionary,pointer_id:int,direction:int=0) -> void:
	var hit:Dictionary=pool.pop_back() if not pool.is_empty() else make_hit()
	hit.age=0.0;hit.sustain_entry=entry;hit.pointer_id=pointer_id;hit.x=world.note_x(lane)
	if not entry.is_empty():contact_x(hit)
	position_hit(hit)
	var palette=world.palette_for_kind(kind)
	hit.material.set_shader_parameter("tint",world.element_color("hits",world.colors[palette]))
	hit.material.set_shader_parameter("style",1.0 if world.game.hit_style=="bloom" else 0.0)
	hit.material.set_shader_parameter("direction",float(direction))
	hit.seed=randf()*100.0;hit.material.set_shader_parameter("seed",hit.seed)
	hit.material.set_shader_parameter("frame",0.0)
	hit.material.set_shader_parameter("opacity",world.game.features.effect("Hit flashes"))
	hit.material.set_shader_parameter("particles",world.game.features.effect("Particles"))
	hit.node.show();hits.append(hit)

func release(hit:Dictionary) -> void:
	hit.node.hide();hit.sustain_entry={}
	if pool.size()<64:pool.append(hit)
	else:hit.node.queue_free()

func advance(delta:float) -> void:
	var game=world.game
	var running=game.mode=="play" and game.countdown<=0 and game.resume_countdown<=0
	for i in range(hits.size()-1,-1,-1):
		var hit:Dictionary=hits[i]
		var held=sustained(hit.sustain_entry,world.render_time())
		if running:hit.age+=delta
		if running and held and hit.age>RETRIGGER:
			hit.age=fmod(hit.age,RETRIGGER);hit.seed+=.6180339
			hit.material.set_shader_parameter("seed",hit.seed)
		if (not held and hit.age>=LIFE) or game.mode not in ["play","paused"]:
			hits.remove_at(i);release(hit);continue
		if running and held:contact_x(hit)
		position_hit(hit)
		hit.material.set_shader_parameter("frame",float(mini(10,int(hit.age*FPS))))
		hit.material.set_shader_parameter("opacity",game.features.effect("Hit flashes"))
		hit.material.set_shader_parameter("particles",game.features.effect("Particles"))

func clear() -> void:
	for hit in hits+pool:hit.node.hide();hit.node.queue_free()
	hits.clear();pool.clear()
