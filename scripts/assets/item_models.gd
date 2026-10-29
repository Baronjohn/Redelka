class_name ItemModels
extends RefCounted

## Low-poly 3D models for every item that can lie in the world (pickups, the closet key, the bird).
## Built from primitives and lathed profiles with the shared environment textures, so items
## sit in any scene without separate assets. `build(item_id)` returns a Node3D whose origin is
## the point the item rests on; items without a dedicated model fall back by weapon class,
## equipment slot or item type.

const EnvironmentMaterialsScript = preload("res://scripts/assets/environment_materials.gd")

const GLASS: Color = Color(0.55, 0.62, 0.6, 0.38)
const POTION: Color = Color(0.45, 0.05, 0.05)
const CORK: Color = Color(0.5, 0.38, 0.24)
const THREAD_RED: Color = Color(0.6, 0.12, 0.1)
const BRASS: Color = Color(0.62, 0.48, 0.24)
const BONE: Color = Color(0.78, 0.74, 0.64)
const TAPE: Color = Color(0.08, 0.07, 0.07)
const FEATHER: Color = Color(0.32, 0.3, 0.28)
const STONE_BLUE: Color = Color(0.25, 0.34, 0.5)
const STONE_RED: Color = Color(0.5, 0.12, 0.12)
const STONE_GREEN: Color = Color(0.22, 0.38, 0.3)
const BIRD_WOOD: Color = Color(1.2, 1.05, 0.85)


static func build(item_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ItemModel"
	match item_id:
		"heal_potion":
			_potion(root)
		"revive_charm":
			_revive_charm(root)
		"memory_tape":
			_memory_tape(root)
		"arrow":
			_arrow_bundle(root)
		"cellar_key", "adjacent_room_key":
			_key(root)
		"wooden_bird":
			_wooden_bird(root)
		"leather_vest":
			_armor_stand(root, _tex("sackcloth", Color(0.62, 0.45, 0.32), 0.3), false)
		"chain_mail":
			_armor_stand(root, _tex("iron", Color(1.05, 1.05, 1.1), 0.12), true)
		"cloth_robe":
			_robe(root)
		"iron_helm":
			_helm(root)
		"scout_hood":
			_hood(root)
		"power_ring":
			_ring(root, STONE_RED)
		"guard_brooch":
			_brooch(root)
		"mind_pendant":
			_pendant(root)
		"swift_charm":
			_swift_charm(root)
		"iron_sword":
			_sword(root)
		"wooden_staff":
			_staff(root)
		"short_bow":
			_bow(root)
		"rusty_dagger":
			_dagger(root, Color(0.62, 0.42, 0.32), false)
		"skinning_knife":
			_dagger(root, Color(0.5, 0.51, 0.53), true)
		_:
			_fallback(root, item_id)
	return root


static func has_dedicated_model(item_id: String) -> bool:
	return item_id in [
		"heal_potion", "revive_charm", "memory_tape", "arrow", "cellar_key", "adjacent_room_key",
		"wooden_bird", "leather_vest", "chain_mail", "cloth_robe", "iron_helm", "scout_hood",
		"power_ring", "guard_brooch", "mind_pendant", "swift_charm", "iron_sword", "wooden_staff",
		"short_bow", "rusty_dagger", "skinning_knife",
	]


# --- items ---------------------------------------------------------------------------

static func _potion(root: Node3D) -> void:
	# A squat corked bottle, dark red inside, a twist of string at the neck. Lies a little tilted.
	var bottle := _group(root, Vector3(0, 0, 0), Vector3(0, 0, 8))
	var outer: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.11, 0.04), Vector2(0.11, 0.12),
		Vector2(0.09, 0.17), Vector2(0.035, 0.2), Vector2(0.03, 0.27), Vector2(0.038, 0.28)]
	var inner: Array[Vector2] = [Vector2(0.0, 0.01), Vector2(0.085, 0.012), Vector2(0.1, 0.045), Vector2(0.1, 0.11),
		Vector2(0.075, 0.15), Vector2(0.0, 0.15)]
	_add(bottle, _lathe(inner, 10), _flat(POTION, 0.25, Color(0.7, 0.08, 0.06)))
	_add(bottle, _lathe(outer, 10), _glass())
	_add(bottle, _cyl(0.03, 0.06, 6), _flat(CORK), Vector3(0, 0.3, 0))
	_add(bottle, _torus(0.034, 0.046, 8), _flat(Color(0.7, 0.65, 0.5)), Vector3(0, 0.22, 0))


