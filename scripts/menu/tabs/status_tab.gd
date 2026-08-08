extends Control

const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")
const MasteryConstantsScript = preload("res://scripts/data/mastery_constants.gd")
const PlaceholderIconsScript = preload("res://scripts/ui/placeholder_icons.gd")

const STAT_NAMES: Array[String] = ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]

var menu: Control
var _sub_tabs: TabContainer
var _overview_label: RichTextLabel
var _stats_grid: GridContainer
var _derived_grid: GridContainer
var _weapon_list: ItemList
var _spell_list: ItemList


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_tabs = TabContainer.new()
	_sub_tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_sub_tabs)
	_build_overview_page()
	_build_stats_page()
	_build_derived_page()
	_build_mastery_page()
	_sub_tabs.tab_changed.connect(_on_sub_tab_changed)


func _on_sub_tab_changed(tab: int) -> void:
	if menu == null:
		return
	menu.call("show_message", "Status — %s." % _sub_tabs.get_tab_title(tab))


func refresh() -> void:
	var character_id := str(menu.call("get_selected_character_id"))
	var characters := DataLoader.load_characters()
	if not characters.has(character_id):
		_overview_label.text = "No character selected."
		_clear_stat_rows()
		_clear_derived_rows()
		_weapon_list.clear()
		_spell_list.clear()
		return
	var character: CharacterData = characters[character_id]
	var snapshot := GameState.get_member_snapshot(character_id)
	var base_stats := character.stats
	var progression_stats := PartyStatsHelper.get_progression_stats(character, snapshot) if snapshot != null else base_stats
	var effective_stats := GameState.get_effective_stats(character_id)
	var derived := GameState.get_derived_values(character_id)

	_populate_overview(character, snapshot, derived)
	_populate_stats(base_stats, progression_stats, effective_stats)
	_populate_derived(derived)
	_populate_weapon_mastery(character_id)
	_populate_spell_mastery(character_id)
	menu.call("show_message", "Viewing %s — %s." % [character.display_name, _sub_tabs.get_tab_title(_sub_tabs.current_tab)])


func _build_overview_page() -> void:
	var page := MarginContainer.new()
	page.name = "Overview"
	page.add_theme_constant_override("margin_left", 8)
	page.add_theme_constant_override("margin_top", 8)
	page.add_theme_constant_override("margin_right", 8)
	page.add_theme_constant_override("margin_bottom", 8)
	_sub_tabs.add_child(page)
	_sub_tabs.set_tab_title(_sub_tabs.get_tab_count() - 1, "Overview")

	_overview_label = RichTextLabel.new()
	_overview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_label.bbcode_enabled = true
	_overview_label.fit_content = true
	_overview_label.scroll_active = false
	page.add_child(_overview_label)


func _build_stats_page() -> void:
	var page := MarginContainer.new()
	page.name = "Stats"
	page.add_theme_constant_override("margin_left", 8)
	page.add_theme_constant_override("margin_top", 8)
	page.add_theme_constant_override("margin_right", 8)
	page.add_theme_constant_override("margin_bottom", 8)
	_sub_tabs.add_child(page)
	_sub_tabs.set_tab_title(_sub_tabs.get_tab_count() - 1, "Stats")

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 5
	_stats_grid.add_theme_constant_override("h_separation", 24)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stats_grid)

	for header: String in ["", "Stat", "Base", "Growth", "Effective"]:
		_add_grid_header(_stats_grid, header)


func _build_derived_page() -> void:
	var page := MarginContainer.new()
	page.name = "Derived"
	page.add_theme_constant_override("margin_left", 8)
	page.add_theme_constant_override("margin_top", 8)
	page.add_theme_constant_override("margin_right", 8)
	page.add_theme_constant_override("margin_bottom", 8)
	_sub_tabs.add_child(page)
	_sub_tabs.set_tab_title(_sub_tabs.get_tab_count() - 1, "Derived")

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	_derived_grid = GridContainer.new()
	_derived_grid.columns = 2
	_derived_grid.add_theme_constant_override("h_separation", 32)
	_derived_grid.add_theme_constant_override("v_separation", 6)
	_derived_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_derived_grid)


