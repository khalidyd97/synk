extends Node
# A local clock keeps ambient motion continuous while visible and stops it offscreen.
var elapsed=0.0
static func attach(target: CanvasItem,shader: Shader) -> ShaderMaterial:
    var mat=ShaderMaterial.new(); mat.shader=shader; target.material=mat
    mat.set_shader_parameter("clock",0.0)
    var driver=Node.new(); driver.set_script(load("res://scripts/background_motion.gd"))
    driver.name="BackgroundMotion"; target.add_child(driver)
    return mat
func _process(delta: float) -> void:
    var target=get_parent() as CanvasItem
    if not target or not target.is_visible_in_tree(): return
    elapsed+=delta
    if target.material is ShaderMaterial: target.material.set_shader_parameter("clock",elapsed)
