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
