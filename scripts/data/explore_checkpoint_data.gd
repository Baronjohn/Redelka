class_name ExploreCheckpointData
extends RefCounted

var area_id: String = ""
var position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var party_members: Array = []
var inventory: Dictionary = {}
var equipped: Dictionary = {}
var owned_equipment: Dictionary = {}
var defeated_enemy_ids: Array[String] = []
var visited_area_ids: Array[String] = []


func duplicate_snapshot() -> ExploreCheckpointData:
	var copy: ExploreCheckpointData = new()
	copy.area_id = area_id
	copy.position = position
	copy.rotation_y = rotation_y
	copy.inventory = inventory.duplicate()
	copy.equipped = equipped.duplicate(true)
	copy.owned_equipment = owned_equipment.duplicate()
	copy.defeated_enemy_ids = defeated_enemy_ids.duplicate()
	copy.visited_area_ids = visited_area_ids.duplicate()
	for member: Variant in party_members:
		var snapshot := member as PartyMemberSnapshot
		copy.party_members.append(PartyMemberSnapshot.from_dict(snapshot.to_dict()))
	return copy
