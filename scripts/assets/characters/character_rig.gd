class_name CharacterRig
extends Node3D

## Procedural PS1-style humanoid: lathe-based body, sphere head,
## per-character wardrobe and a keyframed animation set.

const MeshUtils = preload("res://scripts/assets/characters/character_mesh_utils.gd")
const ConfigsScript = preload("res://scripts/assets/characters/survivor_character_configs.gd")

const HIP_Y: float = 0.88
const LEG_SPLAY_X: float = 0.09
const UPPER_LEG_LEN: float = 0.40
const LOWER_LEG_LEN: float = 0.34
const FOOT_HEIGHT: float = 0.08
const TORSO_HEIGHT: float = 0.46
const SHOULDER_Y: float = 0.40
const UPPER_ARM_LEN: float = 0.27
const FORE_ARM_LEN: float = 0.24
const HAND_LEN: float = 0.09

var attack_style: String = "melee"

var _rig_root: Node3D
var _animation_player: AnimationPlayer
var _mesh_instances: Array[MeshInstance3D] = []
var _bones: Dictionary = {}
var _colors: Dictionary = {}
var _features: Array = []
var _shoulder_x: float = 0.19
var _width: float = 1.0
var _depth: float = 1.0
var _girth: float = 1.0
var _hip_width: float = 1.0
var _walk_swing: float = 1.0
var _is_chanting: bool = false
var _action_playing: bool = false


func build(character_id: String) -> void:
	var config: Dictionary = ConfigsScript.get_config(character_id)
	attack_style = str(config.get("attack_style", "melee"))
	scale = config.get("scale", Vector3.ONE) as Vector3
	_colors = config.get("colors", {}) as Dictionary
	_features = config.get("features", []) as Array
	var body: Dictionary = config.get("body", {}) as Dictionary
	_shoulder_x = float(body.get("shoulder_x", 0.19))
	_width = float(body.get("width", 1.0))
	_depth = float(body.get("depth", 1.0))
	_girth = float(body.get("girth", 1.0))
	_hip_width = float(body.get("hip_width", 1.0))
	_walk_swing = float(config.get("walk_swing", 1.0))
	_build_skeleton()
	_build_head()
	_build_wardrobe()
	_build_weapons()
	_build_animations()
	_animation_player.play("idle")


func update_animation(_delta: float, speed_ratio: float) -> void:
	if _action_playing or _is_chanting:
		return
	if speed_ratio >= 0.05:
		if _animation_player.current_animation != "walk":
			_animation_player.play("walk", 0.15)
		_animation_player.speed_scale = clampf(speed_ratio, 0.4, 1.4)
	elif _animation_player.current_animation != "idle":
		_animation_player.play("idle", 0.2)
		_animation_player.speed_scale = 1.0


func update_walk_animation(delta: float, speed_ratio: float) -> void:
	update_animation(delta, speed_ratio)


func is_action_playing() -> bool:
	return _action_playing


func is_chanting() -> bool:
	return _is_chanting


func set_chanting(enabled: bool) -> void:
	_is_chanting = enabled
	if enabled:
		_action_playing = false
		_animation_player.play("chant", 0.2)
	elif _animation_player.current_animation == "chant":
		_animation_player.play("idle", 0.2)


func play_attack() -> void:
	_action_playing = true
	_animation_player.speed_scale = 1.0
	_animation_player.play("attack")
	var attack_anim: Animation = _animation_player.get_animation("attack")
	var duration := attack_anim.length if attack_anim != null else 0.5
	duration = DebugSettings.scale_battle_duration(duration)
	await get_tree().create_timer(duration).timeout
	_action_playing = false
	if _is_chanting:
		_animation_player.play("chant", 0.15)
	else:
		_animation_player.play("idle", 0.15)


func play_chant_release() -> void:
	_action_playing = true
	_is_chanting = false
	_animation_player.speed_scale = 1.0
	_animation_player.play("chant_release")
	var release_anim: Animation = _animation_player.get_animation("chant_release")
	var duration := release_anim.length if release_anim != null else 0.4
	duration = DebugSettings.scale_battle_duration(duration)
	await get_tree().create_timer(duration).timeout
	_action_playing = false
	_animation_player.play("idle", 0.15)


func get_mesh_instances() -> Array[MeshInstance3D]:
	return _mesh_instances


func get_ground_y_offset() -> float:
	return CombatConstants.TILE_FLOOR_Y