static func _revive_charm(root: Node3D) -> void:
	# A folk charm: a carved bone disc on a cord, a bundle of twigs bound with red thread.
	_add(root, _torus(0.1, 0.115, 12), _flat(Color(0.35, 0.28, 0.2)), Vector3(0.02, 0.01, 0.02), Vector3(90, 0, 0))
	_add(root, _cyl(0.07, 0.02, 10), _flat(BONE), Vector3(-0.06, 0.012, -0.04))
	for i: int in range(5):
		var angle := -10.0 + i * 5.0
		_add(root, _box(Vector3(0.014, 0.014, 0.24)), _tex("bark", Color(1.4, 1.3, 1.2), 0.2),
			Vector3(0.08 + i * 0.012, 0.015, 0.0), Vector3(0, angle, 0))
	_add(root, _cyl(0.042, 0.03, 8), _flat(THREAD_RED), Vector3(0.105, 0.016, 0.0), Vector3(0, 0, 90))


static func _memory_tape(root: Node3D) -> void:
	# A wooden spool wound with inked ribbon, its tail trailing on the ground.
	var spool := _group(root, Vector3(0, 0.09, 0), Vector3(0, 0, 90))
	var wood := _tex("timber", Color(1.1, 1.0, 0.9), 0.2)
	_add(spool, _cyl(0.09, 0.025, 12), wood, Vector3(0, 0.085, 0))
	_add(spool, _cyl(0.09, 0.025, 12), wood, Vector3(0, -0.085, 0))
	_add(spool, _cyl(0.065, 0.15, 12), _flat(TAPE, 0.6), Vector3.ZERO)
	_add(spool, _cyl(0.02, 0.2, 6), wood, Vector3.ZERO)
	_add(root, _box(Vector3(0.13, 0.004, 0.32)), _flat(TAPE, 0.6), Vector3(0.02, 0.003, 0.2), Vector3(0, 12, 0))
	_add(root, _box(Vector3(0.04, 0.03, 0.04)), _flat(Color(0.65, 0.6, 0.5)), Vector3(0.0, 0.175, 0.0))


static func _arrow_bundle(root: Node3D) -> void:
	# Four arrows tied in a bundle with a twist of cord.
	for i: int in range(4):
		var offset := Vector3((i % 2) * 0.03 - 0.015, 0.02 + (i / 2) * 0.025, 0.0)
		var arrow := _group(root, offset, Vector3(0, (i - 1.5) * 4.0, 0))
		_add(arrow, _cyl(0.007, 0.7, 5), _tex("timber", Color(1.2, 1.1, 1.0), 0.3), Vector3.ZERO, Vector3(90, 0, 0))
		_add(arrow, _cone(0.018, 0.06), _flat(Color(0.3, 0.3, 0.32), 0.5), Vector3(0, 0, 0.38), Vector3(90, 0, 0))
		for f: int in range(2):
			_add(arrow, _box(Vector3(0.002, 0.03, 0.09)), _flat(FEATHER), Vector3(0, 0, -0.3), Vector3(0, 0, f * 90.0))
	_add(root, _cyl(0.05, 0.03, 8), _flat(Color(0.55, 0.45, 0.3)), Vector3(0, 0.035, 0.05), Vector3(90, 0, 0))


static func _key(root: Node3D) -> void:
	# A heavy iron key: ring bow, long shank, toothed bit.
	var iron := _flat(Color(0.28, 0.27, 0.27), 0.45)
	var key := _group(root, Vector3(0, 0.015, 0), Vector3(0, 25, 0))
	_add(key, _torus(0.045, 0.065, 10), iron, Vector3(0, 0, -0.14), Vector3(90, 0, 0))
	_add(key, _cyl(0.012, 0.22, 6), iron, Vector3(0, 0, 0.0), Vector3(90, 0, 0))
	_add(key, _box(Vector3(0.012, 0.012, 0.03)), iron, Vector3(0, 0, -0.09))
	_add(key, _box(Vector3(0.06, 0.016, 0.022)), iron, Vector3(0.03, 0, 0.1))
	_add(key, _box(Vector3(0.022, 0.016, 0.014)), iron, Vector3(0.055, 0, 0.075))


