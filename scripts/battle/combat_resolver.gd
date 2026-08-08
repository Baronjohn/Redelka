class_name CombatResolver
extends RefCounted

const MasteryConstantsScript = preload("res://scripts/data/mastery_constants.gd")


static func roll_percent(chance: float) -> bool:
	return randf() * 100.0 <= chance


static func physical_hit_chance(attacker: CombatUnit, defender: CombatUnit) -> float:
	var attacker_stats := attacker.get_effective_stats_for_attack()
	var defender_dex := 0.0
	var defender_luk := 0.0
	if defender.enemy_data == null:
		defender_dex = float(defender.stats.dex)
		defender_luk = float(defender.stats.luk)
	var chance := (
		CombatConstants.BASE_HIT
		+ float(attacker_stats.dex)
		- (defender_dex + defender_luk * CombatConstants.LUK_WEIGHT)
	)
	return clampf(chance, CombatConstants.HIT_FLOOR, CombatConstants.HIT_CEILING)


static func spell_hit_chance(caster: CombatUnit, target: CombatUnit) -> float:
	var chance := CombatConstants.BASE_SPELL_HIT + float(caster.stats.mnd) - float(target.stats.res)
	return clampf(chance, CombatConstants.HIT_FLOOR, CombatConstants.HIT_CEILING)


static func resolve_physical_attack(
	attacker: CombatUnit,
	defender: CombatUnit,
	mastery_level: int = 1,
	enemy_action: EnemyActionData = null,
) -> Dictionary:
	var result := {
		"hit": false,
		"damage": 0,
		"hit_count": 0,
		"critical": false,
		"message": "",
	}
	var hit_chance := physical_hit_chance(attacker, defender)
	result["hit"] = roll_percent(hit_chance)
	if not result["hit"]:
		result["message"] = "%s missed %s." % [attacker.display_name, defender.display_name]
		return result

	var attacker_stats := attacker.get_effective_stats_for_attack()
	var hit_count := MasteryConstantsScript.resolve_combo_hit_count(mastery_level, attacker_stats)
	result["hit_count"] = hit_count
	var mitigation := int(float(defender.stats.vit) * CombatConstants.VIT_WEIGHT)
	if defender.enemy_data != null:
		mitigation = defender.enemy_data.vit
	var damage := _resolve_physical_damage(attacker, attacker_stats, mitigation, enemy_action)
	result["damage"] = damage
	if hit_count > 1:
		result["message"] = "%s hit %s x%d for %d." % [
			attacker.display_name,
			defender.display_name,
			hit_count,
			result["damage"],
		]
	else:
		if enemy_action != null:
			result["message"] = "%s used %s on %s for %d." % [
				attacker.display_name,
				enemy_action.display_name,
				defender.display_name,
				result["damage"],
			]
		else:
			result["message"] = "%s hit %s for %d." % [
				attacker.display_name,
				defender.display_name,
				result["damage"],
			]
	return result


static func resolve_spell(
	caster: CombatUnit,
	target: CombatUnit,
	spell: SpellData,
	effective_tier_base: int = -1,
) -> Dictionary:
	var tier_base := effective_tier_base if effective_tier_base >= 0 else spell.tier_base
	var result := {
		"hit": false,
		"amount": 0,
		"healing": spell.healing,
		"message": "",
	}
	if spell.healing:
		result["hit"] = true
		result["amount"] = tier_base + int(float(caster.stats.int_stat) * 0.5)
		result["message"] = "%s cast %s on %s for %d HP." % [
			caster.display_name, spell.display_name, target.display_name, result["amount"]
		]
		return result

	var hit_chance := spell_hit_chance(caster, target)
	result["hit"] = roll_percent(hit_chance)
	if not result["hit"]:
		result["message"] = "%s's %s missed %s." % [caster.display_name, spell.display_name, target.display_name]
		return result

	var multiplier := 1.0 + float(caster.stats.int_stat) * CombatConstants.INT_FACTOR
	result["amount"] = int(float(tier_base) * multiplier)
	if spell.damage_type == "fire":
		var resist := 0
		if target.enemy_data != null:
			resist = target.enemy_data.fire_resist
		result["amount"] = maxi(result["amount"] - resist, 1)
	result["message"] = "%s cast %s on %s for %d." % [
		caster.display_name, spell.display_name, target.display_name, result["amount"]
	]
	return result


static func resolve_skill(attacker: CombatUnit, defender: CombatUnit) -> Dictionary:
	var result := {
		"hit": false,
		"damage": 0,
		"message": "",
	}
	if attacker.skill == null:
		result["message"] = "Skill unavailable."
		return result
	if attacker.skill.mp_restore > 0:
		attacker.restore_mp(attacker.skill.mp_restore)
		result["hit"] = true
		result["message"] = "%s used %s and restored MP." % [attacker.display_name, attacker.skill.display_name]
		return result
	result["hit"] = roll_percent(physical_hit_chance(attacker, defender))
	if not result["hit"]:
		result["message"] = "%s's %s missed." % [attacker.display_name, attacker.skill.display_name]
		return result
	var mitigation := int(float(defender.stats.vit) * CombatConstants.VIT_WEIGHT)
	if defender.enemy_data != null:
		mitigation = defender.enemy_data.vit
	result["damage"] = maxi(attacker.stats.str - mitigation, 1)
	result["message"] = "%s used %s for %d." % [attacker.display_name, attacker.skill.display_name, result["damage"]]
	return result


static func resolve_retreat(unit: CombatUnit) -> bool:
	var chance := CombatConstants.RETREAT_BASE + float(unit.stats.agi) + float(unit.stats.luk) * 0.5
	return roll_percent(chance)


static func resolve_enemy_debuff(action: EnemyActionData, targets: Array[CombatUnit]) -> Dictionary:
	var messages: PackedStringArray = []
	for target: CombatUnit in targets:
		if not target.can_act():
			continue
		var before := target.stats.get_stat(action.stat_name)
		target.stats.add_stat(action.stat_name, action.amount)
		var after := maxi(target.stats.get_stat(action.stat_name), 1)
		if after != target.stats.get_stat(action.stat_name):
			target.stats.add_stat(action.stat_name, after - target.stats.get_stat(action.stat_name))
		var delta := after - before
		if delta == 0:
			continue
		messages.append("%s's %s %s by %d." % [
			target.display_name,
			action.stat_name.to_upper(),
			"rose" if delta > 0 else "fell",
			absi(delta),
		])
	return {
		"ok": not messages.is_empty(),
		"message": ", ".join(messages),
	}


static func _resolve_physical_damage(
	attacker: CombatUnit,
	attacker_stats: StatBlock,
	mitigation: int,
	enemy_action: EnemyActionData = null,
) -> int:
	if attacker.enemy_data != null and enemy_action != null:
		var rolled := randi_range(enemy_action.damage_min, enemy_action.damage_max)
		return maxi(rolled - mitigation, 1)
	if attacker.enemy_data != null:
		return 1
	return maxi(attacker_stats.str - mitigation, 1)