func _build_mastery_page() -> void:
	var page := MarginContainer.new()
	page.name = "Mastery"
	page.add_theme_constant_override("margin_left", 8)
	page.add_theme_constant_override("margin_top", 8)
	page.add_theme_constant_override("margin_right", 8)
	page.add_theme_constant_override("margin_bottom", 8)
	_sub_tabs.add_child(page)
	_sub_tabs.set_tab_title(_sub_tabs.get_tab_count() - 1, "Mastery")

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	page.add_child(split)

	var weapon_panel := _build_mastery_panel("Weapon Classes")
	_weapon_list = weapon_panel.list
	split.add_child(weapon_panel.root)

	var spell_panel := _build_mastery_panel("Spell Mastery")
	_spell_list = spell_panel.list
	split.add_child(spell_panel.root)


func _build_mastery_panel(title: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)

	var heading := Label.new()
	heading.text = title
	root.add_child(heading)

	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.focus_mode = Control.FOCUS_NONE
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(list)

	return {"root": root, "list": list}


func _populate_overview(
	character: CharacterData,
	snapshot: PartyMemberSnapshot,
	derived: Dictionary,
) -> void:
	var lines: PackedStringArray = []
	lines.append("[font_size=20][b]%s[/b][/font_size]" % character.display_name)
	if snapshot != null:
		lines.append("")
		lines.append("[b]Condition[/b]")
		lines.append("HP %d / %d   MP %d / %d%s" % [
			snapshot.current_hp,
			snapshot.max_hp,
			snapshot.current_mp,
			snapshot.max_mp,
			"   [color=red](KO)[/color]" if snapshot.is_ko else "",
		])
		lines.append("Level %d   XP %d / %d" % [
			snapshot.level,
			snapshot.xp,
			PartyStatsHelper.get_xp_to_next_level(snapshot),
		])
		if snapshot.unspent_stat_points > 0:
			lines.append("[i]%d stat point(s) pending next level-up.[/i]" % snapshot.unspent_stat_points)
	lines.append("")
	lines.append("[b]Combat Snapshot[/b]")
	lines.append("Attack %d   Range %d   Move %d" % [
		int(derived.get("attack_power", 0)),
		int(derived.get("attack_range", 1)),
		int(derived.get("move_range", 0)),
	])
	lines.append("Hit %.0f   Retreat %.0f%%" % [
		float(derived.get("hit_mod", 0.0)),
		float(derived.get("retreat_chance", 0.0)),
	])
	lines.append("")
	lines.append("[color=gray]Use the tabs above for full stats, derived values, and mastery.[/color]")
	_overview_label.text = "\n".join(lines)


func _populate_stats(
	base_stats: StatBlock,
	progression_stats: StatBlock,
	effective_stats: StatBlock,
) -> void:
	_clear_stat_rows()
	for stat_name: String in STAT_NAMES:
		_add_grid_icon(_stats_grid, PlaceholderIconsScript.get_stat_icon(stat_name))
		_add_grid_cell(_stats_grid, stat_name.to_upper())
		_add_grid_cell(_stats_grid, str(_get_stat_value(base_stats, stat_name)))
		_add_grid_cell(_stats_grid, str(_get_stat_value(progression_stats, stat_name)))
		var effective_value := _get_stat_value(effective_stats, stat_name)
		var base_value := _get_stat_value(base_stats, stat_name)
		var delta := effective_value - base_value
		if delta > 0:
			_add_grid_cell(_stats_grid, "%d [color=green](+%d)[/color]" % [effective_value, delta], true)
		elif delta < 0:
			_add_grid_cell(_stats_grid, "%d [color=red](%d)[/color]" % [effective_value, delta], true)
		else:
			_add_grid_cell(_stats_grid, str(effective_value))