static func _wooden_bird(root: Node3D) -> void:
	# The bird Mira carved for Lily: round body, small head and beak, fanned tail, a little base.
	var wood := _tex("timber", BIRD_WOOD, 0.15)
	_add(root, _cyl(0.06, 0.025, 8), wood, Vector3(0, 0.0125, 0))
	_add(root, _sphere(0.06, 0.09), wood, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(0.8, 0.8, 1.25))
	_add(root, _sphere(0.04, 0.08), wood, Vector3(0, 0.15, 0.06))
	_add(root, _cone(0.014, 0.04), _flat(Color(0.28, 0.2, 0.14)), Vector3(0, 0.15, 0.11), Vector3(90, 0, 0))
	_add(root, _box(Vector3(0.07, 0.012, 0.08)), wood, Vector3(0, 0.1, -0.1), Vector3(-25, 0, 0))
	for side: float in [-1.0, 1.0]:
		_add(root, _box(Vector3(0.01, 0.04, 0.08)), wood, Vector3(side * 0.05, 0.09, -0.01), Vector3(0, 0, side * 12.0))
		_add(root, _box(Vector3(0.008, 0.008, 0.008)), _flat(Color(0.05, 0.04, 0.03)), Vector3(side * 0.024, 0.16, 0.085))


static func _armor_stand(root: Node3D, cloth: Material, sleeves: bool) -> void:
	# A body garment on a plain wooden stand: a cross post, the shell, laces or rings down the front.
	var wood := _tex("timber", Color(0.8, 0.75, 0.7), 0.5)
	_add(root, _box(Vector3(0.34, 0.04, 0.34)), wood, Vector3(0, 0.02, 0))
	_add(root, _cyl(0.025, 0.9, 6), wood, Vector3(0, 0.45, 0))
	_add(root, _box(Vector3(0.46, 0.04, 0.04)), wood, Vector3(0, 0.88, 0))
	var shell: Array[Vector2] = [Vector2(0.16, 0.42), Vector2(0.18, 0.55), Vector2(0.2, 0.72), Vector2(0.21, 0.82),
		Vector2(0.12, 0.9)]
	var body := _add(root, _lathe(shell, 12, true), cloth, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	body.name = "Body"
	if sleeves:
		for side: float in [-1.0, 1.0]:
			_add(root, _cyl(0.06, 0.2, 8, 0.07), cloth, Vector3(side * 0.24, 0.8, 0), Vector3(0, 0, side * 70.0))
	else:
		for y: float in [0.55, 0.65, 0.75]:
			_add(root, _box(Vector3(0.08, 0.01, 0.01)), _flat(Color(0.2, 0.14, 0.1)), Vector3(0, y, 0.15))


static func _robe(root: Node3D) -> void:
	var cloth := _tex("sackcloth", Color(0.45, 0.4, 0.55), 0.35)
	var wood := _tex("timber", Color(0.8, 0.75, 0.7), 0.5)
	_add(root, _box(Vector3(0.34, 0.04, 0.34)), wood, Vector3(0, 0.02, 0))
	_add(root, _cyl(0.025, 1.0, 6), wood, Vector3(0, 0.5, 0))
	var shell: Array[Vector2] = [Vector2(0.25, 0.08), Vector2(0.21, 0.4), Vector2(0.18, 0.7), Vector2(0.2, 0.88),
		Vector2(0.1, 0.98)]
	_add(root, _lathe(shell, 12, true), cloth, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.75))


static func _helm(root: Node3D) -> void:
	# An iron cap with a brim band and a nasal guard, lying on its side.
	var iron := _tex("iron", Color(1.1, 1.1, 1.15), 0.2)
	var helm := _group(root, Vector3(0, 0.12, 0), Vector3(0, 30, 70))
	var dome: Array[Vector2] = [Vector2(0.15, 0.0), Vector2(0.15, 0.06), Vector2(0.13, 0.13), Vector2(0.08, 0.19),
		Vector2(0.0, 0.21)]
	_add(helm, _lathe(dome, 12, true), iron)
	_add(helm, _torus(0.145, 0.165, 12), iron, Vector3(0, 0.015, 0))
	_add(helm, _box(Vector3(0.03, 0.14, 0.02)), iron, Vector3(0, -0.04, 0.155))
	_add(helm, _cyl(0.012, 0.012, 6), _flat(BRASS, 0.4), Vector3(0, 0.21, 0))


static func _hood(root: Node3D) -> void:
	var cloth := _tex("sackcloth", Color(0.5, 0.52, 0.42), 0.3)
	var hood: Array[Vector2] = [Vector2(0.14, 0.0), Vector2(0.15, 0.08), Vector2(0.12, 0.17), Vector2(0.04, 0.24),
		Vector2(0.0, 0.25)]
	_add(root, _lathe(hood, 10, true), cloth, Vector3(0, 0.07, 0), Vector3(-75, 0, 0), Vector3(1.0, 1.0, 0.7))
	_add(root, _box(Vector3(0.36, 0.02, 0.24)), cloth, Vector3(0, 0.01, 0.18), Vector3(0, 0, 4))


