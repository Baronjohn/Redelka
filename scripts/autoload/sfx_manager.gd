extends Node

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0
var _walk_step_cooldown: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in AudioSettings.sfx_pool_size:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


func play(sfx_id: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not AudioSettings.sfx_paths.has(sfx_id):
		push_warning("Unknown sfx: %s" % sfx_id)
		return
	var path: String = str(AudioSettings.sfx_paths[sfx_id])
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func play_walk_step(speed_ratio: float) -> void:
	play(
		"walk_step",
		randf_range(AudioSettings.walk_step_pitch_min, AudioSettings.walk_step_pitch_max),
		lerpf(
			AudioSettings.walk_step_volume_min_db,
			AudioSettings.walk_step_volume_max_db,
			clampf(speed_ratio, 0.0, 1.0),
		),
	)


func update_walk_steps(delta: float, speed_ratio: float) -> void:
	if speed_ratio < AudioSettings.walk_step_min_speed_ratio:
		_walk_step_cooldown = 0.0
		return
	_walk_step_cooldown -= delta
	if _walk_step_cooldown > 0.0:
		return
	_walk_step_cooldown = lerpf(
		AudioSettings.walk_step_cooldown_max,
		AudioSettings.walk_step_cooldown_min,
		clampf(speed_ratio, 0.0, 1.0),
	)
	play_walk_step(speed_ratio)


func wire_menu_button(button: BaseButton, confirm: bool = false) -> void:
	var sfx_id := "menu_confirm" if confirm else "menu_nav"
	button.pressed.connect(func() -> void: play(sfx_id))


func wire_item_list(list: ItemList, confirm: bool = true) -> void:
	var sfx_id := "menu_confirm" if confirm else "menu_nav"
	list.item_selected.connect(func(_index: int) -> void: play(sfx_id))
