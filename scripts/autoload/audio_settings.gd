extends Node

var master_volume_default: float = 1.0
var music_volume_default: float = 1.0
var sfx_volume_default: float = 1.0
var music_fade_duration: float = 1.2
var music_tracks: Dictionary = {}
var sfx_pool_size: int = 10
var sfx_paths: Dictionary = {}
var walk_step_min_speed_ratio: float = 0.12
var walk_step_cooldown_min: float = 0.28
var walk_step_cooldown_max: float = 0.52
var walk_step_volume_min_db: float = -8.0
var walk_step_volume_max_db: float = -2.0
var walk_step_pitch_min: float = 0.9
var walk_step_pitch_max: float = 1.08


func _ready() -> void:
	load_defaults()


func load_defaults() -> void:
	var data := DataLoader.load_audio()
	var volumes := data.get("volumes", {}) as Dictionary
	master_volume_default = float(volumes.get("master", master_volume_default))
	music_volume_default = float(volumes.get("music", music_volume_default))
	sfx_volume_default = float(volumes.get("sfx", sfx_volume_default))

	var music := data.get("music", {}) as Dictionary
	music_fade_duration = float(music.get("fade_duration", music_fade_duration))
	music_tracks = music.get("tracks", {}) as Dictionary

	var sfx := data.get("sfx", {}) as Dictionary
	sfx_pool_size = int(sfx.get("pool_size", sfx_pool_size))
	sfx_paths = sfx.get("paths", {}) as Dictionary

	var walk_step := sfx.get("walk_step", {}) as Dictionary
	walk_step_min_speed_ratio = float(walk_step.get("min_speed_ratio", walk_step_min_speed_ratio))
	walk_step_cooldown_min = float(walk_step.get("cooldown_min", walk_step_cooldown_min))
	walk_step_cooldown_max = float(walk_step.get("cooldown_max", walk_step_cooldown_max))
	walk_step_volume_min_db = float(walk_step.get("volume_min_db", walk_step_volume_min_db))
	walk_step_volume_max_db = float(walk_step.get("volume_max_db", walk_step_volume_max_db))
	walk_step_pitch_min = float(walk_step.get("pitch_min", walk_step_pitch_min))
	walk_step_pitch_max = float(walk_step.get("pitch_max", walk_step_pitch_max))
