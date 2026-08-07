class_name ExploreCheckpointData
extends RefCounted

var area_id: String = ""
var position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var party_members: Array = []
var inventory: Dictionary = {}
var defeated_enemy_ids: Array[String] = []


func duplicate_snapshot():
	var copy: ExploreCheckpointData = new()
	copy.area_id = area_id
	copy.position = position
	copy.rotation_y = rotation_y
	copy.inventory = inventory.duplicate()
	copy.defeated_enemy_ids = defeated_enemy_ids.duplicate()
	for member: Variant in party_members:
		var snapshot := member as PartyMemberSnapshot
		copy.party_members.append(PartyMemberSnapshot.from_dict(snapshot.to_dict()))
	return copy