static func _ring(root: Node3D, stone: Color) -> void:
	# Small items sit on a scrap of cloth so they read at a distance.
	_add(root, _box(Vector3(0.26, 0.008, 0.22)), _tex("canvas", Color(0.8, 0.75, 0.75), 0.3), Vector3(0, 0.004, 0), Vector3(0, 15, 0))
	_add(root, _torus(0.04, 0.055, 12), _flat(BRASS, 0.35), Vector3(0, 0.03, 0), Vector3(70, 0, 0))
	_add(root, _sphere(0.02, 0.03), _flat(stone, 0.3, stone * 0.4), Vector3(0, 0.085, 0.01))


static func _brooch(root: Node3D) -> void:
	_add(root, _box(Vector3(0.26, 0.008, 0.22)), _tex("canvas", Color(0.8, 0.75, 0.75), 0.3), Vector3(0, 0.004, 0), Vector3(0, -10, 0))
	_add(root, _cyl(0.06, 0.016, 10), _flat(BRASS, 0.35), Vector3(0, 0.016, 0))
	_add(root, _cyl(0.025, 0.012, 8), _flat(STONE_BLUE, 0.3, STONE_BLUE * 0.4), Vector3(0, 0.028, 0))
	_add(root, _box(Vector3(0.15, 0.006, 0.006)), _flat(Color(0.4, 0.4, 0.42), 0.4), Vector3(0, 0.01, -0.03), Vector3(0, 20, 0))


static func _pendant(root: Node3D) -> void:
	_add(root, _torus(0.12, 0.13, 14), _flat(Color(0.32, 0.3, 0.3), 0.4), Vector3(0, 0.006, 0), Vector3(0, 0, 0))
	_add(root, _cyl(0.05, 0.016, 8), _flat(Color(0.35, 0.36, 0.4), 0.35), Vector3(0, 0.01, 0.14))
	_add(root, _cyl(0.022, 0.01, 6), _flat(STONE_GREEN, 0.3, STONE_GREEN * 0.4), Vector3(0, 0.02, 0.14))


static func _swift_charm(root: Node3D) -> void:
	_add(root, _torus(0.09, 0.1, 12), _flat(Color(0.3, 0.24, 0.18)), Vector3(0, 0.006, 0))
	_add(root, _box(Vector3(0.05, 0.006, 0.2)), _flat(FEATHER), Vector3(0.02, 0.012, 0.1), Vector3(0, 25, 0))
	_add(root, _sphere(0.022, 0.04), _flat(Color(0.6, 0.55, 0.4), 0.4), Vector3(-0.02, 0.022, 0.02))


static func _sword(root: Node3D) -> void:
	var iron := _flat(Color(0.55, 0.56, 0.58), 0.35)
	var sword := _group(root, Vector3(0, 0.025, 0), Vector3(0, 35, 0))
	_add(sword, _box(Vector3(0.05, 0.01, 0.62)), iron, Vector3(0, 0, 0.1))
	_add(sword, _prism(Vector3(0.05, 0.08, 0.01)), iron, Vector3(0, 0, 0.45), Vector3(90, 0, 0))
	_add(sword, _box(Vector3(0.2, 0.025, 0.03)), _flat(Color(0.3, 0.27, 0.24), 0.4), Vector3(0, 0, -0.22))
	_add(sword, _cyl(0.018, 0.14, 6), _tex("sackcloth", Color(0.35, 0.25, 0.18), 0.1), Vector3(0, 0, -0.3), Vector3(90, 0, 0))
	_add(sword, _sphere(0.025, 0.05), _flat(Color(0.3, 0.27, 0.24), 0.4), Vector3(0, 0, -0.38))


static func _staff(root: Node3D) -> void:
	var wood := _tex("bark", Color(1.3, 1.2, 1.05), 0.3)
	var staff := _group(root, Vector3(0, 0.03, 0), Vector3(0, -20, 0))
	for i: int in range(3):
		_add(staff, _cyl(0.024 - i * 0.003, 0.4, 6), wood, Vector3(i * 0.008, 0, -0.4 + i * 0.4), Vector3(90, 0, 0))
	_add(staff, _sphere(0.045, 0.08), wood, Vector3(0.02, 0, 0.62))


