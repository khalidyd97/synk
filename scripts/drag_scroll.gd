extends Node

# Drag-to-scroll for a ScrollContainer full of buttons. Buttons would otherwise swallow the
# touch, so the list never scrolls on a phone. A press that moves more than DRAG_THRESHOLD
# pixels scrolls the list, and was_dragged() lets the buttons ignore that press's release.
const DRAG_THRESHOLD = 12.0

var scroll: ScrollContainer
var pressing = false
var dragged = false
var press_position = Vector2.ZERO
var press_scroll = 0

static func attach(target: ScrollContainer) -> Node:
	var helper = load("res://scripts/drag_scroll.gd").new()
	helper.name = "DragScroll"; helper.scroll = target
	target.add_child(helper)
	return helper

static func was_dragged(target: ScrollContainer) -> bool:
	var helper = target.get_node_or_null("DragScroll")
	return helper != null and helper.dragged

func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and scroll.get_global_rect().has_point(event.position):
			pressing = true; dragged = false
			press_position = event.position; press_scroll = scroll.scroll_vertical
		elif not event.pressed:
			pressing = false
	elif event is InputEventMouseMotion and pressing:
		var distance = event.position.y - press_position.y
		if not dragged and absf(distance) > DRAG_THRESHOLD: dragged = true
		if dragged: scroll.scroll_vertical = int(press_scroll - distance)