func get_model_top_y() -> float:
	var top := 0.0
	for mesh_instance: MeshInstance3D in _mesh_instances:
		if mesh_instance.mesh == null:
			continue
		var local_top := mesh_instance.mesh.get_aabb().end.y
		var node := mesh_instance as Node3D
		while node != null and node != self:
			local_top += node.position.y
			node = node.get_parent() as Node3D
		top = maxf(top, local_top)
	return top * scale.y


func apply_tint(base_tint: Color, emission: Color = Color.BLACK) -> void:
	var material := MeshUtils.create_state_material(base_tint, emission)
	for mesh_instance: MeshInstance3D in _mesh_instances:
		mesh_instance.material_override = material


func reset_materials() -> void:
	var material := MeshUtils.create_base_material()
	for mesh_instance: MeshInstance3D in _mesh_instances:
		mesh_instance.material_override = material


func apply_ko_darken() -> void:
	var material := MeshUtils.create_state_material(Color(0.35, 0.35, 0.38))
	for mesh_instance: MeshInstance3D in _mesh_instances:
		mesh_instance.material_override = material


func _c(key: String) -> Color:
	return _colors.get(key, Color.MAGENTA) as Color


func _has(feature: String) -> bool:
	return _features.has(feature)


func _build_skeleton() -> void:
	_rig_root = Node3D.new()
	_rig_root.name = "RigRoot"
	add_child(_rig_root)
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)

	var pants := _c("pants")
	var sleeves := _c("sleeves")
	var skin := _c("skin")
	var boots := _c("boots")

	var hips := _bone("Hips", _rig_root, Vector3(0.0, HIP_Y, 0.0))
	_mesh(hips, MeshUtils.make_lathe([
		MeshUtils.ring(-0.14, 0.126 * _hip_width * _width, 0.096 * _depth, MeshUtils.shade(pants, 0.82)),
		MeshUtils.ring(-0.04, 0.148 * _hip_width * _width, 0.108 * _depth, pants),
		MeshUtils.ring(0.05, 0.132 * _width, 0.098 * _depth, pants),
	], 10), "PelvisMesh")

	for side_data: Array in [["L", -1.0], ["R", 1.0]]:
		var suffix: String = side_data[0]
		var side: float = side_data[1]
		var upper_leg := _bone("UpperLeg%s" % suffix, hips, Vector3(side * LEG_SPLAY_X * _hip_width, -0.06, 0.0))
		_mesh(upper_leg, MeshUtils.make_lathe([
			MeshUtils.ring(-UPPER_LEG_LEN, 0.056 * _girth, 0.056 * _girth, MeshUtils.shade(pants, 0.88)),
			MeshUtils.ring(0.0, 0.074 * _girth, 0.074 * _girth, pants),
		], 7), "UpperLeg%sMesh" % suffix)
		var lower_leg := _bone("LowerLeg%s" % suffix, upper_leg, Vector3(0.0, -UPPER_LEG_LEN, 0.0))
		_mesh(lower_leg, MeshUtils.make_sphere(0.056 * _girth, pants, Vector3.ONE, Vector3.ZERO, 3, 7), "Knee%sMesh" % suffix)
		_mesh(lower_leg, MeshUtils.make_lathe([
			MeshUtils.ring(-LOWER_LEG_LEN, 0.042 * _girth, 0.042 * _girth, MeshUtils.shade(pants, 0.8)),
			MeshUtils.ring(0.0, 0.054 * _girth, 0.054 * _girth, MeshUtils.shade(pants, 0.94)),
		], 7), "LowerLeg%sMesh" % suffix)
		var foot := _bone("Foot%s" % suffix, lower_leg, Vector3(0.0, -LOWER_LEG_LEN, 0.0))
		_mesh(foot, MeshUtils.make_lathe([
			MeshUtils.ring(-FOOT_HEIGHT, 0.052, 0.072, MeshUtils.shade(boots, 0.85), 0.03),
			MeshUtils.ring(-0.035, 0.05, 0.062, boots, 0.02),
			MeshUtils.ring(0.0, 0.046, 0.048, boots),
		], 7), "Foot%sMesh" % suffix)

	var spine := _bone("Spine", hips, Vector3(0.0, 0.04, 0.0))
	var torso := _c("torso")
	_mesh(spine, MeshUtils.make_lathe([
		MeshUtils.ring(0.0, 0.128 * _width, 0.094 * _depth, MeshUtils.shade(torso, 0.88)),
		MeshUtils.ring(0.16, 0.136 * _width, 0.098 * _depth, MeshUtils.shade(torso, 0.95)),
		MeshUtils.ring(0.30, 0.150 * _width, 0.106 * _depth, torso),
		MeshUtils.ring(0.40, 0.148 * _width, 0.104 * _depth, torso),
		MeshUtils.ring(TORSO_HEIGHT, 0.116 * _width, 0.09 * _depth, MeshUtils.shade(torso, 0.96)),
	], 10), "TorsoMesh")

	var neck := _bone("Neck", spine, Vector3(0.0, TORSO_HEIGHT, 0.0))
	_mesh(neck, MeshUtils.make_lathe([
		MeshUtils.ring(0.0, 0.05, 0.05, MeshUtils.shade(skin, 0.85)),
		MeshUtils.ring(0.075, 0.054, 0.054, skin),
	], 7), "NeckMesh")
	_bone("Head", neck, Vector3(0.0, 0.07, 0.0))

	for side_data: Array in [["L", -1.0], ["R", 1.0]]:
		var suffix: String = side_data[0]
		var side: float = side_data[1]
		var shoulder := _bone("Shoulder%s" % suffix, spine, Vector3(side * _shoulder_x, SHOULDER_Y, 0.0))
		var upper_arm := _bone("UpperArm%s" % suffix, shoulder, Vector3.ZERO)
		_mesh(upper_arm, MeshUtils.make_sphere(0.052 * _girth, sleeves, Vector3.ONE, Vector3(0.0, 0.015, 0.0), 3, 7), "Shoulder%sMesh" % suffix)
		_mesh(upper_arm, MeshUtils.make_lathe([
			MeshUtils.ring(-UPPER_ARM_LEN, 0.042 * _girth, 0.042 * _girth, MeshUtils.shade(sleeves, 0.88)),
			MeshUtils.ring(-0.02, 0.05 * _girth, 0.05 * _girth, sleeves),
		], 7), "UpperArm%sMesh" % suffix)
		var fore_arm := _bone("ForeArm%s" % suffix, upper_arm, Vector3(0.0, -UPPER_ARM_LEN, 0.0))
		_mesh(fore_arm, MeshUtils.make_sphere(0.042 * _girth, sleeves, Vector3.ONE, Vector3.ZERO, 3, 7), "Elbow%sMesh" % suffix)
		_mesh(fore_arm, MeshUtils.make_lathe([
			MeshUtils.ring(-FORE_ARM_LEN, 0.032 * _girth, 0.032 * _girth, MeshUtils.shade(sleeves, 0.82)),
			MeshUtils.ring(0.0, 0.04 * _girth, 0.04 * _girth, MeshUtils.shade(sleeves, 0.94)),
		], 7), "ForeArm%sMesh" % suffix)
		var hand := _bone("Hand%s" % suffix, fore_arm, Vector3(0.0, -FORE_ARM_LEN, 0.0))
		_mesh(hand, MeshUtils.make_lathe([
			MeshUtils.ring(-HAND_LEN, 0.026, 0.03, MeshUtils.shade(skin, 0.9)),
			MeshUtils.ring(0.0, 0.032, 0.034, skin),
		], 6), "Hand%sMesh" % suffix)


