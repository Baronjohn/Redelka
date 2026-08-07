class_name StatBlock
extends RefCounted

var str: int = 0
var dex: int = 0
var vit: int = 0
var agi: int = 0
var int_stat: int = 0
var mnd: int = 0
var res: int = 0
var luk: int = 0


static func from_dict(data: Dictionary) -> StatBlock:
	var block := StatBlock.new()
	block.str = int(data.get("str", 0))
	block.dex = int(data.get("dex", 0))
	block.vit = int(data.get("vit", 0))
	block.agi = int(data.get("agi", 0))
	block.int_stat = int(data.get("int", 0))
	block.mnd = int(data.get("mnd", 0))
	block.res = int(data.get("res", 0))
	block.luk = int(data.get("luk", 0))
	return block


func get_bonus(other: Dictionary) -> StatBlock:
	var result := StatBlock.new()
	result.str = str + int(other.get("str", 0))
	result.dex = dex + int(other.get("dex", 0))
	result.vit = vit + int(other.get("vit", 0))
	result.agi = agi + int(other.get("agi", 0))
	result.int_stat = int_stat + int(other.get("int", 0))
	result.mnd = mnd + int(other.get("mnd", 0))
	result.res = res + int(other.get("res", 0))
	result.luk = luk + int(other.get("luk", 0))
	return result


func duplicate_block() -> StatBlock:
	var copy := StatBlock.new()
	copy.str = str
	copy.dex = dex
	copy.vit = vit
	copy.agi = agi
	copy.int_stat = int_stat
	copy.mnd = mnd
	copy.res = res
	copy.luk = luk
	return copy


func add_block(other: StatBlock) -> void:
	str += other.str
	dex += other.dex
	vit += other.vit
	agi += other.agi
	int_stat += other.int_stat
	mnd += other.mnd
	res += other.res
	luk += other.luk


static func from_growth_dict(growth: Dictionary, level_count: int = 1) -> StatBlock:
	var block := StatBlock.new()
	if level_count <= 0:
		return block
	for stat_name: String in growth.keys():
		block.add_stat(stat_name, int(growth[stat_name]) * level_count)
	return block


func add_stat(stat_name: String, amount: int) -> void:
	match stat_name:
		"str":
			str += amount
		"dex":
			dex += amount
		"vit":
			vit += amount
		"agi":
			agi += amount
		"int":
			int_stat += amount
		"mnd":
			mnd += amount
		"res":
			res += amount
		"luk":
			luk += amount


func get_stat(stat_name: String) -> int:
	match stat_name:
		"str":
			return str
		"dex":
			return dex
		"vit":
			return vit
		"agi":
			return agi
		"int":
			return int_stat
		"mnd":
			return mnd
		"res":
			return res
		"luk":
			return luk
	return 0
