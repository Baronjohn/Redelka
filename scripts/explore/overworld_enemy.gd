class_name OverworldEnemy
extends CharacterBody3D

signal contact_triggered

const Ps1EnemyModelScript = preload("res://scripts/assets/ps1_enemy_model.gd")

@export var enemy_id: String = ""
@export var encounter_id: String = ""
@export var contact_radius: float = 1.2

var _player: CharacterBody3D
var _area: Area3D
var _triggered: bool = false


func _ready() -> void:
	_area = Area3D.new()
	_area.name = "ContactArea"
	var shape := SphereShape3D.new()
	shape.radius = contact_radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_area.add_child(collision)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_attach_enemy_model()

	if GameState.is_enemy_defeated(enemy_id):
		queue_free()


func _attach_enemy_model() -> void:
	var model_path := ""
	var enemies := DataLoader.load_enemies()
	if enemies.has(enemy_id):
		model_path = (enemies[enemy_id] as EnemyData).model_path

	var model: Node3D = null
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var scene := load(model_path) as PackedScene
		if scene != null:
			model = scene.instantiate() as Node3D
	if model == null:
		model = Ps1EnemyModelScript.create(enemy_id)
	model.position = Vector3(0.0, 0.9, 0.0)
	add_child(model)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or GameState.is_post_battle_contact_immune():
		return
	if not body.is_in_group("explore_player"):
		return
	_player = body as CharacterBody3D
	_triggered = true
	contact_triggered.emit()


func begin_battle(player: CharacterBody3D, area_id: String) -> void:
	GameState.enter_battle(
		area_id,
		player.global_position,
		player.rotation.y,
		encounter_id,
		enemy_id
	)
	SceneTransition.go_to_battle()
