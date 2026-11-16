extends RefCounted
## ゲームの状態とルール。描画には依存しない。
## 位置は Vector2(x, y) で表し、マスの中心が整数座標になる。

const B = preload("res://core/balance.gd")
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var rng := RandomNumberGenerator.new()

## 盤面
var floor_cells := {}            # Vector2i -> true
var facilities := {}             # Vector2i -> {type, hp, cd}
var core_cell := Vector2i.ZERO
var core_hp := 0.0
var dig_marks: Array[Vector2i] = []
var board_version := 0           # 盤面の見た目が変わるたびに増やす

## 資源と成長
var mana := 0.0
var materials := 0
var funds := 0
var research := {}               # 研究の種類 -> 段階
var minions: Array = []          # {type, hired, home, pos, hp, cd, path, alive}

## 進行
var unlocked := 1                # 挑戦できる wave の数
var cleared := {}                # クリア済みの wave 番号 -> true
var phase := "prep"              # prep / battle / result
var wave_index := 0
var last_result := {}

## 戦闘中の状態
var enemies: Array = []          # {id, type, pos, entry, hp, max_hp, cd, slow}
var spawn_queue: Array = []      # {t, type, slot}
var spawn_dirs: Array = []       # この wave で使う方向（DIRS の番号）
var spawn_entries: Array = []    # 方向ごとの侵入マス
var time := 0.0
var buff_time := 0.0
var shots: Array = []            # 表示用：{from, to, ttl, kind}

var _flow := {}                  # マス -> コアへ向かう次のマス
var _next_id := 1
var _min_c := 0
var _max_c := 0


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var n: int = B.BOARD_SIZE
	@warning_ignore("integer_division")
	var margin: int = (B.BOARD_LIMIT_LV1 - n) / 2
	_min_c = -margin
	_max_c = n - 1 + margin
	for y in n:
		for x in n:
			floor_cells[Vector2i(x, y)] = true
	@warning_ignore("integer_division")
	core_cell = Vector2i(n / 2, n / 2)
	core_hp = B.CORE["hp"]
	mana = B.START["mana"]
	materials = B.START["materials"]
	funds = B.START["funds"]
	for key in B.RESEARCH:
		research[key] = 0
	var homes := {"demon": core_cell + Vector2i(-1, 1), "succubus": core_cell + Vector2i(1, 1)}
	for type in B.MINIONS:
		var home: Vector2i = homes.get(type, core_cell + Vector2i(0, 1))
		minions.append({
			"type": type, "hired": false, "home": home, "pos": Vector2(home),
			"hp": float(B.MINIONS[type]["hp"]), "cd": 0.0, "path": [], "alive": true,
		})
	_rebuild_flow()


# ---------------------------------------------------------------- 盤面

func is_floor(c: Vector2i) -> bool:
	return floor_cells.has(c)


func in_limit(c: Vector2i) -> bool:
	return c.x >= _min_c and c.x <= _max_c and c.y >= _min_c and c.y <= _max_c


## 盤面に接していて、このLvで掘れる岩盤か。
func is_rock(c: Vector2i) -> bool:
	if is_floor(c) or not in_limit(c):
		return false
	for d in DIRS:
		if is_floor(c + d):
			return true
	return false


func rock_cells() -> Array:
	var found := {}
	for c in floor_cells:
		for d in DIRS:
			var n: Vector2i = c + d
			if is_rock(n):
				found[n] = true
	return found.keys()


## 通行を塞ぐものが立っているか（コア、壊れていない防壁と塔）。
func is_blocked(c: Vector2i) -> bool:
	if c == core_cell:
		return true
	var f = facilities.get(c)
	if f == null:
		return false
	return f["hp"] > 0.0 and B.FACILITIES[f["type"]]["block"]


# ---------------------------------------------------------------- 資源

func can_afford(cost: Dictionary) -> bool:
	return (
		materials >= int(cost.get("materials", 0))
		and funds >= int(cost.get("funds", 0))
		and mana >= float(cost.get("mana", 0.0))
	)


func _pay(cost: Dictionary, direction: int = 1) -> void:
	materials -= direction * int(cost.get("materials", 0))
	funds -= direction * int(cost.get("funds", 0))
	mana -= direction * float(cost.get("mana", 0.0))


