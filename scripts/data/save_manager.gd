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

enum SaveReadStatus { OK, MISSING, CORRUPT, INVALID }


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
	return read_save_detailed(path).get("data", {}) as Dictionary


static func read_save_detailed(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"status": SaveReadStatus.MISSING,
			"data": {},
			"message": "Save file not found.",
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"status": SaveReadStatus.CORRUPT,
			"data": {},
			"message": "Could not read save file.",
		}
	var text := file.get_as_text()
	if text.strip_edges().is_empty():
		return {
			"status": SaveReadStatus.CORRUPT,
			"data": {},
			"message": "Save file is empty.",
		}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return {
			"status": SaveReadStatus.CORRUPT,
			"data": {},
			"message": "Save file is corrupted.",
		}
	var data := parsed as Dictionary
	var validation := validate_save_data(data)
	if not bool(validation.get("ok", false)):
		return {
			"status": SaveReadStatus.INVALID,
			"data": data,
			"message": str(validation.get("message", "Save file is invalid.")),
		}
	return {
		"status": SaveReadStatus.OK,
		"data": data,
		"message": "",
	}


static func validate_save_data(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if state == null or not state is Dictionary:
		return {"ok": false, "message": "Save file is missing game state."}
	var state_dict := state as Dictionary
	var members: Variant = state_dict.get("party_members")
	if members == null or not members is Array:
		return {"ok": false, "message": "Save file has invalid party data."}
	return {"ok": true, "message": ""}


static func read_slot_detailed(slot: int) -> Dictionary:
	return read_save_detailed(slot_path(slot))


static func read_autosave_detailed() -> Dictionary:
	return read_save_detailed(AUTOSAVE_PATH)


static func get_slot_read_status(slot: int) -> SaveReadStatus:
	return read_slot_detailed(slot).get("status", SaveReadStatus.MISSING) as SaveReadStatus


static func get_autosave_read_status() -> SaveReadStatus:
	if not FileAccess.file_exists(AUTOSAVE_PATH):
		return SaveReadStatus.MISSING
	return read_autosave_detailed().get("status", SaveReadStatus.CORRUPT) as SaveReadStatus


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
	var read_result := read_slot_detailed(slot)
	if int(read_result.get("status", SaveReadStatus.MISSING)) != SaveReadStatus.OK:
		return {}
	var save_data := read_result.get("data", {}) as Dictionary
	return save_data.get("meta", {}) as Dictionary


static func get_autosave_metadata() -> Dictionary:
	var read_result := read_autosave_detailed()
	if int(read_result.get("status", SaveReadStatus.MISSING)) != SaveReadStatus.OK:
		return {}
	var save_data := read_result.get("data", {}) as Dictionary
	return save_data.get("meta", {}) as Dictionary


static func format_timestamp(unix_time: int) -> String:
	return Time.get_datetime_string_from_unix_time(unix_time, true)


static func format_slot_label(
	slot: int,
	metadata: Dictionary,
	is_autosave: bool = false,
	read_status: SaveReadStatus = SaveReadStatus.OK,
) -> String:
	var prefix := "Autosave" if is_autosave else "Slot %02d" % slot
	if read_status == SaveReadStatus.CORRUPT or read_status == SaveReadStatus.INVALID:
		return "%s — Corrupt save" % prefix
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
