extends Control

const PartyStatsHelper = preload("res://scripts/data/party_stats.gd")

var menu: Control
var _stats_label: RichTextLabel


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_label = RichTextLabel.new()
	_stats_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_label.fit_content = true
	_stats_label.bbcode_enabled = true
	add_child(_stats_label)


func refresh() -> void:
	var character_id := str(menu.call("get_selected_character_id"))
	var characters := DataLoader.load_characters()
	if not characters.has(character_id):
		_stats_label.text = "No character selected."
		return
	var character: CharacterData = characters[character_id]
	var snapshot := GameState.get_member_snapshot(character_id)
	var base_stats := character.stats
	var progression_stats := PartyStatsHelper.get_progression_stats(character, snapshot) if snapshot != null else base_stats
	var effective_stats := GameState.get_effective_stats(character_id)
	var derived := GameState.get_derived_values(character_id)
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % character.display_name)
	if snapshot != null:
		lines.append("HP %d/%d  MP %d/%d%s" % [
			snapshot.current_hp,
			snapshot.max_hp,
			snapshot.current_mp,
			snapshot.max_mp,
			" (KO)" if snapshot.is_ko else "",
		])
		lines.append("Level %d  XP %d / %d" % [
			snapshot.level,
			snapshot.xp,
			PartyStatsHelper.get_xp_to_next_level(snapshot),
		])
		if snapshot.unspent_stat_points > 0:
			lines.append(
				"[i]Allocate points after your next level-up in battle.[/i]"
			)
	lines.append("")
	lines.append("[b]Base Stats[/b]")
	for stat_name: String in ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]:
		lines.append("%s: %d" % [stat_name.to_upper(), _get_stat_value(base_stats, stat_name)])
	lines.append("")
	lines.append("[b]Progression Stats[/b]")
	for stat_name: String in ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]:
		lines.append("%s: %d" % [stat_name.to_upper(), _get_stat_value(progression_stats, stat_name)])
	lines.append("")
	lines.append("[b]Effective Stats[/b]")
	for stat_name: String in ["str", "dex", "vit", "agi", "int", "mnd", "res", "luk"]:
		lines.append("%s: %d" % [stat_name.to_upper(), _get_stat_value(effective_stats, stat_name)])
	lines.append("")
	lines.append("[b]Derived Values[/b]")
	lines.append("Max HP: %d" % int(derived.get("max_hp", 0)))
	lines.append("Max MP: %d" % int(derived.get("max_mp", 0)))
	lines.append("Damage: %d-%d" % [int(derived.get("damage_min", 0)), int(derived.get("damage_max", 0))])
	lines.append("Attack Range: %d" % int(derived.get("attack_range", 1)))
	lines.append("Hit Modifier: %.0f" % float(derived.get("hit_mod", 0.0)))
	lines.append("VIT Mitigation: %d" % int(derived.get("vit_mitigation", 0)))
	lines.append("Move Range: %d" % int(derived.get("move_range", 0)))
	lines.append("Retreat Chance: %.0f" % float(derived.get("retreat_chance", 0.0)))
	_stats_label.text = "\n".join(lines)


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