func _populate_derived(derived: Dictionary) -> void:
	_clear_derived_rows()
	var entries: Array[Dictionary] = [
		{"label": "Max HP", "value": str(int(derived.get("max_hp", 0)))},
		{"label": "Max MP", "value": str(int(derived.get("max_mp", 0)))},
		{"label": "Attack Power", "value": str(int(derived.get("attack_power", 0)))},
		{"label": "Attack Range", "value": str(int(derived.get("attack_range", 1)))},
		{"label": "Move Range", "value": str(int(derived.get("move_range", 0)))},
		{"label": "Hit Modifier", "value": "%.0f" % float(derived.get("hit_mod", 0.0))},
		{"label": "VIT Mitigation", "value": str(int(derived.get("vit_mitigation", 0)))},
		{"label": "Retreat Chance", "value": "%.0f" % float(derived.get("retreat_chance", 0.0))},
	]
	for entry: Dictionary in entries:
		_add_derived_row(str(entry["label"]), str(entry["value"]))


func _populate_weapon_mastery(character_id: String) -> void:
	_weapon_list.clear()
	for weapon_class: String in MasteryConstantsScript.WEAPON_CLASSES:
		var progress: Dictionary = GameState.get_weapon_mastery_progress(character_id, weapon_class)
		var level := int(progress.get("level", 1))
		var xp_to_next := int(progress.get("xp_to_next", 0))
		var xp := int(progress.get("xp", 0))
		var progress_text := "%d / %d XP" % [xp, xp_to_next] if xp_to_next > 0 else "Mastered"
		var index := _weapon_list.item_count
		_weapon_list.add_item("%s  —  Lv %d  (%s)" % [weapon_class.capitalize(), level, progress_text])
		_weapon_list.set_item_icon(index, PlaceholderIconsScript.get_weapon_class_icon(weapon_class))
		if xp_to_next <= 0:
			_weapon_list.set_item_custom_fg_color(index, Color(0.75, 0.85, 0.55))


func _populate_spell_mastery(character_id: String) -> void:
	_spell_list.clear()
	for mastery_id: String in MasteryConstantsScript.SPELL_MASTERY_TYPES:
		var progress: Dictionary = GameState.get_spell_mastery_progress_for_type(character_id, mastery_id)
		var display_name := MasteryConstantsScript.get_spell_mastery_display_name(mastery_id)
		var tier := int(progress.get("tier", 0))
		var index := _spell_list.item_count
		if tier <= 0:
			_spell_list.add_item("%s  —  Locked" % display_name)
			_spell_list.set_item_icon(index, PlaceholderIconsScript.get_spell_mastery_icon(mastery_id))
			_spell_list.set_item_custom_fg_color(index, Color(0.55, 0.55, 0.55))
			continue
		var xp_to_next := int(progress.get("xp_to_next", 0))
		var xp := int(progress.get("xp", 0))
		var progress_text := "%d / %d XP" % [xp, xp_to_next] if xp_to_next > 0 else "Mastered"
		_spell_list.add_item("%s  —  Tier %d  (%s)" % [display_name, tier, progress_text])
		_spell_list.set_item_icon(index, PlaceholderIconsScript.get_spell_mastery_icon(mastery_id))
		if xp_to_next <= 0:
			_spell_list.set_item_custom_fg_color(index, Color(0.75, 0.85, 0.55))


func _clear_stat_rows() -> void:
	while _stats_grid.get_child_count() > 5:
		var child: Node = _stats_grid.get_child(5)
		_stats_grid.remove_child(child)
		child.queue_free()


func _add_grid_icon(grid: GridContainer, texture: Texture2D) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	grid.add_child(icon)


func _clear_derived_rows() -> void:
	for child: Node in _derived_grid.get_children():
		child.queue_free()


func _add_grid_header(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.28))
	grid.add_child(label)


func _add_grid_cell(grid: GridContainer, text: String, bbcode: bool = false) -> void:
	if bbcode:
		var rich_label := RichTextLabel.new()
		rich_label.custom_minimum_size = Vector2(72, 0)
		rich_label.fit_content = true
		rich_label.bbcode_enabled = true
		rich_label.scroll_active = false
		rich_label.text = text
		grid.add_child(rich_label)
		return
	var plain_label := Label.new()
	plain_label.text = text
	grid.add_child(plain_label)


func _add_derived_row(label_text: String, value_text: String) -> void:
	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_derived_grid.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_derived_grid.add_child(value_label)


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