func _build_head() -> void:
	var head: Node3D = _bones["Head"]
	var skin := _c("skin")
	var hair := _c("hair")
	_mesh(head, MeshUtils.make_sphere(0.105, skin, Vector3(0.85, 1.05, 0.92), Vector3(0.0, 0.09, 0.0), 5, 10), "SkullMesh")
	var eye_color := Color(0.11, 0.09, 0.08)
	_mesh(head, MeshUtils.make_box(Vector3(0.021, 0.011, 0.012), eye_color, Vector3(-0.033, 0.085, 0.09)), "EyeLMesh")
	_mesh(head, MeshUtils.make_box(Vector3(0.021, 0.011, 0.012), eye_color, Vector3(0.033, 0.085, 0.09)), "EyeRMesh")

	if _has("hood"):
		var hood := _c("hood")
		# Open lathe built along local Y, rotated so the uncapped end
		# becomes a forward-facing opening around the face.
		var hood_mesh := MeshUtils.make_lathe([
			MeshUtils.ring(-0.118, 0.112, 0.112, MeshUtils.shade(hood, 0.72)),
			MeshUtils.ring(-0.06, 0.124, 0.124, hood),
			MeshUtils.ring(0.045, 0.122, 0.122, hood, 0.008),
			MeshUtils.ring(0.118, 0.062, 0.062, MeshUtils.shade(hood, 0.88), 0.014),
		], 10, false, true)
		_mesh_at(head, hood_mesh, Vector3(0.0, 0.095, -0.005), Vector3(deg_to_rad(-90.0), 0.0, 0.0), "HoodMesh")
		_mesh(head, MeshUtils.make_box(Vector3(0.09, 0.028, 0.02), hair, Vector3(0.0, 0.128, 0.078)), "FringeMesh")
	elif _has("cap"):
		_mesh(head, MeshUtils.make_sphere(0.108, hair, Vector3(0.92, 1.0, 0.9), Vector3(0.0, 0.1, -0.025), 4, 10), "HairMesh")
		var cap := _c("cap")
		_mesh(head, MeshUtils.make_sphere(0.115, cap, Vector3(1.0, 0.55, 1.0), Vector3(0.0, 0.165, 0.0), 4, 10), "CapMesh")
		_mesh(head, MeshUtils.make_box(Vector3(0.17, 0.016, 0.09), MeshUtils.shade(cap, 0.85), Vector3(0.0, 0.14, 0.105)), "BrimMesh")
	else:
		_mesh(head, MeshUtils.make_sphere(0.112, hair, Vector3(0.9, 1.0, 0.95), Vector3(0.0, 0.115, -0.012), 4, 10), "HairMesh")

	if _has("peak"):
		var hood := _c("hood")
		_mesh(head, MeshUtils.make_lathe([
			MeshUtils.ring(0.16, 0.078, 0.078, hood),
			MeshUtils.ring(0.24, 0.045, 0.045, MeshUtils.shade(hood, 0.9), -0.025),
			MeshUtils.ring(0.3, 0.012, 0.012, MeshUtils.shade(hood, 0.8), -0.06),
		], 8), "PeakMesh")


