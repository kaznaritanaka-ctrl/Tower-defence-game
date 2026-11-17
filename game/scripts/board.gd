class_name Board
extends Node3D

## 盤面（正方グリッド）の状態と見た目を持つ。
## 掘削済みのマスだけを cells に持ち、周辺の岩盤は候補として都度求める。
## 採掘の指定はキュー（タップ順）に保持し、wave 終了時にまとめて反映する。

const STATE_FLOOR := 0
const STATE_CORE := 1

var cells: Dictionary = {} # Vector2i -> int（掘削済みマスのみ）
var core_cell := Vector2i.ZERO
var designated: Array = [] # 採掘指定キュー（タップ順）

var _tiles_root: Node3D
var _mat_floor: StandardMaterial3D
var _mat_rock: StandardMaterial3D
var _mat_rock_marked: StandardMaterial3D
var _mat_core: StandardMaterial3D


func _init() -> void:
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	add_child(_tiles_root)
	_mat_floor = _make_mat(Color(0.16, 0.18, 0.22))
	_mat_rock = _make_mat(Color(0.09, 0.10, 0.13))
	_mat_rock_marked = _make_mat(Color(0.38, 0.27, 0.08))
	_mat_core = _make_mat(Color(0.85, 0.55, 0.12), true)


func _make_mat(c: Color, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emission:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
	return m


func setup(size: int) -> void:
	cells.clear()
	designated.clear()
	for x in size:
		for y in size:
			cells[Vector2i(x, y)] = STATE_FLOOR
	core_cell = Vector2i(size / 2, size / 2)
	cells[core_cell] = STATE_CORE
	rebuild_visuals()


func is_playable(cell: Vector2i) -> bool:
	return cells.has(cell)


func is_core(cell: Vector2i) -> bool:
	return int(cells.get(cell, -1)) == STATE_CORE


func neighbors4(cell: Vector2i) -> Array:
	return [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
	]


func bounds() -> Rect2i:
	var min_c := Vector2i(1 << 30, 1 << 30)
	var max_c := Vector2i(-(1 << 30), -(1 << 30))
	for c in cells.keys():
		min_c.x = mini(min_c.x, c.x)
		min_c.y = mini(min_c.y, c.y)
		max_c.x = maxi(max_c.x, c.x)
		max_c.y = maxi(max_c.y, c.y)
	return Rect2i(min_c, max_c - min_c + Vector2i.ONE)


func is_rock_candidate(cell: Vector2i) -> bool:
	if cells.has(cell):
		return false
	for nb in neighbors4(cell):
		if cells.has(nb):
			return true
	return false


func rock_candidates() -> Array:
	var b := bounds()
	var out: Array = []
	for x in range(b.position.x - 1, b.position.x + b.size.x + 1):
		for y in range(b.position.y - 1, b.position.y + b.size.y + 1):
			var c := Vector2i(x, y)
			if is_rock_candidate(c):
				out.append(c)
	return out


func is_perimeter(cell: Vector2i) -> bool:
	if not cells.has(cell):
		return false
	for nb in neighbors4(cell):
		if not cells.has(nb):
			return true
	return false


func perimeter_cells() -> Array:
	var out: Array = []
	for c in cells.keys():
		if is_perimeter(c):
			out.append(c)
	return out


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x), 0.0, float(cell.y))


func world_center() -> Vector3:
	var sum := Vector3.ZERO
	for c in cells.keys():
		sum += cell_to_world(c)
	return sum / float(maxi(cells.size(), 1))


func extent() -> float:
	var b := bounds()
	return float(maxi(b.size.x, b.size.y))


## 採掘指定の切り替え。指定済みなら取り消し、候補ならキュー末尾へ追加。
func toggle_designation(cell: Vector2i) -> bool:
	if designated.has(cell):
		designated.erase(cell)
		return true
	if is_rock_candidate(cell):
		designated.append(cell)
		return true
	return false


## wave 終了時に呼ぶ。指定された岩盤を盤面へ加え、加えたマスの一覧を返す。
func apply_designated() -> Array:
	var applied: Array = []
	for c in designated:
		if is_rock_candidate(c):
			cells[c] = STATE_FLOOR
			applied.append(c)
	designated.clear()
	if not applied.is_empty():
		rebuild_visuals()
	return applied


func rebuild_visuals() -> void:
	for ch in _tiles_root.get_children():
		ch.free()
	for c in cells.keys():
		var core := is_core(c)
		var tile := _make_box(Vector3(0.98, 0.2, 0.98), _mat_core if core else _mat_floor)
		tile.position = cell_to_world(c) + Vector3(0, -0.1, 0)
		_tiles_root.add_child(tile)
		if core:
			var pillar := _make_box(Vector3(0.5, 0.9, 0.5), _mat_core)
			pillar.position = cell_to_world(c) + Vector3(0, 0.45, 0)
			_tiles_root.add_child(pillar)
	for c in rock_candidates():
		var marked := designated.has(c)
		var rock := _make_box(Vector3(0.98, 0.7, 0.98), _mat_rock_marked if marked else _mat_rock)
		rock.position = cell_to_world(c) + Vector3(0, 0.15, 0)
		_tiles_root.add_child(rock)


func _make_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return mi
