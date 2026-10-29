extends Control

const LINE_THICKNESS: float = 3.0
const LINE_COLOR: Color = Color(0.4, 0.42, 0.46, 0.85)
const LOCKED_LINE_COLOR: Color = UiPalette.DANGER
const ALIGN_EPSILON: float = 4.0
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 0.1

var menu: Control

var _viewport: Control
var _map_canvas: Control
var _map_root: Control
var _zoom_label: Label
var _zoom_out_button: Button
var _zoom_in_button: Button

var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _pan_at_drag_start: Vector2 = Vector2.ZERO
var _view_initialized: bool = false


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)

	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_END
	toolbar.add_theme_constant_override("separation", 6)
	layout.add_child(toolbar)

	_zoom_out_button = Button.new()
	_zoom_out_button.text = "-"
	_zoom_out_button.tooltip_text = "Zoom out"
	_zoom_out_button.custom_minimum_size = Vector2(36.0, 28.0)
	_zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	toolbar.add_child(_zoom_out_button)

	_zoom_label = Label.new()
	_zoom_label.text = "100%"
	_zoom_label.custom_minimum_size = Vector2(52.0, 28.0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toolbar.add_child(_zoom_label)

	_zoom_in_button = Button.new()
	_zoom_in_button.text = "+"
	_zoom_in_button.tooltip_text = "Zoom in"
	_zoom_in_button.custom_minimum_size = Vector2(36.0, 28.0)
	_zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	toolbar.add_child(_zoom_in_button)

	var center_button := Button.new()
	center_button.text = "Center"
	center_button.tooltip_text = "Center on current room"
	center_button.custom_minimum_size = Vector2(72.0, 28.0)
	center_button.pressed.connect(_center_on_current_room)
	toolbar.add_child(center_button)

	_viewport = Control.new()
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.clip_contents = true
	_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport.gui_input.connect(_on_viewport_gui_input)
	layout.add_child(_viewport)

	_map_canvas = Control.new()
	_viewport.add_child(_map_canvas)

	_map_root = Control.new()
	_map_canvas.add_child(_map_root)

	_update_zoom_controls()


func refresh() -> void:
	for child: Node in _map_root.get_children():
		child.queue_free()

	var visible_areas: Array[AreaData] = []
	var area_by_id: Dictionary = {}
	for area: AreaData in DataLoader.load_all_areas():
		if not area.map_visible:
			continue
		visible_areas.append(area)
		area_by_id[area.id] = area

	var drawn_pairs: Dictionary = {}
	for area: AreaData in visible_areas:
		for connection_id: String in area.map_connections:
			if not area_by_id.has(connection_id):
				continue
			var pair_key := _connection_pair_key(area.id, connection_id)
			if drawn_pairs.has(pair_key):
				continue
			drawn_pairs[pair_key] = true
			var other: AreaData = area_by_id[connection_id]
			var start_center := _area_center(area)
			var end_center := _area_center(other)
			var start := _rect_edge_point(area.map_position, area.map_size, end_center)
			var end := _rect_edge_point(other.map_position, other.map_size, start_center)
			var required_item_id := _get_required_item_id(area, connection_id, other)
			var locked := _is_connection_locked(required_item_id)
			_draw_orthogonal_connection(start, end, locked)
			if locked:
				_draw_locked_marker(start, end, required_item_id)

	for area: AreaData in visible_areas:
		_map_root.add_child(_create_room_panel(area))

	if not _view_initialized:
		_view_initialized = true
		call_deferred("_center_on_current_room")
	else:
		_apply_view_transform()


func _on_zoom_in_pressed() -> void:
	_set_zoom(_zoom + ZOOM_STEP)


func _on_zoom_out_pressed() -> void:
	_set_zoom(_zoom - ZOOM_STEP)


func _set_zoom(value: float) -> void:
	var old_zoom := _zoom
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, _zoom):
		return
	var viewport_center := _viewport.size * 0.5
	var world_focus := (viewport_center - _pan_offset) / old_zoom
	_pan_offset = viewport_center - world_focus * _zoom
	_apply_view_transform()
	_update_zoom_controls()


func _center_on_current_room() -> void:
	var area := DataLoader.load_area(GameState.current_area_id)
	if not area.map_visible:
		return
	var room_center := _area_center(area)
	var viewport_center := _viewport.size * 0.5
	_pan_offset = viewport_center - room_center * _zoom
	_apply_view_transform()


func _apply_view_transform() -> void:
	_map_canvas.scale = Vector2(_zoom, _zoom)
	_map_canvas.position = _pan_offset


