class_name PlaceholderIcons
extends RefCounted

const SIZE: int = 24

static var _cache: Dictionary = {}


static func get_stat_icon(stat_name: String) -> Texture2D:
	return _get_or_create("stat:%s" % stat_name, _stat_color(stat_name))


static func get_weapon_class_icon(weapon_class: String) -> Texture2D:
	return _get_or_create("weapon_class:%s" % weapon_class, _weapon_class_color(weapon_class))


static func get_slot_icon(slot_name: String) -> Texture2D:
	var slot_key := _normalize_slot_key(slot_name)
	return _get_or_create("slot:%s" % slot_key, _slot_color(slot_key))


static func get_spell_mastery_icon(mastery_id: String) -> Texture2D:
	return _get_or_create("spell_mastery:%s" % mastery_id, _spell_mastery_color(mastery_id))


static func _normalize_slot_key(slot_name: String) -> String:
	match slot_name:
		EquipmentData.SLOT_ACCESSORY_1, EquipmentData.SLOT_ACCESSORY_2:
			return "accessory"
		_:
			return slot_name


static func _get_or_create(cache_key: String, color: Color) -> Texture2D:
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color.darkened(0.35))
	for x: int in range(SIZE):
		image.set_pixel(x, 0, color.lightened(0.2))
		image.set_pixel(x, SIZE - 1, color.darkened(0.5))
	for y: int in range(SIZE):
		image.set_pixel(0, y, color.lightened(0.2))
		image.set_pixel(SIZE - 1, y, color.darkened(0.5))
	image.fill_rect(Rect2i(4, 4, SIZE - 8, SIZE - 8), color)
	var texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture


static func _stat_color(stat_name: String) -> Color:
	match stat_name:
		"str":
			return Color(0.82, 0.28, 0.24)
		"dex":
			return Color(0.92, 0.78, 0.18)
		"vit":
			return Color(0.78, 0.48, 0.18)
		"agi":
			return Color(0.28, 0.72, 0.36)
		"int":
			return Color(0.28, 0.48, 0.92)
		"mnd":
			return Color(0.58, 0.36, 0.82)
		"res":
			return Color(0.22, 0.72, 0.78)
		"luk":
			return Color(0.88, 0.72, 0.22)
		_:
			return Color(0.5, 0.5, 0.5)


static func _weapon_class_color(weapon_class: String) -> Color:
	match weapon_class:
		"sword":
			return Color(0.62, 0.66, 0.74)
		"bow":
			return Color(0.52, 0.38, 0.24)
		"staff":
			return Color(0.46, 0.34, 0.22)
		"dagger":
			return Color(0.72, 0.74, 0.78)
		_:
			return Color(0.55, 0.55, 0.55)


static func _slot_color(slot_key: String) -> Color:
	match slot_key:
		"weapon":
			return Color(0.58, 0.62, 0.68)
		"armor":
			return Color(0.42, 0.5, 0.58)
		"helmet":
			return Color(0.66, 0.58, 0.38)
		"accessory":
			return Color(0.62, 0.38, 0.72)
		_:
			return Color(0.5, 0.5, 0.5)


static func _spell_mastery_color(mastery_id: String) -> Color:
	match mastery_id:
		"fire":
			return Color(0.92, 0.38, 0.12)
		_:
			return Color(0.5, 0.5, 0.5)