func mana_regen() -> float:
	return float(B.MANA["regen"]) * (1.0 + float(B.RESEARCH["mana_regen"]["bonus"]) * research["mana_regen"])


func mana_cap() -> float:
	return float(B.MANA["cap"]) * (1.0 + float(B.RESEARCH["mana_cap"]["bonus"]) * research["mana_cap"])


func minion_damage_mult() -> float:
	return 1.0 + float(B.RESEARCH["weapon"]["bonus"]) * research["weapon"]


# ---------------------------------------------------------------- 準備中の操作

func can_place(type: String, c: Vector2i) -> bool:
	if phase != "prep" or not B.FACILITIES.has(type):
		return false
	if not is_floor(c) or c == core_cell or facilities.has(c):
		return false
	if B.FACILITIES[type]["block"]:
		for m in minions:
			if m["hired"] and m["home"] == c:
				return false
	return can_afford(B.FACILITIES[type])


func place(type: String, c: Vector2i) -> bool:
	if not can_place(type, c):
		return false
	_pay(B.FACILITIES[type])
	facilities[c] = {"type": type, "hp": float(B.FACILITIES[type]["hp"]), "cd": 0.0}
	board_version += 1
	_rebuild_flow()
	return true


## 撤去は全額返還。
func remove(c: Vector2i) -> bool:
	if phase != "prep" or not facilities.has(c):
		return false
	_pay(B.FACILITIES[facilities[c]["type"]], -1)
	facilities.erase(c)
	board_version += 1
	_rebuild_flow()
	return true


## 採掘先の指定と取り消し。掘った結果は wave 終了時に反映する。
func toggle_dig(c: Vector2i) -> bool:
	if phase != "prep":
		return false
	if dig_marks.has(c):
		dig_marks.erase(c)
	elif is_rock(c) and dig_marks.size() < int(B.DIG["per_wave"]):
		dig_marks.append(c)
	else:
		return false
	board_version += 1
	return true


func hire(type: String) -> bool:
	if phase != "prep":
		return false
	for m in minions:
		if m["type"] == type and not m["hired"]:
			var cost := {"funds": B.MINIONS[type]["hire"]}
			if not can_afford(cost):
				return false
			_pay(cost)
			m["hired"] = true
			# 持ち場に設備が置かれていたら、近くの空いたマスへ移す。
			if is_blocked(m["home"]):
				m["home"] = _nearest_free(m["home"])
				m["pos"] = Vector2(m["home"])
			return true
	return false


## 配下の移動。準備中は持ち場の変更、戦闘中は移動の指示。
func move_minion(index: int, c: Vector2i) -> bool:
	if index < 0 or index >= minions.size():
		return false
	var m = minions[index]
	if not m["hired"] or not is_floor(c) or is_blocked(c):
		return false
	if phase == "prep":
		m["home"] = c
		m["pos"] = Vector2(c)
		return true
	if phase != "battle" or not m["alive"]:
		return false
	var start := Vector2i(Vector2(m["pos"]).round())
	if start == c:
		m["path"] = [c]
		return true
	var path := _find_path(start, c)
	if path.is_empty():
		return false
	m["path"] = path
	return true


func do_research(key: String) -> bool:
	if phase != "prep" or not B.RESEARCH.has(key):
		return false
	var spec: Dictionary = B.RESEARCH[key]
	if research[key] >= int(spec["max"]) or not can_afford(spec):
		return false
	_pay(spec)
	research[key] += 1
	return true


# ---------------------------------------------------------------- wave

func wave_count() -> int:
	return B.WAVES.size()


func wave_reward(i: int) -> int:
	var base: int = B.WAVES[i]["reward"]
	if cleared.has(i):
		return int(round(base * float(B.REPLAY_REWARD_RATE)))
	return base


## 襲撃の前に見せる情報：敵の編成、方向の数、報酬。出現位置は含めない。
func wave_info(i: int) -> Dictionary:
	var counts := {}
	for g in B.WAVES[i]["groups"]:
		for u in g["units"]:
			counts[u[0]] = int(counts.get(u[0], 0)) + int(u[1])
	return {
		"counts": counts, "directions": B.WAVES[i]["directions"],
		"reward": wave_reward(i), "replay": cleared.has(i),
	}


