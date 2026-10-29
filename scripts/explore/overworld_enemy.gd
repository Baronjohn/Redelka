class_name OverworldEnemy
extends CharacterBody3D

signal contact_triggered

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


## The overworld id is per-area (e.g. "room_wretch"), so the model comes from
## the encounter's first enemy, falling back to enemy_id for direct enemy ids.
func _attach_enemy_model() -> void:
	var model_enemy_id := enemy_id
	if not encounter_id.is_empty():
		var encounter := DataLoader.load_encounter(encounter_id)
		if encounter != null and not encounter.enemies.is_empty():
			model_enemy_id = str(encounter.enemies[0].get("enemy_id", enemy_id))
	var model_path := ""
	var enemies := DataLoader.load_enemies()
	if enemies.has(model_enemy_id):
		model_path = (enemies[model_enemy_id] as EnemyData).model_path

	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		push_warning("Overworld enemy '%s' has no model" % enemy_id)
		return
	var scene := load(model_path) as PackedScene
	if scene != null:
		add_child(scene.instantiate() as Node3D)


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