func _build_wardrobe() -> void:
	var hips: Node3D = _bones["Hips"]
	var spine: Node3D = _bones["Spine"]

	if _has("belt"):
		var belt := _c("belt")
		_mesh(hips, MeshUtils.make_lathe([
			MeshUtils.ring(0.02, 0.138 * _width, 0.102 * _depth, belt),
			MeshUtils.ring(0.075, 0.136 * _width, 0.1 * _depth, belt),
		], 10), "BeltMesh")
		_mesh(hips, MeshUtils.make_box(Vector3(0.045, 0.032, 0.014), _c("buckle"), Vector3(0.0, 0.048, 0.102 * _depth)), "BuckleMesh")

	if _has("coat_skirt"):
		var coat := _c("coat")
		_mesh(hips, MeshUtils.make_lathe([
			MeshUtils.ring(-0.34, 0.176 * _width, 0.13 * _depth, MeshUtils.shade(coat, 0.72)),
			MeshUtils.ring(-0.12, 0.16 * _width, 0.118 * _depth, MeshUtils.shade(coat, 0.88)),
			MeshUtils.ring(0.03, 0.15 * _width, 0.11 * _depth, coat),
		], 10), "CoatSkirtMesh")

	if _has("fur_collar"):
		var fur := _c("fur")
		_mesh(spine, MeshUtils.make_lathe([
			MeshUtils.ring(0.37, 0.15 * _width, 0.108 * _depth, MeshUtils.shade(fur, 0.85)),
			MeshUtils.ring(0.47, 0.17 * _width, 0.125 * _depth, fur),
		], 10), "FurCollarMesh")

	if _has("cape"):
		var cape := _c("cape")
		_mesh(spine, MeshUtils.make_lathe([
			MeshUtils.ring(0.16, 0.185 * _width, 0.135 * _depth, MeshUtils.shade(cape, 0.78)),
			MeshUtils.ring(0.34, 0.16 * _width, 0.116 * _depth, MeshUtils.shade(cape, 0.92)),
			MeshUtils.ring(0.46, 0.125 * _width, 0.095 * _depth, cape),
		], 10), "CapeMesh")

	if _has("scarf"):
		var scarf := _c("scarf")
		_mesh(spine, MeshUtils.make_lathe([
			MeshUtils.ring(0.40, 0.085, 0.075, MeshUtils.shade(scarf, 0.9)),
			MeshUtils.ring(0.47, 0.072, 0.066, scarf),
		], 8), "ScarfMesh")
		_mesh(spine, MeshUtils.make_box(Vector3(0.05, 0.11, 0.016), MeshUtils.shade(scarf, 0.85), Vector3(0.025, 0.34, 0.118)), "ScarfTailMesh")

	if _has("vest"):
		var vest := _c("vest")
		_mesh(spine, MeshUtils.make_lathe([
			MeshUtils.ring(0.03, 0.136 * _width, 0.1 * _depth, MeshUtils.shade(vest, 0.88)),
			MeshUtils.ring(0.2, 0.144 * _width, 0.104 * _depth, vest),
			MeshUtils.ring(0.36, 0.154 * _width, 0.11 * _depth, vest),
		], 10), "VestMesh")

	if _has("satchel"):
		var satchel := _c("satchel")
		_mesh(hips, MeshUtils.make_box(Vector3(0.13, 0.11, 0.05), satchel, Vector3(0.16 * _width + 0.04, -0.02, 0.01)), "SatchelMesh")

	if _has("robe"):
		var robe := _c("robe")
		var trim := _c("trim")
		_mesh(hips, MeshUtils.make_lathe([
			MeshUtils.ring(-0.82, 0.21 * _width, 0.17 * _depth, MeshUtils.shade(robe, 0.6)),
			MeshUtils.ring(-0.5, 0.19 * _width, 0.15 * _depth, MeshUtils.shade(robe, 0.78)),
			MeshUtils.ring(-0.15, 0.165 * _width, 0.125 * _depth, MeshUtils.shade(robe, 0.9)),
			MeshUtils.ring(0.05, 0.15 * _width, 0.11 * _depth, robe),
		], 10), "RobeMesh")
		_mesh(hips, MeshUtils.make_lathe([
			MeshUtils.ring(-0.82, 0.213 * _width, 0.173 * _depth, trim),
			MeshUtils.ring(-0.76, 0.208 * _width, 0.168 * _depth, trim),
		], 10), "RobeTrimMesh")

	if _has("sash"):
		var trim := _c("trim")
		_mesh(hips, MeshUtils.make_lathe([
			MeshUtils.ring(0.0, 0.14 * _width, 0.104 * _depth, MeshUtils.shade(trim, 0.9)),
			MeshUtils.ring(0.055, 0.137 * _width, 0.1 * _depth, trim),
		], 10), "SashMesh")