func start_wave(i: int) -> bool:
	if phase != "prep" or i < 0 or i >= unlocked:
		return false
	phase = "battle"
	wave_index = i
	time = 0.0
	buff_time = 0.0
	enemies.clear()
	shots.clear()
	_restore()
	_rebuild_flow()
	# 方向を抽選する。同じ wave でも毎回変わる。
	var order: Array = [0, 1, 2, 3]
	for k in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = order[k]
		order[k] = order[j]
		order[j] = tmp
	spawn_dirs = order.slice(0, int(B.WAVES[i]["directions"]))
	spawn_entries.clear()
	for d in spawn_dirs:
		var edge := _edge_cells(d)
		spawn_entries.append(edge[rng.randi_range(0, edge.size() - 1)])
	spawn_queue.clear()
	for g in B.WAVES[i]["groups"]:
		var t: float = g["at"]
		for u in g["units"]:
			for n in int(u[1]):
				spawn_queue.append({"t": t, "type": u[0], "slot": int(g["slot"])})
				t += float(B.SPAWN_INTERVAL)
	spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	board_version += 1
	return true


func confirm_result() -> void:
	if phase == "result":
		phase = "prep"


func cast_spell() -> bool:
	if phase != "battle" or mana < float(B.SPELL["mana"]):
		return false
	mana -= float(B.SPELL["mana"])
	buff_time = float(B.SPELL["duration"])
	return true


func tick(dt: float) -> void:
	if phase != "battle":
		return
	time += dt
	mana = minf(mana_cap(), mana + mana_regen() * dt)
	buff_time = maxf(0.0, buff_time - dt)
	for s in shots:
		s["ttl"] -= dt
	shots = shots.filter(func(s): return s["ttl"] > 0.0)
	while not spawn_queue.is_empty() and spawn_queue[0]["t"] <= time:
		_spawn(spawn_queue.pop_front())
	_update_enemies(dt)
	_update_facilities(dt)
	_update_minions(dt)
	enemies = enemies.filter(func(e): return e["hp"] > 0.0)
	if core_hp <= 0.0:
		_end_wave(false)
	elif spawn_queue.is_empty() and enemies.is_empty():
		_end_wave(true)


# ---------------------------------------------------------------- 内部処理

func _restore() -> void:
	core_hp = B.CORE["hp"]
	for c in facilities:
		var f = facilities[c]
		f["hp"] = float(B.FACILITIES[f["type"]]["hp"])
		f["cd"] = 0.0
	for m in minions:
		m["hp"] = float(B.MINIONS[m["type"]]["hp"])
		m["alive"] = true
		m["pos"] = Vector2(m["home"])
		m["path"] = []
		m["cd"] = 0.0


func _end_wave(win: bool) -> void:
	var reward := 0
	var first := not cleared.has(wave_index)
	if win:
		reward = wave_reward(wave_index)
		funds += reward
		cleared[wave_index] = true
		unlocked = mini(wave_count(), maxi(unlocked, wave_index + 2))
	# 採掘は勝敗にかかわらず反映する。
	var dug := dig_marks.size()
	for c in dig_marks:
		floor_cells[c] = true
	var gained := dug * int(B.DIG["materials"])
	materials += gained
	dig_marks.clear()
	enemies.clear()
	spawn_queue.clear()
	shots.clear()
	buff_time = 0.0
	_restore()
	_rebuild_flow()
	board_version += 1
	phase = "result"
	last_result = {
		"win": win, "wave": wave_index, "reward": reward, "first": first,
		"materials": gained, "dug": dug,
		"final": win and wave_index == wave_count() - 1,
	}


## ある方向の外周マス。列（または行）ごとに、その方向へ最も外側のマスを返す。
func _edge_cells(dir_index: int) -> Array:
	var d: Vector2i = DIRS[dir_index]
	var best := {}
	for c in floor_cells:
		var line: int = c.x if d.x == 0 else c.y
		var depth: int = c.x * d.x + c.y * d.y
		if not best.has(line) or depth > int(best[line][0]):
			best[line] = [depth, c]
	var cells: Array = []
	for line in best:
		cells.append(best[line][1])
	return cells


