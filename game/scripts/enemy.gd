class_name Enemy
extends Node3D

## 侵入者。外周に出現し、ダンジョンコア（魔力タンク）を目指す。
## 防壁などの施設マスは高コストで通れるマスとして経路探索し、
## 迂回より壊す方が安ければ壊して進む（docs/DECISIONS.md）。
## 幻惑中は最も近い味方（他の敵）を攻撃する（2026-11-18決定）。

var hp := 0.0
var max_hp := 0.0
var alive := true
var spawn_cell := Vector2i.ZERO
var path: Array = []
var attack_cooldown := 0.0
var charm_remaining := 0.0
var current_target = null # 幻惑中のみ：攻撃対象の Enemy

var _mat: StandardMaterial3D
var _y_off := 0.55

const COLOR_NORMAL := Color(0.78, 0.74, 0.66)
const COLOR_CHARMED := Color(0.62, 0.34, 0.85)


func setup(world: Vector3, p_hp: float) -> void:
	max_hp = p_hp
	hp = p_hp
	position = world + Vector3(0, _y_off, 0)
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.05
	mi.mesh = cap
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR_NORMAL
	mi.material_override = _mat
	add_child(mi)


func current_cell() -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.z))


func is_charmed() -> bool:
	return charm_remaining > 0.0


func apply_charm(duration: float) -> void:
	charm_remaining = maxf(charm_remaining, duration)
	current_target = null
	path.clear()
	_update_tint()


func tick(dt: float, game) -> void:
	if not alive:
		return
	attack_cooldown -= dt
	if charm_remaining > 0.0:
		charm_remaining -= dt
		if charm_remaining <= 0.0:
			charm_remaining = 0.0
			current_target = null
			path.clear()
			_update_tint()
	if is_charmed():
		_tick_charmed(dt, game)
		return
	# すぐ近くの配下には反撃する
	var m = _nearest_minion(game)
	if m != null:
		_attack(m)
		return
	_tick_advance(dt, game)


func _tick_charmed(dt: float, game) -> void:
	var best = null
	var bd := INF
	for e in game.enemies:
		if e == self or not e.alive:
			continue
		var d := _hdist(position, e.position)
		if d < bd:
			bd = d
			best = e
	current_target = best
	if best == null:
		return
	if bd <= Balance.ENEMY_ATTACK_RANGE:
		_attack(best)
	else:
		_move_toward(best.position, dt)


func _tick_advance(dt: float, game) -> void:
	if path.is_empty():
		path = Pathfinding.find_path(game.board, game.facilities, current_cell(), game.board.core_cell)
		if path.is_empty():
			return
	var next: Vector2i = path[0]
	var target_pos: Vector3 = game.board.cell_to_world(next)
	var dist := _hdist(position, target_pos)
	if next == game.board.core_cell:
		if dist <= Balance.ENEMY_ATTACK_RANGE:
			if attack_cooldown <= 0.0:
				game.damage_core(Balance.ENEMY_DAMAGE)
				attack_cooldown = Balance.ENEMY_ATTACK_INTERVAL
		else:
			_move_toward(target_pos, dt)
		return
	var blocker = game.facility_at(next)
	if blocker != null and blocker.alive:
		if dist <= Balance.ENEMY_ATTACK_RANGE:
			_attack(blocker)
		else:
			_move_toward(target_pos, dt)
		return
	_move_toward(target_pos, dt)
	if dist < 0.12:
		path.pop_front()


func _nearest_minion(game):
	var best = null
	var bd := Balance.ENEMY_ATTACK_RANGE
	for mn in game.minions:
		if not mn.alive:
			continue
		var d := _hdist(position, mn.position)
		if d <= bd:
			bd = d
			best = mn
	return best


func _attack(target) -> void:
	if attack_cooldown <= 0.0:
		target.take_damage(Balance.ENEMY_DAMAGE)
		attack_cooldown = Balance.ENEMY_ATTACK_INTERVAL


func _move_toward(target_pos: Vector3, dt: float) -> void:
	var dir := target_pos - position
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	position += dir.normalized() * Balance.ENEMY_SPEED * dt


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		alive = false


func _update_tint() -> void:
	if _mat != null:
		_mat.albedo_color = COLOR_CHARMED if is_charmed() else COLOR_NORMAL


func _hdist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