func _build_weapons() -> void:
	var hand_r: Node3D = _bones["HandR"]
	var hand_l: Node3D = _bones["HandL"]

	if _has("sword"):
		_mesh_at(hand_r, MeshUtils.make_sword(0.46, 0.026, _c("metal"), MeshUtils.shade(_c("metal"), 0.7), _c("grip")),
			Vector3(0.0, -0.055, 0.018), Vector3(deg_to_rad(-14.0), 0.0, 0.0), "SwordMesh")

	if _has("dagger"):
		_mesh_at(hand_r, MeshUtils.make_sword(0.2, 0.018, _c("metal"), MeshUtils.shade(_c("metal"), 0.65), _c("grip")),
			Vector3(0.0, -0.05, 0.016), Vector3(deg_to_rad(-10.0), 0.0, 0.0), "DaggerMesh")

	if _has("staff"):
		_mesh_at(hand_r, MeshUtils.make_staff(_c("wood"), _c("orb")),
			Vector3(0.0, -0.05, 0.024), Vector3.ZERO, "StaffMesh")

	if _has("bow"):
		_mesh_at(hand_l, MeshUtils.make_bow(0.34, 55.0, _c("wood"), _c("string")),
			Vector3(0.0, -0.05, 0.02), Vector3.ZERO, "BowMesh")

	if _has("book"):
		_mesh_at(hand_l, MeshUtils.make_book(Vector3(0.085, 0.115, 0.03), _c("book"), Color(0.78, 0.73, 0.62)),
			Vector3(0.0, -0.06, 0.025), Vector3(deg_to_rad(24.0), 0.0, 0.0), "BookMesh")


func _bone(bone_name: String, parent: Node3D, offset: Vector3) -> Node3D:
	var bone := Node3D.new()
	bone.name = bone_name
	bone.position = offset
	parent.add_child(bone)
	_bones[bone_name] = bone
	return bone


func _mesh(parent: Node3D, mesh: ArrayMesh, mesh_name: String) -> void:
	_mesh_at(parent, mesh, Vector3.ZERO, Vector3.ZERO, mesh_name)


