extends Node

var _player: AudioStreamPlayer
var _fade_tween: Tween
var _current_track: String = ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	get_tree().root.ready.connect(_on_root_ready, CONNECT_ONE_SHOT)


func _on_root_ready() -> void:
	_sync_current_scene_music()


func play_track(track_id: String, force: bool = false) -> void:
	if not AudioSettings.music_tracks.has(track_id):
		push_warning("Unknown music track: %s" % track_id)
		return
	if track_id == _current_track and _player.playing and not force:
		return
	var path: String = str(AudioSettings.music_tracks[track_id])
	if not ResourceLoader.exists(path):
		push_warning("Music file missing: %s" % path)
		return
	_current_track = track_id
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_player.stream = stream
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_player.volume_db = linear_to_db(0.0001)
	_player.play()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", 0.0, AudioSettings.music_fade_duration)


func play_for_scene_path(scene_path: String) -> void:
	if scene_path.contains("main_menu"):
		play_track("main_menu")
	elif scene_path.contains("battle"):
		play_track("battle")
	else:
		play_track("overworld")


func stop_music(fade_duration: float = -1.0) -> void:
	if not _player.playing:
		return
	var duration := fade_duration if fade_duration >= 0.0 else AudioSettings.music_fade_duration
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", linear_to_db(0.0001), duration)
	_fade_tween.tween_callback(_player.stop)
	_current_track = ""


func _sync_current_scene_music() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	play_for_scene_path(scene.scene_file_path)