func _update_zoom_controls() -> void:
	_zoom_label.text = "%d%%" % int(round(_zoom * 100.0))
	_zoom_out_button.disabled = _zoom <= MIN_ZOOM + 0.001
	_zoom_in_button.disabled = _zoom >= MAX_ZOOM - 0.001


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_dragging = true
				_drag_start = mouse_button.position
				_pan_at_drag_start = _pan_offset
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_pan_offset = _pan_at_drag_start + (motion.position - _drag_start)
		_apply_view_transform()


func _area_center(area: AreaData) -> Vector2:
	return area.map_position + area.map_size * 0.5


func _rect_edge_point(rect_position: Vector2, rect_size: Vector2, toward: Vector2) -> Vector2:
	var center := rect_position + rect_size * 0.5
	var direction := toward - center
	if direction.is_zero_approx():
		return center
	var half := rect_size * 0.5
	var scale := INF
	if absf(direction.x) > 0.001:
		scale = minf(scale, half.x / absf(direction.x))
	if absf(direction.y) > 0.001:
		scale = minf(scale, half.y / absf(direction.y))
	return center + direction * scale


func _connection_pair_key(from_id: String, to_id: String) -> String:
	if from_id <= to_id:
		return "%s|%s" % [from_id, to_id]
	return "%s|%s" % [to_id, from_id]


func _get_required_item_id(from_area: AreaData, to_id: String, to_area: AreaData) -> String:
	if from_area.map_locked_connections.has(to_id):
		return str(from_area.map_locked_connections[to_id])
	if to_area.map_locked_connections.has(from_area.id):
		return str(to_area.map_locked_connections[from_area.id])
	return ""


func _is_connection_locked(required_item_id: String) -> bool:
	if required_item_id.is_empty():
		return false
	return not GameState.has_item(required_item_id)


func _draw_orthogonal_connection(start: Vector2, end: Vector2, locked: bool) -> void:
	var color := LOCKED_LINE_COLOR if locked else LINE_COLOR
	if absf(start.x - end.x) <= ALIGN_EPSILON or absf(start.y - end.y) <= ALIGN_EPSILON:
		_add_line_segment(start, end, color)
		return
	var corner := Vector2(end.x, start.y)
	_add_line_segment(start, corner, color)
	_add_line_segment(corner, end, color)


func _add_line_segment(from: Vector2, to: Vector2, color: Color) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 1.0:
		return
	var line := ColorRect.new()
	line.size = Vector2(length, LINE_THICKNESS)
	line.position = from
	line.rotation = delta.angle()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_root.add_child(line)


func _draw_locked_marker(start: Vector2, end: Vector2, required_item_id: String) -> void:
	var marker_pos := start.lerp(end, 0.5)
	if absf(start.x - end.x) > ALIGN_EPSILON and absf(start.y - end.y) > ALIGN_EPSILON:
		marker_pos = Vector2(end.x, start.y)

	var marker := Label.new()
	marker.text = "Locked"
	marker.add_theme_color_override("font_color", LOCKED_LINE_COLOR)
	marker.add_theme_font_size_override("font_size", 15)
	marker.add_theme_stylebox_override("normal", UiPalette.box(UiPalette.INK, UiPalette.DANGER, 1, 4, 0))
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.custom_minimum_size = Vector2(64.0, 20.0)
	marker.position = marker_pos - marker.custom_minimum_size * 0.5
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.tooltip_text = "Requires %s" % _get_item_display_name(required_item_id)
	_map_root.add_child(marker)


func _get_item_display_name(item_id: String) -> String:
	var items := DataLoader.load_items()
	if items.has(item_id):
		return (items[item_id] as ItemData).display_name
	return item_id


func _create_room_panel(area: AreaData) -> PanelContainer:
	var room := PanelContainer.new()
	room.position = area.map_position
	room.custom_minimum_size = area.map_size
	# Current room: lamp. Unvisited: barely there. Cleared: quiet bone. Still dangerous: scarf.
	var style: StyleBoxFlat
	if area.id == GameState.current_area_id:
		style = UiPalette.box(Color(UiPalette.LAMP, 0.16), UiPalette.LAMP, 2, 0, 0)
	elif not GameState.is_area_visited(area.id):
		style = UiPalette.box(Color(UiPalette.INK, 0.85), Color(UiPalette.RULE, 0.8), 1, 0, 0)
	elif GameState.is_area_cleared(area.id):
		style = UiPalette.box(Color(UiPalette.BONE, 0.07), UiPalette.BONE_DIM, 1, 0, 0)
	else:
		style = UiPalette.box(Color(UiPalette.SCARF, 0.18), UiPalette.SCARF, 2, 0, 0)
	room.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = area.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	room.add_child(label)
	return room