static func _bow(root: Node3D) -> void:
	var wood := _tex("timber", Color(1.15, 1.0, 0.85), 0.3)
	var bow := _group(root, Vector3(0, 0.02, 0), Vector3(0, 15, 0))
	for i: int in range(7):
		var t := (float(i) - 3.0) / 3.0
		var angle := t * 50.0
		var pos := Vector3(cos(deg_to_rad(t * 50.0)) * 0.42 - 0.42, 0, sin(deg_to_rad(t * 50.0)) * 0.42)
		_add(bow, _box(Vector3(0.025, 0.02, 0.12)), wood, pos, Vector3(0, -angle, 0))
	_add(bow, _box(Vector3(0.004, 0.004, 0.65)), _flat(Color(0.8, 0.78, 0.7)), Vector3(-0.15, 0, 0))
	_add(bow, _box(Vector3(0.035, 0.03, 0.08)), _tex("sackcloth", Color(0.4, 0.3, 0.22), 0.1), Vector3(0.0, 0, 0))


static func _dagger(root: Node3D, metal: Color, curved: bool) -> void:
	var steel := _flat(metal, 0.4)
	var knife := _group(root, Vector3(0, 0.018, 0), Vector3(0, -40, 0))
	_add(knife, _box(Vector3(0.035, 0.008, 0.2)), steel, Vector3(0, 0, 0.08))
	if curved:
		_add(knife, _box(Vector3(0.03, 0.008, 0.08)), steel, Vector3(0.012, 0, 0.21), Vector3(0, -18, 0))
	else:
		_add(knife, _prism(Vector3(0.035, 0.05, 0.008)), steel, Vector3(0, 0, 0.2), Vector3(90, 0, 0))
	_add(knife, _box(Vector3(0.07, 0.016, 0.018)), _flat(Color(0.25, 0.22, 0.2), 0.4), Vector3(0, 0, -0.03))
	_add(knife, _cyl(0.014, 0.1, 6), _tex("timber", Color(0.7, 0.6, 0.5), 0.1), Vector3(0, 0, -0.09), Vector3(90, 0, 0))


static func _fallback(root: Node3D, item_id: String) -> void:
	# Unknown items: a weapon by class, gear by slot, anything else a tied bundle.
	var weapons := DataLoader.load_weapons()
	if weapons.has(item_id):
		match (weapons[item_id] as WeaponData).weapon_class:
			"sword":
				_sword(root)
			"staff":
				_staff(root)
			"bow":
				_bow(root)
			_:
				_dagger(root, Color(0.6, 0.6, 0.62), false)
		return
	var equipment := DataLoader.load_equipment()
	if equipment.has(item_id):
		match str(equipment[item_id].slot):
			"armor":
				_armor_stand(root, _tex("sackcloth", Color(0.6, 0.55, 0.5), 0.3), false)
			"helmet":
				_helm(root)
			_:
				_ring(root, STONE_BLUE)
		return
	var cloth := EnvironmentMaterialsScript.create_pickup_material()
	_add(root, _box(Vector3(0.36, 0.22, 0.3)), cloth, Vector3(0, 0.11, 0))
	_add(root, _box(Vector3(0.12, 0.1, 0.12)), cloth, Vector3(0, 0.26, 0))


# --- mesh helpers ----------------------------------------------------------------------

static func _group(parent: Node3D, pos: Vector3, rot_deg: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation_degrees = rot_deg
	parent.add_child(node)
	return node


static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_deg
	instance.scale = scale
	parent.add_child(instance)
	return instance


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cyl(radius: float, height: float, segments: int, top: float = -1.0) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func _cone(radius: float, height: float) -> CylinderMesh:
	return _cyl(radius, height, 6, 0.0)


static func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


static func _torus(inner: float, outer: float, segments: int) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = segments
	mesh.ring_segments = 5
	return mesh


static func _prism(size: Vector3) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = size
	return mesh


## Revolves a (radius, height) profile around the Y axis. `two_sided` also emits the inside
## faces, for open shells such as a helm or a garment.
static func _lathe(profile: Array[Vector2], segments: int, two_sided: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(profile.size() - 1):
		var a := profile[i]
		var b := profile[i + 1]
		for s: int in range(segments):
			var t0 := TAU * float(s) / float(segments)
			var t1 := TAU * float(s + 1) / float(segments)
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p01 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p10 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			# Godot treats clockwise triangles as front faces; this order faces outward.
			for v: Vector3 in [p00, p11, p10, p00, p01, p11]:
				st.add_vertex(v)
			if two_sided:
				for v: Vector3 in [p00, p10, p11, p00, p11, p01]:
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()


# --- materials -------------------------------------------------------------------------

static func _tex(texture: String, tint: Color, tile: float) -> StandardMaterial3D:
	return EnvironmentMaterialsScript.world_material(texture, tint, tile)


static func _flat(albedo: Color, roughness: float = 0.85, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = 0.0
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.5
	return material


static func _glass() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = GLASS
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return material
