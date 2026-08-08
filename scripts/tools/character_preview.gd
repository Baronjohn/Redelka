extends Node3D

## Dev tool: renders all four survivor models to /tmp/redelka_preview.png.
## Run: godot --path . res://scenes/tools/character_preview.tscn

const SurvivorModelScript = preload("res://scripts/assets/characters/survivor_character_model.gd")

const OUTPUT_PATH: String = "/tmp/redelka_preview.png"


func _ready() -> void:
	var ids: Array[String] = ["ally_1", "ally_2", "ally_3", "ally_4"]
	var front_row: Array[Node3D] = []
	var back_row: Array[Node3D] = []
	for index: int in ids.size():
		var front := SurvivorModelScript.create(ids[index]) as Node3D
		add_child(front)
		front.position = Vector3(-2.4 + 1.6 * float(index), 0.0, 0.0)
		front_row.append(front)
		var back := SurvivorModelScript.create(ids[index]) as Node3D
		add_child(back)
		back.position = Vector3(-2.4 + 1.6 * float(index), 0.0, 0.0)
		back.rotation.y = PI
		back.visible = false
		back_row.append(back)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	light.light_energy = 1.15
	add_child(light)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.13, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 1.25, 3.9)
	camera.look_at(Vector3(0.0, 0.85, 0.0))
	camera.current = true

	for _frame: int in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)

	camera.position = Vector3(0.0, 1.45, 2.2)
	camera.look_at(Vector3(0.0, 1.32, 0.0))
	for _frame: int in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/redelka_preview_heads.png")

	for front: Node3D in front_row:
		front.visible = false
	for back: Node3D in back_row:
		back.visible = true
	camera.position = Vector3(0.0, 1.25, 3.9)
	camera.look_at(Vector3(0.0, 0.85, 0.0))
	for _frame: int in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/redelka_preview_backs.png")

	print("Preview saved to %s" % OUTPUT_PATH)
	get_tree().quit()
