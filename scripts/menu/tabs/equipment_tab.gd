extends Control

const EquipmentDataScript = preload("res://scripts/data/equipment_data.gd")
const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")

var menu: Control
var _selected_slot: String = "weapon"
var _pending_candidate: Dictionary = {}

var _slot_list: ItemList
var _candidate_list: ItemList
var _preview_label: RichTextLabel
var _hint_label: Label


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	_slot_list = ItemList.new()
	_slot_list.custom_minimum_size = Vector2(280, 220)
	_slot_list.allow_reselect = true
	_slot_list.select_mode = ItemList.SELECT_SINGLE
	_slot_list.item_selected.connect(_on_slot_selected)
	root.add_child(_slot_list)

	for slot_name: String in EquipmentDataScript.ALL_SLOTS:
		var index := _slot_list.item_count
		_slot_list.add_item(EquipmentDataScript.slot_label(slot_name))
		_slot_list.set_item_metadata(index, slot_name)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)

	_hint_label = Label.new()
	_hint_label.text = "Select a slot, then click an item to preview. Click again to confirm."
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_hint_label)
	_candidate_list = ItemList.new()
	_candidate_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_candidate_list.custom_minimum_size = Vector2(0, 180)
	_candidate_list.allow_reselect = true
	_candidate_list.item_clicked.connect(_on_candidate_clicked)
	_candidate_list.item_activated.connect(_on_candidate_activated)
	right.add_child(_candidate_list)
	_preview_label = RichTextLabel.new()
	_preview_label.custom_minimum_size = Vector2(0, 160)
	_preview_label.fit_content = true
	_preview_label.bbcode_enabled = true
	right.add_child(_preview_label)
	_refresh_slots()
	_select_slot(EquipmentDataScript.SLOT_WEAPON, false)


func _on_slot_selected(index: int) -> void:
	var slot_name := str(_slot_list.get_item_metadata(index))
	_select_slot(slot_name, true)


func refresh() -> void:
	_pending_candidate = {}
	_refresh_slots()
	_populate_candidates()
	_candidate_list.deselect_all()
	_update_preview()


func _select_slot(slot_name: String, from_user: bool) -> void:
	_selected_slot = slot_name
	_pending_candidate = {}
	_refresh_slots()
	_populate_candidates()
	_candidate_list.deselect_all()
	_update_preview()
	if from_user:
		menu.call("show_message", "Select an item to preview.")


func _refresh_slots() -> void:
	var character_id := str(menu.call("get_selected_character_id"))
	for index: int in _slot_list.item_count:
		var slot_name := str(_slot_list.get_item_metadata(index))
		var equipped_name := GameState.get_equipped_item_name(character_id, slot_name)
		_slot_list.set_item_text(index, "%s: %s" % [EquipmentDataScript.slot_label(slot_name), equipped_name])
		if slot_name == _selected_slot:
			_slot_list.select(index, false)


func _populate_candidates() -> void:
	_candidate_list.clear()
	var character_id := str(menu.call("get_selected_character_id"))
	for candidate: Dictionary in GameState.get_equipment_candidates_for_slot(character_id, _selected_slot):
		var index := _candidate_list.item_count
		_candidate_list.add_item(_format_candidate_label(candidate))
		_candidate_list.set_item_metadata(index, candidate)


func _on_candidate_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_handle_candidate_pick(index)


func _on_candidate_activated(index: int) -> void:
	_handle_candidate_pick(index)


func _handle_candidate_pick(index: int) -> void:
	var candidate := _candidate_list.get_item_metadata(index) as Dictionary
	if _candidates_match(candidate, _pending_candidate):
		_confirm_change(candidate)
		return
	_pending_candidate = candidate.duplicate()
	_candidate_list.select(index)
	_update_preview()
	if str(candidate.get("source", "")) == "current":
		menu.call("show_message", "Previewing unequip. Click again to confirm.")
	else:
		menu.call("show_message", "Previewing equip. Click again to confirm.")


