class_name Facility
extends Node3D

## 防衛施設（防壁・弓塔・魔法塔・採掘所の基底）。
## 準備中に自由配置し、戦闘中は自動で迎撃する。壊れても wave 終了後に復旧する。

var kind := ""
var cell := Vector2i.ZERO
var hp := 0.0
var max_hp := 0.0
var alive := true
var attack_cooldown := 0.0

var _mat: StandardMaterial3D
var _base_color := Color.WHITE

const COLORS := {
	"wall": Color(0.45, 0.47, 0.52),
	"archer": Color(0.30, 0.48, 0.30),
	"mage": Color(0.38, 0.32, 0.58),
	"mine": Color(0.42, 0.31, 0.17),
}
const SIZES := {
	"wall": Vector3(0.96, 0.7, 0.96),
	"archer": Vector3(0.66, 1.5, 0.66),
	"mage": Vector3(0.66, 1.5, 0.66),
	"mine": Vector3(0.9, 0.5, 0.9),
}


func setup(p_kind: String, p_cell: Vector2i, world: Vector3) -> void:
	kind = p_kind
	cell = p_cell
	var d: Dictionary = Balance.FACILITIES[kind]
	max_hp = float(d["hp"])
	hp = max_hp
	position = world
	_base_color = COLORS[kind]
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	var sz: Vector3 = SIZES[kind]
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = Vector3(0, sz.y * 0.5, 0)
	mi.material_override = _mat
	add_child(mi)
	if kind == "archer" or kind == "mage":
		var top := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.4, 0.3, 0.4)
		top.mesh = tb
		top.position = Vector3(0, sz.y + 0.15, 0)
		top.material_override = _mat
		add_child(top)


func label() -> String:
	return String(Balance.FACILITIES[kind]["label"])


func base_damage() -> float:
	return float(Balance.FACILITIES[kind]["damage"])


func attack_range() -> float:
	return float(Balance.FACILITIES[kind]["range"])


func attack_interval() -> float:
	return float(Balance.FACILITIES[kind]["interval"])


## 全体魔法の倍率込みの実ダメージ（施設もバフ対象：2026-11-18決定）。
func current_damage(magic) -> float:
	return base_damage() * magic.multiplier()


func tick(dt: float, game) -> void:
	if not alive or base_damage() <= 0.0:
		return
	attack_cooldown -= dt
	var target = null
	var best := attack_range()
	for e in game.enemies:
		if not e.alive:
			continue
		var dist := _hdist(position, e.position)
		if dist <= best:
			best = dist
			target = e
	if target != null and attack_cooldown <= 0.0:
		target.take_damage(current_damage(game.magic))
		attack_cooldown = attack_interval()


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		alive = false
		_mat.albedo_color = Color(0.15, 0.15, 0.16)


func restore() -> void:
	hp = max_hp
	alive = true
	visible = true
	attack_cooldown = 0.0
	if _mat != null:
		_mat.albedo_color = _base_color


func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
