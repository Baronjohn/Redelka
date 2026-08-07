class_name SaveManager
extends RefCounted

const SAVE_DIR: String = "user://saves/"
const AUTOSAVE_PATH: String = SAVE_DIR + "autosave.json"
const SLOT_PATH_FORMAT: String = SAVE_DIR + "slot_%02d.json"
const SLOT_COUNT: int = 99
const AUTOSAVE_SLOT_ID: int = 0
const DIFFICULTY_EASY: int = 0
const DIFFICULTY_NORMAL: int = 1
const DIFFICULTY_HARD: int = 2


static func ensure_save_dir() -> void:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


static func slot_path(slot: int) -> String:
	return SLOT_PATH_FORMAT % clampi(slot, 1, SLOT_COUNT)


static func build_meta(state: Dictionary) -> Dictionary:
	var area_id := str(state.get("current_area_id", ""))
	var area_name := area_id
	if not area_id.is_empty():
		var area := DataLoader.load_area(area_id)
		if area.id == area_id:
			area_name = area.display_name
	var party_level := 1
	var members: Array = state.get("party_members", []) as Array
	if not members.is_empty():
		var first := members[0] as Dictionary
		party_level = int(first.get("level", 1))
	return {
		"timestamp": int(Time.get_unix_time_from_system()),
		"area_id": area_id,
		"area_name": area_name,
		"party_level": party_level,
		"difficulty": int(state.get("difficulty", DIFFICULTY_NORMAL)),
	}


static func write_save(path: String, save_data: Dictionary) -> bool:
	ensure_save_dir()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: %s" % path)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	return true


static func read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func write_slot(slot: int, save_data: Dictionary) -> bool:
	return write_save(slot_path(slot), save_data)


static func write_autosave(save_data: Dictionary) -> bool:
	return write_save(AUTOSAVE_PATH, save_data)


static func read_slot(slot: int) -> Dictionary:
	return read_save(slot_path(slot))


static func read_autosave() -> Dictionary:
	return read_save(AUTOSAVE_PATH)


static func has_autosave() -> bool:
	return FileAccess.file_exists(AUTOSAVE_PATH)


static func get_slot_metadata(slot: int) -> Dictionary:
	var save_data := read_slot(slot)
	if save_data.is_empty():
		return {}
	return save_data.get("meta", {}) as Dictionary


static func get_autosave_metadata() -> Dictionary:
	var save_data := read_autosave()
	if save_data.is_empty():
		return {}
	return save_data.get("meta", {}) as Dictionary


static func format_timestamp(unix_time: int) -> String:
	return Time.get_datetime_string_from_unix_time(unix_time, true)


static func format_slot_label(slot: int, metadata: Dictionary, is_autosave: bool = false) -> String:
	var prefix := "Autosave" if is_autosave else "Slot %02d" % slot
	if metadata.is_empty():
		return "%s — Empty" % prefix
	return "%s — %s, Lv %d, %s, %s" % [
		prefix,
		str(metadata.get("area_name", "Unknown")),
		int(metadata.get("party_level", 1)),
		get_difficulty_name(int(metadata.get("difficulty", DIFFICULTY_NORMAL))),
		format_timestamp(int(metadata.get("timestamp", 0))),
	]


static func get_difficulty_name(difficulty: int) -> String:
	match difficulty:
		DIFFICULTY_EASY:
			return "Easy"
		DIFFICULTY_HARD:
			return "Hard"
	return "Normal"