func _confirm_change(candidate: Dictionary) -> void:
	var character_id := str(menu.call("get_selected_character_id"))
	var item_id := str(candidate.get("item_id", ""))
	var result: String
	if str(candidate.get("source", "")) == "current":
		result = GameState.unequip_slot(character_id, _selected_slot)
	else:
		result = GameState.equip_item(character_id, _selected_slot, item_id)
	_pending_candidate = {}
	menu.call("show_message", result)
	menu.call("refresh_all")


func _get_equipped_id() -> String:
	var character_id := str(menu.call("get_selected_character_id"))
	return str(GameState.get_loadout(character_id).get(_selected_slot, ""))


func _update_preview() -> void:
	var character_id := str(menu.call("get_selected_character_id"))
	var characters := DataLoader.load_characters()
	var character: CharacterData = characters[character_id]
	var current_stats := GameState.get_effective_stats(character_id)
	var preview_loadout := GameState.get_loadout(character_id).duplicate()
	var equipped_id := _get_equipped_id()
	var pending_item_id := str(_pending_candidate.get("item_id", ""))
	if _pending_candidate.is_empty():
		preview_loadout[_selected_slot] = equipped_id
	elif str(_pending_candidate.get("source", "")) == "current":
		preview_loadout[_selected_slot] = ""
	else:
		preview_loadout[_selected_slot] = pending_item_id
	var preview_stats := PartyStatsHelper.get_effective_stats(character, preview_loadout)
	var lines: PackedStringArray = []
	if _pending_candidate.is_empty():
		lines.append("[i]Select an item to preview changes.[/i]")
	else:
		var action := "Unequip" if str(_pending_candidate.get("source", "")) == "current" else "Equip"
		lines.append("[b]%s preview[/b] — click item again to confirm" % action)
		lines.append("")
	for stat_name: String in ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]:
		var current_value := _get_stat_value(current_stats, stat_name)
		var preview_value := _get_stat_value(preview_stats, stat_name)
		var delta := preview_value - current_value
		var delta_text := ""
		if _pending_candidate.is_empty():
			delta_text = ""
		elif delta > 0:
			delta_text = " [color=green](+%d)[/color]" % delta
		elif delta < 0:
			delta_text = " [color=red](%d)[/color]" % delta
		lines.append("%s: %d%s" % [stat_name.to_upper(), preview_value, delta_text])
	_preview_label.text = "\n".join(lines)


func _format_candidate_label(candidate: Dictionary) -> String:
	var item_id := str(candidate.get("item_id", ""))
	var label := _get_item_display_name(item_id)
	match str(candidate.get("source", "")):
		"current":
			return "%s (Equipped)" % label
		"pool":
			return label
		"equipped":
			var owner_id := str(candidate.get("owner_id", ""))
			var character_id := str(menu.call("get_selected_character_id"))
			if owner_id == character_id:
				return "%s (Equipped)" % label
			var characters := DataLoader.load_characters()
			if characters.has(owner_id):
				return "%s (%s)" % [label, (characters[owner_id] as CharacterData).display_name]
			return "%s (%s)" % [label, owner_id]
	return label


func _candidates_match(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("item_id", "")) != str(b.get("item_id", "")):
		return false
	if str(a.get("source", "")) != str(b.get("source", "")):
		return false
	if str(a.get("source", "")) == "equipped":
		return (
			str(a.get("owner_id", "")) == str(b.get("owner_id", ""))
			and str(a.get("owner_slot", "")) == str(b.get("owner_slot", ""))
		)
	return true


func _get_item_display_name(item_id: String) -> String:
	if _selected_slot == EquipmentDataScript.SLOT_WEAPON:
		var weapons := DataLoader.load_weapons()
		if weapons.has(item_id):
			return (weapons[item_id] as WeaponData).display_name
	var equipment := DataLoader.load_equipment()
	if equipment.has(item_id):
		return equipment[item_id].display_name
	return item_id


func _get_stat_value(stats: StatBlock, stat_name: String) -> int:
	match stat_name:
		"str":
			return stats.str
		"dex":
			return stats.dex
		"vit":
			return stats.vit
		"agi":
			return stats.agi
		"int":
			return stats.int_stat
		"mnd":
			return stats.mnd
		"res":
			return stats.res
		"luk":
			return stats.luk
	return 0
