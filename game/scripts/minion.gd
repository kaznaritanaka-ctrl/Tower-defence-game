class_name Minion
extends Node3D

## 配下（デーモン／サキュバス）。準備中に配置し、戦闘中はタップで移動を指示する。
## 到着後は周囲の敵と自動で戦う。倒されても wave 終了後に復帰する。
## サキュバスは幻惑魔法を使う：範囲内の敵1体を数秒間同士討ちさせる（2026-11-18決定）。

var species := ""
var hp := 0.0
var max_hp := 0.0
var alive := true
var home_cell := Vector2i.ZERO # 準備中の配置位置。wave 終了後の復帰先
var path: Array = []
var attack_cooldown := 0.0
var charm_cooldown := 0.0

var _y_off := 0.65

const COLORS := {
	"demon": Color(0.55, 0.16, 0.20),
	"succubus": Color(0.82, 0.42, 0.62),
}


func setup(p_species: String, board, cell: Vector2i) -> void:
	species = p_species
	var d: Dictionary = Balance.MINIONS[species]
	max_hp = float(d["hp"])
	hp = max_hp
	home_cell = cell
	_y_off = 0.8 if species == "demon" else 0.65
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.34 if species == "demon" else 0.28
	cap.height = 1.5 if species == "demon" else 1.2
	mi.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = COLORS[species]
	mi.material_override = m
	add_child(mi)
	place_at(board, cell)


func label() -> String:
	return String(Balance.MINIONS[species]["label"])


func current_cell() -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.z))


func place_at(board, cell: Vector2i) -> void:
	position = board.cell_to_world(cell) + Vector3(0, _y_off, 0)
	path.clear()


func order_move(board, facilities: Dictionary, dest: Vector2i) -> void:
	if not alive:
		return
	path = Pathfinding.find_path(board, facilities, current_cell(), dest, true)


func base_damage() -> float:
	return float(Balance.MINIONS[species]["damage"])


## 全体魔法の倍率込みの実ダメージ（配下もバフ対象：2026-11-18決定）。
func current_damage(magic) -> float:
	return base_damage() * magic.multiplier()


func _speed() -> float:
	return float(Balance.MINIONS[species]["speed"])


func _attack_range() -> float:
	return float(Balance.MINIONS[species]["range"])


func _attack_interval() -> float:
	return float(Balance.MINIONS[species]["interval"])


func tick(dt: float, game) -> void:
	if not alive:
		return
	attack_cooldown -= dt
	if species == "succubus":
		_tick_charm(dt, game)
	var target = null
	var best := _attack_range()
	for e in game.enemies:
		if not e.alive:
			continue
		var dist := _hdist(position, e.position)
		if dist <= best:
			best = dist
			target = e
	if target != null:
		if attack_cooldown <= 0.0:
			target.take_damage(current_damage(game.magic))
			attack_cooldown = _attack_interval()
		return
	if not path.is_empty():
		var dest: Vector3 = game.board.cell_to_world(path[0]) + Vector3(0, _y_off, 0)
		if _hdist(position, dest) < 0.1:
			path.pop_front()
		else:
			var dir := dest - position
			dir.y = 0.0
			position += dir.normalized() * _speed() * dt


func _tick_charm(dt: float, game) -> void:
	charm_cooldown -= dt
	if charm_cooldown > 0.0:
		return
	var target = null
	var best := Balance.CHARM_RANGE
	for e in game.enemies:
		if not e.alive or e.is_charmed():
			continue
		var dist := _hdist(position, e.position)
		if dist <= best:
			best = dist
			target = e
	if target != null:
		target.apply_charm(Balance.CHARM_DURATION)
		charm_cooldown = Balance.CHARM_COOLDOWN


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		alive = false
		visible = false


func restore(board) -> void:
	hp = max_hp
	alive = true
	visible = true
	attack_cooldown = 0.0
	charm_cooldown = 0.0
	place_at(board, home_cell)


func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
