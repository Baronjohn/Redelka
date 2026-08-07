extends CanvasLayer

const FADE_DURATION: float = 0.4

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/menu/main_menu.tscn")

var _overlay: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_overlay)


func change_scene(scene: PackedScene) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	await tween.finished
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)
	await tween.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func go_to_battle() -> void:
	await change_scene(BATTLE_SCENE)


func go_to_main_menu() -> void:
	await change_scene(MAIN_MENU_SCENE)


func go_to_explore() -> void:
	var area_id := GameState.return_area_id
	if pending_door_spawn_has_area():
		area_id = str(GameState.pending_door_spawn["area_id"])
	var area := DataLoader.load_area(area_id)
	var scene := load(area.scene_path) as PackedScene
	if scene == null:
		push_error("Explore scene missing for area: %s" % area_id)
		return
	await change_scene(scene)


func pending_door_spawn_has_area() -> bool:
	return GameState.pending_door_spawn.has("area_id") and not str(GameState.pending_door_spawn["area_id"]).is_empty()