func _spawn(item: Dictionary) -> void:
	var slot: int = item["slot"]
	var entry: Vector2i = spawn_entries[slot]
	var d: Vector2i = DIRS[spawn_dirs[slot]]
	var spec: Dictionary = B.ENEMIES[item["type"]]
	enemies.append({
		"id": _next_id, "type": item["type"], "pos": Vector2(entry) + Vector2(d),
		"entry": entry, "hp": float(spec["hp"]), "max_hp": float(spec["hp"]),
		"cd": 0.0, "slow": 0.0,
	})
	_next_id += 1


## コアから外へ向けて最短経路を求め、各マスの「次に進むマス」を記録する。
## 防壁や塔のマスは高いコストで通れる扱いにする。完全に塞がれていても経路は必ず見つかる。
func _rebuild_flow() -> void:
	_flow.clear()
	var dist := {core_cell: 0.0}
	var open: Array = [core_cell]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if dist[open[i]] < dist[open[bi]]:
				bi = i
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		var step := 1.0
		if c != core_cell and is_blocked(c):
			step += float(B.WALL_PATH_COST)
		for d in DIRS:
			var n: Vector2i = c + d
			if not is_floor(n) or n == core_cell:
				continue
			var nd: float = dist[c] + step
			if not dist.has(n) or nd < dist[n] - 0.0001:
				dist[n] = nd
				_flow[n] = c
				if not open.has(n):
					open.append(n)


## 指定したマスに最も近い、塞がれていない床のマス。
func _nearest_free(from: Vector2i) -> Vector2i:
	var best := from
	var best_d := INF
	for c in floor_cells:
		if is_blocked(c):
			continue
		var d := Vector2(c).distance_to(Vector2(from))
		if d < best_d:
			best_d = d
			best = c
	return best


## 配下の移動経路。塞がれたマスは通らない。
func _find_path(start: Vector2i, goal: Vector2i) -> Array:
	var prev := {start: start}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or not is_floor(n) or is_blocked(n):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(goal):
		return []
	var path: Array = []
	var cur := goal
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	return path


func _nearest_enemy(pos: Vector2, reach: float):
	var best = null
	var best_d := reach
	for e in enemies:
		if e["hp"] <= 0.0:
			continue
		var d: float = pos.distance_to(e["pos"])
		if d <= best_d:
			best_d = d
			best = e
	return best


