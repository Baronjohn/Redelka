class_name EnemyData
extends RefCounted

var id: String = ""
var display_name: String = ""
var move_range: int = 2
var attack_range: int = 1
var hp: int = 0
var agi: int = 0
var dex: int = 10
var vit: int = 0
var res: int = 0
var fire_resist: int = 0
var xp_reward: int = 0
var actions: Array[EnemyActionData] = []
var drops: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> EnemyData:
	var enemy := EnemyData.new()
	var stats: Dictionary = data.get("stats", {}) as Dictionary
	enemy.id = str(data.get("id", ""))
	enemy.display_name = str(data.get("name", ""))
	enemy.move_range = int(data.get("move_range", 2))
	enemy.attack_range = int(data.get("attack_range", 1))
	enemy.hp = int(stats.get("hp", 30))
	enemy.agi = int(stats.get("agi", 8))
	enemy.dex = int(stats.get("dex", 10))
	enemy.vit = int(stats.get("vit", stats.get("def", 5)))
	enemy.res = int(stats.get("res", 5))
	enemy.fire_resist = int(stats.get("fire_resist", 0))
	enemy.xp_reward = int(data.get("xp_reward", 0))
	for action_entry: Variant in data.get("actions", []) as Array:
		enemy.actions.append(EnemyActionData.from_dict(action_entry as Dictionary))
	enemy._apply_action_defaults()
	for drop_entry: Variant in data.get("drops", []) as Array:
		enemy.drops.append(drop_entry as Dictionary)
	return enemy


func _apply_action_defaults() -> void:
	if actions.is_empty():
		return
	var max_attack_range := attack_range
	for action: EnemyActionData in actions:
		if action.action_type == EnemyActionData.TYPE_ATTACK:
			max_attack_range = maxi(max_attack_range, action.range_tiles)
	attack_range = max_attack_range


func get_action_chance_total() -> int:
	var total := 0
	for action: EnemyActionData in actions:
		total += action.chance
	return total
