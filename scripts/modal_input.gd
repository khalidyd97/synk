extends RefCounted
# Global _input listeners run before GUI controls. Explicit modal ownership keeps
# background gestures and momentum out of popups, regardless of callback order.
const GROUP="synk_input_modals"
static func register(node:Node) -> void:
	node.add_to_group(GROUP)
static func blocked(target:Node) -> bool:
	if target==null or not target.is_inside_tree():return false
	for modal in target.get_tree().get_nodes_in_group(GROUP):
		if modal.is_queued_for_deletion():continue
		var shown=false
		var viewport=modal.get_viewport()
		if modal is CanvasItem:shown=modal.is_visible_in_tree()
		elif modal is Window:
			shown=modal.visible
			if modal.get_parent():viewport=modal.get_parent().get_viewport()
		var ancestor=modal.get_parent()
		while shown and ancestor:
			if ancestor is CanvasLayer and not ancestor.visible:shown=false
			ancestor=ancestor.get_parent()
		if shown and viewport==target.get_viewport() and modal!=target and not modal.is_ancestor_of(target):return true
	return false
