extends "res://scripts/song_list_scroll.gd"
# Shared, modal-safe scrolling for lists of buttons.
const DRAG_THRESHOLD=12.0
static func attach(target:ScrollContainer) -> Node:
	var helper=load("res://scripts/drag_scroll.gd").new();helper.name="DragScroll";helper.scroll=target;target.add_child(helper);return helper
static func was_dragged(target:ScrollContainer) -> bool:
	var helper=target.get_node_or_null("DragScroll")
	return helper!=null and helper.dragged
