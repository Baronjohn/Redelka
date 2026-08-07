extends Node3D

const PROTAGONIST_SCENE: PackedScene = preload("res://scenes/explore/protagonist.tscn")
const OverworldEnemyScript = preload("res://scripts/explore/overworld_enemy.gd")
const ENEMY_CONTACT_CLEAR_DISTANCE: float = 2.5

@export var area_id: String = "test_room"

@onready var camera_rig: CameraRig = $CameraRig
@onready var enemies_root: Node3D = $Enemies
@onready var prompt_label: Label = $UI/ExploreUI/PromptLabel
@onready var message_label: Label = $UI/ExploreUI/MessageLabel
@onready var doors_root: Node3D = $Doors

var _area: AreaData
var _player: ExplorePlayer
var _busy: bool = false
var _active_door: Node3D
var _checkpoint: ExploreCheckpointNode


func _ready() -> void:
	_area = DataLoader.load_area(area_id)
	_checkpoint = get_node_or_null("Checkpoint") as ExploreCheckpointNode
	GameState.ensure_party_initialized(str(_area.default_encounter_id))
	_spawn_player()
	_spawn_enemies()
	_connect_doors()
	camera_rig.set_track_target(_player)
	if _checkpoint != null:
		_checkpoint.checkpoint_saved.connect(_on_checkpoint_saved)
	_show_message("%s — touch enemies to fight. Space at doors to travel." % _area.display_name)


func _spawn_player() -> void:
	_player = PROTAGONIST_SCENE.instantiate() as ExplorePlayer
	_player.add_to_group("explore_player")
	_player.camera_rig_path = camera_rig.get_path()
	add_child(_player)
	var spawn: Dictionary = GameState.get_explore_spawn(_area)
	_player.set_spawn(spawn["position"] as Vector3, float(spawn["rotation_y"]))
	_player.movement_enabled = true
	_nudge_player_from_enemies()


func _spawn_enemies() -> void:
	for enemy_entry: Dictionary in _area.enemies:
		var enemy_id := str(enemy_entry.get("id", ""))
		if GameState.is_enemy_defeated(enemy_id):
			continue
		var pos_array: Array = enemy_entry.get("position", [0, 0, 0]) as Array
		var enemy: Node3D = OverworldEnemyScript.new()
		enemy.enemy_id = enemy_id
		enemy.encounter_id = str(enemy_entry.get("encounter_id", ""))
		enemy.global_position = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		enemy.contact_triggered.connect(_on_enemy_contact.bind(enemy))
		enemies_root.add_child(enemy)


func _connect_doors() -> void:
	if doors_root == null:
		return
	for child: Node in doors_root.get_children():
		var door := child as Node3D
		if door == null or not door.has_method("can_use"):
			continue
		door.door_entered.connect(_on_door_entered)
		door.door_exited.connect(_on_door_exited)


func _process(_delta: float) -> void:
	if _active_door != null and _active_door.call("can_use"):
		prompt_label.text = "Press Space to enter %s" % str(_active_door.get("door_label"))
	elif _checkpoint != null and _checkpoint.can_interact():
		prompt_label.text = "Press E to save checkpoint"
	else:
		prompt_label.text = "WASD to move"


func _on_door_entered(door: Node3D) -> void:
	_active_door = door


func _on_door_exited(door: Node3D) -> void:
	if _active_door == door:
		_active_door = null


func _on_enemy_contact(enemy: Node3D) -> void:
	if _busy or GameState.is_post_battle_contact_immune():
		return
	_busy = true
	_player.movement_enabled = false
	_show_message("Engaging %s..." % enemy.enemy_id)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or _player == null:
		return
	enemy.call("begin_battle", _player, area_id)


func _nudge_player_from_enemies() -> void:
	var player_pos := _player.global_position
	var push := Vector3.ZERO
	for enemy_entry: Dictionary in _area.enemies:
		var enemy_id := str(enemy_entry.get("id", ""))
		if GameState.is_enemy_defeated(enemy_id):
			continue
		var pos_array: Array = enemy_entry.get("position", [0, 0, 0]) as Array
		var enemy_pos := Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		var offset := player_pos - enemy_pos
		offset.y = 0.0
		var distance := offset.length()
		if distance >= ENEMY_CONTACT_CLEAR_DISTANCE:
			continue
		var away := Vector3(0.0, 0.0, 1.0)
		if distance >= 0.001:
			away = offset / distance
		var needed := away * (ENEMY_CONTACT_CLEAR_DISTANCE - minf(distance, ENEMY_CONTACT_CLEAR_DISTANCE))
		if needed.length() > push.length():
			push = needed
	if not push.is_zero_approx():
		_player.global_position += push
		_player.velocity = Vector3.ZERO


func _on_checkpoint_saved() -> void:
	_show_message("Checkpoint saved.")


func _show_message(text: String) -> void:
	message_label.text = text
