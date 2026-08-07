class_name EnemyData
extends RefCounted

var id: String = ""
var display_name: String = ""
var move_range: int = 2
var attack_range: int = 1
var damage_min: int = 0
var damage_max: int = 0
var damage_type: String = "physical"
var hp: int = 0
var agi: int = 0
var hit: int = 0
var def_stat: int = 0
var res: int = 0
var fire_resist: int = 0
var drops: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> EnemyData:
	var enemy := EnemyData.new()
	var stats: Dictionary = data.get("stats", {}) as Dictionary
	enemy.id = str(data.get("id", ""))
	enemy.display_name = str(data.get("name", ""))
	enemy.move_range = int(data.get("move_range", 2))
	enemy.attack_range = int(data.get("attack_range", 1))
	enemy.damage_min = int(data.get("damage_min", 0))
	enemy.damage_max = int(data.get("damage_max", 0))
	enemy.damage_type = str(data.get("damage_type", "physical"))
	enemy.hp = int(stats.get("hp", 30))
	enemy.agi = int(stats.get("agi", 8))
	enemy.hit = int(stats.get("hit", 70))
	enemy.def_stat = int(stats.get("def", 5))
	enemy.res = int(stats.get("res", 5))
	enemy.fire_resist = int(stats.get("fire_resist", 0))
	for drop_entry: Variant in data.get("drops", []) as Array:
		enemy.drops.append(drop_entry as Dictionary)
	return enemy
