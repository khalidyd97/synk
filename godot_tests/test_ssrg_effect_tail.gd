extends SceneTree
const Effects=preload("res://scripts/ssrg_highway.gd")
func _initialize():
	var entry={"done":false,"ssrg_contact":true}
	assert(Effects.sustain_effect_active(entry,1.0,true))
	entry.ssrg_contact=false
	assert(Effects.sustain_effect_active(entry,1.5,true))
	entry.done=true
	assert(not Effects.sustain_effect_active(entry,1.5,true))
	entry.ssrg_effect_until=2.0
	assert(Effects.sustain_effect_active(entry,1.8,true))
	assert(Effects.sustain_effect_active(entry,2.0,true))
	assert(not Effects.sustain_effect_active(entry,2.001,true))
	assert(not Effects.sustain_effect_active(entry,1.8,false))
	assert(not Effects.sustain_effect_active({},1.8,true))
	var chain={"pointer":7,"sustain_last_pointer":7,"sustain_last_identity":42}
	var contacts={7:{"ssrg_identity":42,"world":Vector3(3,.035,0)}}
	assert(Effects.sustain_finger_x(chain,contacts,-4)==3)
	contacts[7].world.x=5
	assert(Effects.sustain_finger_x(chain,contacts,-3)==5)
	chain.pointer=-999
	assert(Effects.sustain_finger_x(chain,contacts,-2)==5)
	contacts[7].ssrg_identity=43;contacts[7].world.x=-8
	assert(Effects.sustain_finger_x(chain,contacts,-1)==5)
	assert(Effects.sustain_finger_x(chain,{},0)==5)
	assert(Effects.sustain_finger_x({},contacts,2)==2)
	print("SSRG effect lifetime: recoverable gaps, early tail, last connector, miss and OG PASS")
	quit()