func _mesh_at(parent: Node3D, mesh: ArrayMesh, offset: Vector3, rotation_euler: Vector3, mesh_name: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.position = offset
	mesh_instance.rotation = rotation_euler
	mesh_instance.material_override = MeshUtils.create_base_material()
	parent.add_child(mesh_instance)
	_mesh_instances.append(mesh_instance)


# --- Animations -----------------------------------------------------------


func _build_animations() -> void:
	var library := AnimationLibrary.new()
	library.add_animation("idle", _make_idle())
	library.add_animation("walk", _make_walk())
	library.add_animation("attack", _make_attack())
	library.add_animation("chant", _make_chant())
	library.add_animation("chant_release", _make_chant_release())
	_animation_player.add_animation_library("", library)


func _rot(x: float, y: float, z: float) -> Vector3:
	return Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))


func _path(bone_name: String) -> String:
	return String(get_path_to(_bones[bone_name] as Node3D))


func _track(anim: Animation, bone_name: String, times: Array, eulers: Array) -> void:
	var track_index := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track_index, NodePath(_path(bone_name)))
	for key_index: int in times.size():
		var euler: Vector3 = eulers[key_index]
		anim.rotation_track_insert_key(track_index, float(times[key_index]), Quaternion.from_euler(euler))


func _pos_track(anim: Animation, bone_name: String, times: Array, positions: Array) -> void:
	var track_index := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_index, NodePath(_path(bone_name)))
	for key_index: int in times.size():
		anim.position_track_insert_key(track_index, float(times[key_index]), positions[key_index] as Vector3)


func _hips_rest() -> Vector3:
	return Vector3(0.0, HIP_Y, 0.0)


## Idle keys every animated bone so poses from other clips never linger.
func _make_idle() -> Animation:
	var anim := Animation.new()
	anim.length = 3.2
	anim.loop_mode = Animation.LOOP_LINEAR
	var times: Array = [0.0, 1.6, 3.2]
	_pos_track(anim, "Hips", times, [_hips_rest(), _hips_rest() + Vector3(0.0, -0.006, 0.0), _hips_rest()])
	_track(anim, "Hips", times, [_rot(0, 0, 0), _rot(0, 0, 0), _rot(0, 0, 0)])
	_track(anim, "Spine", times, [_rot(0, 0, 0), _rot(1.4, 0, 0), _rot(0, 0, 0)])
	_track(anim, "Neck", times, [_rot(0, 0, 0), _rot(-1.2, 0, 0), _rot(0, 0, 0)])
	_track(anim, "Head", times, [_rot(0, 0, 0), _rot(-0.8, 1.0, 0), _rot(0, 0, 0)])
	_track(anim, "UpperArmL", times, [_rot(0, 0, -5), _rot(0, 0, -6.5), _rot(0, 0, -5)])
	_track(anim, "UpperArmR", times, [_rot(0, 0, 5), _rot(0, 0, 6.5), _rot(0, 0, 5)])
	_track(anim, "ForeArmL", times, [_rot(-8, 0, 0), _rot(-9, 0, 0), _rot(-8, 0, 0)])
	_track(anim, "ForeArmR", times, [_rot(-8, 0, 0), _rot(-9, 0, 0), _rot(-8, 0, 0)])
	for bone_name: String in ["UpperLegL", "UpperLegR", "LowerLegL", "LowerLegR", "FootL", "FootR"]:
		_track(anim, bone_name, [0.0], [_rot(0, 0, 0)])
	return anim


