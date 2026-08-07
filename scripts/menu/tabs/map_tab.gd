extends Control

var menu: Control

var _map_root: Control


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_root = Control.new()
	_map_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_map_root)


func refresh() -> void:
	for child: Node in _map_root.get_children():
		child.queue_free()
	var areas := DataLoader.load_all_areas()
	var area_by_id: Dictionary = {}
	for area: AreaData in areas:
		area_by_id[area.id] = area
	for area: AreaData in areas:
		for connection_id: String in area.map_connections:
			if not area_by_id.has(connection_id):
				continue
			var other: AreaData = area_by_id[connection_id]
			var line := ColorRect.new()
			var start := area.map_position + area.map_size * 0.5
			var end := other.map_position + other.map_size * 0.5
			var delta := end - start
			line.size = Vector2(maxf(delta.length(), 4.0), 3.0)
			line.position = start
			line.rotation = delta.angle()
			line.color = Color(0.35, 0.38, 0.42, 0.8)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_map_root.add_child(line)
	for area: AreaData in areas:
		var room := PanelContainer.new()
		room.position = area.map_position
		room.custom_minimum_size = area.map_size
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		if area.id == GameState.current_area_id:
			style.border_color = Color(0.95, 0.82, 0.28, 0.95)
			style.bg_color = Color(0.95, 0.82, 0.28, 0.18)
		elif not GameState.is_area_visited(area.id):
			style.border_color = Color(0.18, 0.2, 0.24, 0.9)
			style.bg_color = Color(0.1, 0.11, 0.13, 0.85)
		elif GameState.is_area_cleared(area.id):
			style.border_color = Color(0.28, 0.42, 0.58, 0.9)
			style.bg_color = Color(0.18, 0.28, 0.38, 0.55)
		else:
			style.border_color = Color(0.52, 0.28, 0.28, 0.9)
			style.bg_color = Color(0.34, 0.18, 0.18, 0.55)
		room.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = area.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		room.add_child(label)
		_map_root.add_child(room)
