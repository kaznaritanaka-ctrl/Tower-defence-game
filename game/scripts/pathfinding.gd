class_name Pathfinding
extends RefCounted

## グリッド上の A* 経路探索。
## 施設のあるマスは「通行に高い代償がかかるマス」として扱う（docs/DECISIONS.md）。
## 迂回と破壊のどちらが安いかは、進入コストの比較で自然に決まる。
## avoid_blockers=true のときは施設マスを通行不可として扱う（配下の移動用）。

static func enter_cost(facilities: Dictionary, cell: Vector2i, avoid_blockers: bool) -> float:
	if facilities.has(cell):
		if avoid_blockers:
			return -1.0
		return Balance.PATH_BLOCKER_COST
	return 1.0


## start から goal への経路を返す（start を含まず goal を含む）。到達不能なら空。
static func find_path(board, facilities: Dictionary, start: Vector2i, goal: Vector2i, avoid_blockers := false) -> Array:
	var result: Array = []
	if start == goal:
		return result
	if not board.is_playable(goal):
		return result
	var open: Array = [start]
	var in_open: Dictionary = {start: true}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	var closed: Dictionary = {}
	while not open.is_empty():
		var current: Vector2i = open[0]
		var best := float(g_score[current]) + _heuristic(current, goal)
		for c in open:
			var f := float(g_score[c]) + _heuristic(c, goal)
			if f < best:
				best = f
				current = c
		if current == goal:
			var cur: Vector2i = goal
			while cur != start:
				result.push_front(cur)
				cur = came_from[cur]
			return result
		open.erase(current)
		in_open.erase(current)
		closed[current] = true
		for nb in board.neighbors4(current):
			if closed.has(nb) or not board.is_playable(nb):
				continue
			var cost := enter_cost(facilities, nb, avoid_blockers)
			if cost < 0.0:
				continue
			var tentative := float(g_score[current]) + cost
			if tentative < float(g_score.get(nb, INF)):
				g_score[nb] = tentative
				came_from[nb] = current
				if not in_open.has(nb):
					open.append(nb)
					in_open[nb] = true
	return result


static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))
