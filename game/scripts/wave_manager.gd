class_name WaveManager
extends Node

## wave の解禁・クリア記録と、開始前の情報（編成・方向の数）、出現計画を持つ。
## 出現セルは wave 開始時に外周から抽選し、事前の予告はしない（確定仕様）。

var selected_wave := 1
var unlocked_wave := 1
var cleared: Dictionary = {} # wave番号 -> bool

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func wave_count() -> int:
	return Balance.WAVES.size()


func wave_def(n: int) -> Dictionary:
	return Balance.WAVES[n - 1]


func is_cleared(n: int) -> bool:
	return bool(cleared.get(n, false))


func reward_for(n: int) -> int:
	var base := int(wave_def(n)["reward_funds"])
	if is_cleared(n):
		return int(round(float(base) * Balance.RETRY_REWARD_RATE))
	return base


func mark_cleared(n: int) -> void:
	cleared[n] = true
	unlocked_wave = mini(maxi(unlocked_wave, n + 1), wave_count())


## 出現計画：方向の数だけ辺を選び、各敵の出現セルをその辺の外周から抽選する。
## 戻り値は出現順のセル一覧（長さ＝敵の数）。
func make_spawn_plan(board, facilities: Dictionary, n: int) -> Array:
	var plan: Array = []
	var d := wave_def(n)
	var count := int(d["count"])
	var directions := int(d["directions"])
	var b: Rect2i = board.bounds()
	var by_side: Dictionary = {0: [], 1: [], 2: [], 3: []}
	for c in board.perimeter_cells():
		if facilities.has(c) or board.is_core(c):
			continue
		var side := 3
		if c.x == b.position.x:
			side = 0
		elif c.x == b.position.x + b.size.x - 1:
			side = 1
		elif c.y == b.position.y:
			side = 2
		by_side[side].append(c)
	var sides: Array = []
	for s in by_side.keys():
		if not by_side[s].is_empty():
			sides.append(s)
	sides.shuffle()
	var chosen: Array = sides.slice(0, mini(directions, sides.size()))
	if chosen.is_empty():
		return plan
	for i in count:
		var side: int = chosen[i % chosen.size()]
		var cells_for_side: Array = by_side[side]
		plan.append(cells_for_side[_rng.randi_range(0, cells_for_side.size() - 1)])
	plan.shuffle()
	return plan
