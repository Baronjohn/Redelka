class_name OverworldEnemy
extends CharacterBody3D

signal contact_triggered

@export var enemy_id: String = ""
@export var encounter_id: String = ""
@export var contact_radius: float = 1.2

var _player: CharacterBody3D
var _area: Area3D
var _mesh: MeshInstance3D
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

	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	_mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.25, 0.25)
	_mesh.material_override = material
	_mesh.position = Vector3(0.0, 0.9, 0.0)
	add_child(_mesh)

	if GameState.is_enemy_defeated(enemy_id):
		queue_free()


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
