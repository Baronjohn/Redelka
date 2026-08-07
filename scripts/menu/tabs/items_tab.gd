extends Control

var menu: Control
var _sort_mode_index: int = 0
var _selected_item_id: String = ""
var _awaiting_target: bool = false

var _list: ItemList
var _sort_button: Button
var _use_button: Button
var _target_list: ItemList


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	var buttons := HBoxContainer.new()
	_sort_button = Button.new()
	_sort_button.text = "Sort: Name"
	_sort_button.focus_mode = Control.FOCUS_ALL
	_sort_button.pressed.connect(_on_sort_pressed)
	buttons.add_child(_sort_button)
	_use_button = Button.new()
	_use_button.text = "Use"
	_use_button.focus_mode = Control.FOCUS_ALL
	_use_button.pressed.connect(_on_use_pressed)
	buttons.add_child(_use_button)
	vbox.add_child(buttons)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	vbox.add_child(_list)
	_target_list = ItemList.new()
	_target_list.visible = false
	_target_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_target_list.item_selected.connect(_on_target_selected)
	vbox.add_child(_target_list)
	refresh()


func refresh() -> void:
	_populate_items()
	if menu != null:
		menu.call("show_message", "Select an item.")


func _populate_items() -> void:
	_list.clear()
	var items := DataLoader.load_items()
	var entries: Array[Dictionary] = []
	for item_id: String in GameState.inventory.keys():
		var count := int(GameState.inventory[item_id])
		if count <= 0:
			continue
		if not items.has(item_id):
			continue
		var item: ItemData = items[item_id]
		entries.append({
			"id": item_id,
			"name": item.display_name,
			"count": count,
			"type": item.item_type,
		})
	match _sort_mode_index:
		0:
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a["name"]) < str(b["name"])
			)
		1:
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["count"]) > int(b["count"])
			)
		2:
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a["type"]) < str(b["type"])
			)
	for entry: Dictionary in entries:
		var index := _list.item_count
		_list.add_item("%s x%d" % [entry["name"], entry["count"]])
		_list.set_item_metadata(index, entry["id"])


func _on_sort_pressed() -> void:
	_sort_mode_index = (_sort_mode_index + 1) % 3
	var labels := ["Name", "Quantity", "Type"]
	_sort_button.text = "Sort: %s" % labels[_sort_mode_index]
	_populate_items()


func _on_item_selected(index: int) -> void:
	_selected_item_id = str(_list.get_item_metadata(index))
	_awaiting_target = false
	_target_list.visible = false


func _on_use_pressed() -> void:
	if _selected_item_id.is_empty():
		menu.call("show_message", "Select an item first.")
		return
	_awaiting_target = true
	_target_list.visible = true
	_target_list.clear()
	var items := DataLoader.load_items()
	var item: ItemData = items[_selected_item_id]
	var characters := DataLoader.load_characters()
	for member_variant: Variant in GameState.party_members:
		var snapshot := member_variant as PartyMemberSnapshot
		var character: CharacterData = characters[snapshot.character_id]
		var valid := false
		if item.revive:
			valid = snapshot.is_ko
		else:
			valid = not snapshot.is_ko and snapshot.current_hp < snapshot.max_hp
		var index := _target_list.item_count
		_target_list.add_item("%s%s" % [character.display_name, "" if valid else " (invalid)"])
		_target_list.set_item_metadata(index, snapshot.character_id)
		_target_list.set_item_disabled(index, not valid)
	menu.call("show_message", "Choose a target.")


func _on_target_selected(index: int) -> void:
	if not _awaiting_target:
		return
	var target_id := str(_target_list.get_item_metadata(index))
	var result := GameState.use_item_outside_battle(_selected_item_id, target_id)
	menu.call("show_message", result)
	_awaiting_target = false
	_target_list.visible = false
	menu.call("refresh_all")
