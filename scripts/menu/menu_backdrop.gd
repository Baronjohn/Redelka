extends Node3D

## Main-menu backdrop: a slow, uneasy drift of the camera along the pine edge.

const DRIFT_PERIOD: float = 46.0
const SWAY: Vector3 = Vector3(0.7, 0.12, 0.35)
const LOOK_TARGET: Vector3 = Vector3(0.6, 1.6, -7.0)

@onready var _camera: Camera3D = $Camera
var _origin: Vector3
var _time: float = 0.0


func _ready() -> void:
	_origin = _camera.position
	_camera.current = true
	_camera.look_at(LOOK_TARGET, Vector3.UP)


func _process(delta: float) -> void:
	_time += delta
	var phase := TAU * _time / DRIFT_PERIOD
	_camera.position = _origin + Vector3(
		sin(phase) * SWAY.x,
		sin(phase * 2.0 + 0.6) * SWAY.y,
		cos(phase * 0.5) * SWAY.z,
	)
	_camera.look_at(LOOK_TARGET + Vector3(sin(phase * 0.7) * 0.4, 0.0, 0.0), Vector3.UP)