func _make_walk() -> Animation:
	var anim := Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_LINEAR
	var times: Array = [0.0, 0.2, 0.4, 0.6, 0.8]
	var sw := _walk_swing
	_track(anim, "UpperLegL", times, [
		_rot(-26 * sw, 0, 0), _rot(-6 * sw, 0, 0), _rot(20 * sw, 0, 0), _rot(4 * sw, 0, 0), _rot(-26 * sw, 0, 0),
	])
	_track(anim, "LowerLegL", times, [
		_rot(12 * sw, 0, 0), _rot(6 * sw, 0, 0), _rot(10 * sw, 0, 0), _rot(42 * sw, 0, 0), _rot(12 * sw, 0, 0),
	])
	_track(anim, "FootL", times, [
		_rot(-6 * sw, 0, 0), _rot(2 * sw, 0, 0), _rot(4 * sw, 0, 0), _rot(-10 * sw, 0, 0), _rot(-6 * sw, 0, 0),
	])
	_track(anim, "UpperLegR", times, [
		_rot(20 * sw, 0, 0), _rot(4 * sw, 0, 0), _rot(-26 * sw, 0, 0), _rot(-6 * sw, 0, 0), _rot(20 * sw, 0, 0),
	])
	_track(anim, "LowerLegR", times, [
		_rot(10 * sw, 0, 0), _rot(42 * sw, 0, 0), _rot(12 * sw, 0, 0), _rot(6 * sw, 0, 0), _rot(10 * sw, 0, 0),
	])
	_track(anim, "FootR", times, [
		_rot(4 * sw, 0, 0), _rot(-10 * sw, 0, 0), _rot(-6 * sw, 0, 0), _rot(2 * sw, 0, 0), _rot(4 * sw, 0, 0),
	])
	var arm := 0.85 * sw
	_track(anim, "UpperArmL", times, [
		_rot(14 * arm, 0, -5), _rot(2 * arm, 0, -5), _rot(-16 * arm, 0, -5), _rot(-2 * arm, 0, -5), _rot(14 * arm, 0, -5),
	])
	_track(anim, "UpperArmR", times, [
		_rot(-16 * arm, 0, 5), _rot(-2 * arm, 0, 5), _rot(14 * arm, 0, 5), _rot(2 * arm, 0, 5), _rot(-16 * arm, 0, 5),
	])
	_track(anim, "ForeArmL", times, [
		_rot(-8, 0, 0), _rot(-5, 0, 0), _rot(-18, 0, 0), _rot(-9, 0, 0), _rot(-8, 0, 0),
	])
	_track(anim, "ForeArmR", times, [
		_rot(-18, 0, 0), _rot(-9, 0, 0), _rot(-8, 0, 0), _rot(-5, 0, 0), _rot(-18, 0, 0),
	])
	_track(anim, "Spine", times, [
		_rot(2, 5 * sw, 0), _rot(3, 0, 0), _rot(2, -5 * sw, 0), _rot(3, 0, 0), _rot(2, 5 * sw, 0),
	])
	_track(anim, "Hips", times, [
		_rot(0, -4 * sw, 0), _rot(0, 0, 0), _rot(0, 4 * sw, 0), _rot(0, 0, 0), _rot(0, -4 * sw, 0),
	])
	_pos_track(anim, "Hips", times, [
		_hips_rest() + Vector3(0.0, -0.012, 0.0),
		_hips_rest() + Vector3(0.0, 0.012, 0.0),
		_hips_rest() + Vector3(0.0, -0.012, 0.0),
		_hips_rest() + Vector3(0.0, 0.012, 0.0),
		_hips_rest() + Vector3(0.0, -0.012, 0.0),
	])
	_track(anim, "Neck", [0.0], [_rot(0, 0, 0)])
	_track(anim, "Head", [0.0], [_rot(2, 0, 0)])
	return anim


func _make_attack() -> Animation:
	match attack_style:
		"dagger":
			return _make_attack_dagger()
		"bow":
			return _make_attack_bow()
		"staff":
			return _make_attack_staff()
		_:
			return _make_attack_melee()


func _make_attack_melee() -> Animation:
	var anim := Animation.new()
	anim.length = 0.55
	var times: Array = [0.0, 0.16, 0.28, 0.55]
	_track(anim, "UpperArmR", times, [
		_rot(0, 0, 5), _rot(-155, -12, 12), _rot(-50, 0, 5), _rot(0, 0, 5),
	])
	_track(anim, "ForeArmR", times, [
		_rot(-10, 0, 0), _rot(-45, 0, 0), _rot(-6, 0, 0), _rot(-10, 0, 0),
	])
	_track(anim, "Spine", times, [
		_rot(0, 0, 0), _rot(-6, 16, 0), _rot(8, -12, 0), _rot(0, 0, 0),
	])
	_track(anim, "Head", times, [
		_rot(0, 0, 0), _rot(-6, 0, 0), _rot(4, 0, 0), _rot(0, 0, 0),
	])
	return anim


