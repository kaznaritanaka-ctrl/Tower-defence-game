class_name Economy
extends Node

## 資金と資材の所持量。入手・消費の規則は Main / WaveManager 側に置く。

var funds := 0
var materials := 0


func setup() -> void:
	funds = Balance.FUNDS_START
	materials = Balance.MATERIALS_START


func can_afford(cost_materials: int, cost_funds: int) -> bool:
	return materials >= cost_materials and funds >= cost_funds


func spend(cost_materials: int, cost_funds: int) -> bool:
	if not can_afford(cost_materials, cost_funds):
		return false
	materials -= cost_materials
	funds -= cost_funds
	return true


func refund(cost_materials: int, cost_funds: int) -> void:
	materials += cost_materials
	funds += cost_funds


func add_funds(v: int) -> void:
	funds += v


func add_materials(v: int) -> void:
	materials += v