func _nearest_minion(pos: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach
	for i in minions.size():
		var m = minions[i]
		if not m["hired"] or not m["alive"]:
			continue
		var d: float = pos.distance_to(m["pos"])
		if d <= best_d:
			best_d = d
			best = i
	return best


func _nearest_tower(pos: Vector2, reach: float):
	var best = null
	var best_d := reach
	for c in facilities:
		var f = facilities[c]
		if f["hp"] <= 0.0 or (f["type"] != "arrow" and f["type"] != "mage"):
			continue
		var d: float = pos.distance_to(Vector2(c))
		if d <= best_d:
			best_d = d
			best = c
	return best


func _add_shot(from: Vector2, to: Vector2, kind: String) -> void:
	shots.append({"from": from, "to": to, "ttl": 0.18, "kind": kind})


func _hit_minion(e: Dictionary, spec: Dictionary, index: int) -> void:
	if e["cd"] > 0.0:
		return
	e["cd"] = float(spec["interval"])
	var m = minions[index]
	m["hp"] -= float(spec["damage"])
	_add_shot(e["pos"], m["pos"], "enemy")
	if m["hp"] <= 0.0:
		m["hp"] = 0.0
		m["alive"] = false
		m["path"] = []


func _hit_facility(e: Dictionary, spec: Dictionary, c: Vector2i) -> void:
	if e["cd"] > 0.0:
		return
	e["cd"] = float(spec["interval"])
	var f = facilities[c]
	f["hp"] -= float(spec["damage"])
	_add_shot(e["pos"], Vector2(c), "enemy")
	if f["hp"] <= 0.0:
		f["hp"] = 0.0
		board_version += 1
		_rebuild_flow()


func _hit_core(e: Dictionary, spec: Dictionary) -> void:
	if e["cd"] > 0.0:
		return
	e["cd"] = float(spec["interval"])
	core_hp = maxf(0.0, core_hp - float(spec["damage"]))
	_add_shot(e["pos"], Vector2(core_cell), "enemy")


func _update_enemies(dt: float) -> void:
	for e in enemies:
		if e["hp"] <= 0.0:
			continue
		var spec: Dictionary = B.ENEMIES[e["type"]]
		e["cd"] = maxf(0.0, e["cd"] - dt)
		e["slow"] = maxf(0.0, e["slow"] - dt)
		var pos: Vector2 = e["pos"]
		var cell := Vector2i(pos.round())
		var shoot_range: float = spec["range"]
		# 1) 近くの配下を狙う
		var mi := _nearest_minion(pos, maxf(shoot_range, float(B.MELEE_REACH)))
		if mi >= 0:
			_hit_minion(e, spec, mi)
			continue
		# 2) 弓兵は射程内の塔とコアを撃つ
		if shoot_range > 0.0:
			var tower = _nearest_tower(pos, shoot_range)
			if tower != null:
				_hit_facility(e, spec, tower)
				continue
			if pos.distance_to(Vector2(core_cell)) <= shoot_range:
				_hit_core(e, spec)
				continue
		# 3) 経路に沿って進む。塞がれていれば壊す。
		var next: Vector2i = _flow[cell] if _flow.has(cell) else e["entry"]
		if next == core_cell:
			_hit_core(e, spec)
			continue
		if is_blocked(next):
			_hit_facility(e, spec, next)
			continue
		var speed: float = spec["speed"]
		if e["slow"] > 0.0:
			speed *= float(B.MINIONS["succubus"]["slow"])
		var to := Vector2(next) - pos
		var step := speed * dt
		if to.length() <= step:
			e["pos"] = Vector2(next)
		else:
			e["pos"] = pos + to.normalized() * step


func _update_facilities(dt: float) -> void:
	var mult: float = float(B.SPELL["multiplier"]) if buff_time > 0.0 else 1.0
	for c in facilities:
		var f = facilities[c]
		var spec: Dictionary = B.FACILITIES[f["type"]]
		if f["type"] == "wall" or f["hp"] <= 0.0:
			continue
		f["cd"] = maxf(0.0, f["cd"] - dt)
		if f["cd"] > 0.0:
			continue
		var fpos := Vector2(c)
		if f["type"] == "trap":
			var triggered := false
			for e in enemies:
				if e["hp"] > 0.0 and fpos.distance_to(e["pos"]) < 0.45:
					e["hp"] -= float(spec["damage"])
					triggered = true
			if triggered:
				f["cd"] = float(spec["interval"])
				_add_shot(fpos, fpos, "trap")
			continue
		var target = _nearest_enemy(fpos, float(spec["range"]))
		if target == null:
			continue
		f["cd"] = float(spec["interval"])
		var dmg: float = float(spec["damage"]) * mult
		if spec.has("splash"):
			var center: Vector2 = target["pos"]
			for e in enemies:
				if e["hp"] > 0.0 and center.distance_to(e["pos"]) <= float(spec["splash"]):
					e["hp"] -= dmg
		else:
			target["hp"] -= dmg
		_add_shot(fpos, target["pos"], f["type"])


func _update_minions(dt: float) -> void:
	var mult: float = float(B.SPELL["multiplier"]) if buff_time > 0.0 else 1.0
	mult *= minion_damage_mult()
	for m in minions:
		if not m["hired"] or not m["alive"]:
			continue
		var spec: Dictionary = B.MINIONS[m["type"]]
		m["cd"] = maxf(0.0, m["cd"] - dt)
		var path: Array = m["path"]
		if not path.is_empty():
			var pos: Vector2 = m["pos"]
			var to := Vector2(path[0]) - pos
			var step: float = float(spec["speed"]) * dt
			if to.length() <= step:
				m["pos"] = Vector2(path[0])
				path.pop_front()
			else:
				m["pos"] = pos + to.normalized() * step
		if m["cd"] > 0.0:
			continue
		var target = _nearest_enemy(m["pos"], float(spec["range"]))
		if target == null:
			continue
		m["cd"] = float(spec["interval"])
		target["hp"] -= float(spec["damage"]) * mult
		if spec.has("slow_time"):
			target["slow"] = float(spec["slow_time"])
		_add_shot(m["pos"], target["pos"], m["type"])