func _make_attack_dagger() -> Animation:
	var anim := Animation.new()
	anim.length = 0.42
	var times: Array = [0.0, 0.14, 0.26, 0.42]
	_track(anim, "UpperArmR", times, [
		_rot(0, 0, 5), _rot(-92, -16, 8), _rot(-70, -4, 5), _rot(0, 0, 5),
	])
	_track(anim, "ForeArmR", times, [
		_rot(-12, 0, 0), _rot(-30, 0, 0), _rot(-6, 0, 0), _rot(-12, 0, 0),
	])
	_track(anim, "Spine", times, [
		_rot(0, 0, 0), _rot(4, 18, 0), _rot(8, -14, 0), _rot(0, 0, 0),
	])
	_pos_track(anim, "Hips", times, [
		_hips_rest(),
		_hips_rest() + Vector3(0.0, -0.02, 0.06),
		_hips_rest() + Vector3(0.0, -0.012, 0.04),
		_hips_rest(),
	])
	return anim


func _make_attack_bow() -> Animation:
	var anim := Animation.new()
	anim.length = 0.6
	var times: Array = [0.0, 0.2, 0.44, 0.6]
	_track(anim, "UpperArmL", times, [
		_rot(0, 0, -5), _rot(-84, 6, -4), _rot(-84, 6, -4), _rot(0, 0, -5),
	])
	_track(anim, "UpperArmR", times, [
		_rot(0, 0, 5), _rot(-70, -14, 6), _rot(-62, -6, 5), _rot(0, 0, 5),
	])
	_track(anim, "ForeArmL", times, [
		_rot(-8, 0, 0), _rot(-4, 0, 0), _rot(-4, 0, 0), _rot(-8, 0, 0),
	])
	_track(anim, "ForeArmR", times, [
		_rot(-10, 0, 0), _rot(-55, 0, 0), _rot(-12, 0, 0), _rot(-10, 0, 0),
	])
	_track(anim, "Spine", times, [
		_rot(0, 0, 0), _rot(0, -10, 0), _rot(0, -6, 0), _rot(0, 0, 0),
	])
	return anim


func _make_attack_staff() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	var times: Array = [0.0, 0.16, 0.3, 0.5]
	_track(anim, "UpperArmR", times, [
		_rot(0, 0, 5), _rot(-135, 0, 10), _rot(-55, 0, 6), _rot(0, 0, 5),
	])
	_track(anim, "ForeArmR", times, [
		_rot(-10, 0, 0), _rot(-20, 0, 0), _rot(-4, 0, 0), _rot(-10, 0, 0),
	])
	_track(anim, "Spine", times, [
		_rot(0, 0, 0), _rot(-8, 6, 0), _rot(10, -6, 0), _rot(0, 0, 0),
	])
	return anim


func _make_chant() -> Animation:
	var anim := Animation.new()
	anim.length = 1.8
	anim.loop_mode = Animation.LOOP_LINEAR
	var times: Array = [0.0, 0.9, 1.8]
	_track(anim, "UpperArmL", times, [
		_rot(-62, 0, 8), _rot(-70, 0, 10), _rot(-62, 0, 8),
	])
	_track(anim, "UpperArmR", times, [
		_rot(-62, 0, -8), _rot(-70, 0, -10), _rot(-62, 0, -8),
	])
	_track(anim, "ForeArmL", times, [
		_rot(-28, 0, 0), _rot(-34, 0, 0), _rot(-28, 0, 0),
	])
	_track(anim, "ForeArmR", times, [
		_rot(-28, 0, 0), _rot(-34, 0, 0), _rot(-28, 0, 0),
	])
	_track(anim, "Head", times, [
		_rot(-6, 0, 0), _rot(-9, 0, 0), _rot(-6, 0, 0),
	])
	_track(anim, "Spine", times, [
		_rot(3, 0, 0), _rot(5, 0, 0), _rot(3, 0, 0),
	])
	return anim


func _make_chant_release() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	var times: Array = [0.0, 0.14, 0.4]
	_track(anim, "UpperArmL", times, [
		_rot(-70, 0, 10), _rot(-115, 0, 4), _rot(0, 0, -5),
	])
	_track(anim, "UpperArmR", times, [
		_rot(-70, 0, -10), _rot(-115, 0, -4), _rot(0, 0, 5),
	])
	_track(anim, "ForeArmL", times, [
		_rot(-30, 0, 0), _rot(-8, 0, 0), _rot(-8, 0, 0),
	])
	_track(anim, "ForeArmR", times, [
		_rot(-30, 0, 0), _rot(-8, 0, 0), _rot(-8, 0, 0),
	])
	_track(anim, "Head", times, [
		_rot(-8, 0, 0), _rot(6, 0, 0), _rot(0, 0, 0),
	])
	_track(anim, "Spine", times, [
		_rot(4, 0, 0), _rot(-8, 0, 0), _rot(0, 0, 0),
	])
	return anim
