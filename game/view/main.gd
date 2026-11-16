extends Node3D
## 表示と操作。ルールは core/game.gd にあり、ここは状態を映して入力を渡すだけ。
## 見た目は仮の立体（箱・円柱・カプセル）で、アセットは未導入。

const Game = preload("res://core/game.gd")
const B = preload("res://core/balance.gd")

const CAM_PITCH := -45.0
const CAM_YAW := 45.0
const CAM_DISTANCE := 40.0
const ZOOM_MIN := 5.0
const ZOOM_MAX := 24.0
const ROCK_TOP := 0.3            # 岩盤の上面の高さ

var game
var speed := 1.0
var mode := "select"             # select / wall / arrow / mage / trap / remove / dig
var selected := -1               # 選択中の配下
var wave_sel := 0
var manage_open := false

var cam: Camera3D
var cam_target := Vector3.ZERO
var board_root: Node3D
var units_root: Node3D
var fx_mesh: ImmediateMesh
var seen_version := -1
var unit_nodes := {}
var _mats := {}

var _pressed := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _touches := {}
var _pinch_dist := 0.0

var top_label: Label
var info_label: Label
var build_box: VBoxContainer
var prep_box: VBoxContainer
var battle_box: VBoxContainer
var manage_panel: PanelContainer
var result_panel: PanelContainer
var result_label: Label
var wave_label: Label
var start_button: Button
var spell_button: Button
var speed_button: Button
var mode_buttons := {}
var hire_buttons := {}
var research_buttons := {}


func _ready() -> void:
	game = Game.new()
	_setup_world()
	_setup_ui()
	cam_target = Vector3(game.core_cell.x, 0.0, game.core_cell.y)
	_apply_camera()
	var shot := _arg("--shot=")
	if shot != "":
		_run_shot(shot)


func _process(delta: float) -> void:
	if game.phase == "battle":
		var remain := delta * speed
		while remain > 0.0:
			var step := minf(remain, 0.05)
			game.tick(step)
			remain -= step
	if seen_version != game.board_version:
		_rebuild_board()
		seen_version = game.board_version
	_sync_units()
	_draw_shots()
	_refresh_ui()


# ---------------------------------------------------------------- 世界

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.78)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -20.0, 0.0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.93, 0.8)
	add_child(sun)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.5
	cam.near = 0.1
	cam.far = 200.0
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	add_child(cam)
	cam.current = true

	board_root = Node3D.new()
	add_child(board_root)
	units_root = Node3D.new()
	add_child(units_root)

	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	fx_mesh = ImmediateMesh.new()
	var fx := MeshInstance3D.new()
	fx.mesh = fx_mesh
	fx.material_override = line_mat
	add_child(fx)


func _apply_camera() -> void:
	cam.position = cam_target + cam.basis.z * CAM_DISTANCE


func _mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := color.to_html() + str(emission)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	return c


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	return c


func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s


func _rebuild_board() -> void:
	for child in board_root.get_children():
		child.queue_free()
	var amber := Color(0.95, 0.62, 0.15)
	for c in game.floor_cells:
		var shade := 0.0 if posmod(c.x + c.y, 2) == 0 else 0.03
		_add_mesh(board_root, _box(Vector3(0.97, 0.2, 0.97)), Vector3(c.x, -0.1, c.y),
				_mat(Color(0.25 + shade, 0.29 + shade, 0.36 + shade)))
	for c in game.rock_cells():
		var rock_mat := _mat(Color(0.13, 0.15, 0.2))
		if game.dig_marks.has(c):
			rock_mat = _mat(Color(0.75, 0.48, 0.14), 0.5)
		_add_mesh(board_root, _box(Vector3(0.97, ROCK_TOP + 0.2, 0.97)), Vector3(c.x, (ROCK_TOP - 0.2) * 0.5, c.y), rock_mat)

	var core := Vector3(game.core_cell.x, 0.0, game.core_cell.y)
	_add_mesh(board_root, _cyl(0.42, 0.46, 0.5), core + Vector3(0, 0.25, 0), _mat(Color(0.3, 0.33, 0.4)))
	_add_mesh(board_root, _sphere(0.3), core + Vector3(0, 0.75, 0), _mat(amber, 1.6))

	for c in game.facilities:
		var f = game.facilities[c]
		var p := Vector3(c.x, 0.0, c.y)
		var type: String = f["type"]
		if f["hp"] <= 0.0 and B.FACILITIES[type]["block"]:
			_add_mesh(board_root, _box(Vector3(0.8, 0.12, 0.8)), p + Vector3(0, 0.06, 0), _mat(Color(0.2, 0.2, 0.22)))
			continue
		match type:
			"wall":
				_add_mesh(board_root, _box(Vector3(0.92, 0.8, 0.92)), p + Vector3(0, 0.4, 0), _mat(Color(0.42, 0.45, 0.52)))
			"arrow":
				_add_mesh(board_root, _cyl(0.3, 0.38, 1.0), p + Vector3(0, 0.5, 0), _mat(Color(0.45, 0.32, 0.2)))
				_add_mesh(board_root, _sphere(0.17), p + Vector3(0, 1.17, 0), _mat(Color(0.35, 0.72, 0.42)))
			"mage":
				_add_mesh(board_root, _cyl(0.26, 0.36, 1.1), p + Vector3(0, 0.55, 0), _mat(Color(0.33, 0.3, 0.48)))
				_add_mesh(board_root, _sphere(0.19), p + Vector3(0, 1.3, 0), _mat(amber, 1.2))
			"trap":
				_add_mesh(board_root, _box(Vector3(0.72, 0.06, 0.72)), p + Vector3(0, 0.03, 0), _mat(Color(0.55, 0.2, 0.2)))
				_add_mesh(board_root, _box(Vector3(0.12, 0.2, 0.12)), p + Vector3(0, 0.12, 0), _mat(Color(0.7, 0.7, 0.75)))


# ---------------------------------------------------------------- ユニット

func _make_unit(kind: String) -> Node3D:
	var n := Node3D.new()
	units_root.add_child(n)
	var bar_y := 1.05
	var bar_color := Color(0.85, 0.25, 0.2)
	match kind:
		"soldier":
			_add_mesh(n, _capsule(0.2, 0.7), Vector3(0, 0.35, 0), _mat(Color(0.56, 0.63, 0.76)))
			_add_mesh(n, _box(Vector3(0.3, 0.3, 0.06)), Vector3(0.14, 0.38, 0.16), _mat(Color(0.3, 0.36, 0.55)))
		"archer":
			_add_mesh(n, _capsule(0.17, 0.66), Vector3(0, 0.33, 0), _mat(Color(0.42, 0.62, 0.36)))
			_add_mesh(n, _box(Vector3(0.04, 0.5, 0.04)), Vector3(0.2, 0.4, 0.1), _mat(Color(0.5, 0.36, 0.2)))
		"demon":
			var red := _mat(Color(0.52, 0.12, 0.12))
			_add_mesh(n, _capsule(0.3, 1.0), Vector3(0, 0.5, 0), red)
			for side in [-1.0, 1.0]:
				_add_mesh(n, _box(Vector3(0.07, 0.24, 0.07)), Vector3(0.14 * side, 1.08, 0), _mat(Color(0.85, 0.8, 0.7)))
				_add_mesh(n, _box(Vector3(0.12, 0.4, 0.12)), Vector3(0.4 * side, 0.68, 0), red)
				_add_mesh(n, _box(Vector3(0.12, 0.4, 0.12)), Vector3(0.4 * side, 0.36, 0.1), red)
			bar_y = 1.45
			bar_color = Color(0.3, 0.8, 0.4)
		"succubus":
			var purple := _mat(Color(0.64, 0.26, 0.6))
			_add_mesh(n, _capsule(0.19, 0.78), Vector3(0, 0.39, 0), purple)
			for side in [-1.0, 1.0]:
				_add_mesh(n, _box(Vector3(0.3, 0.26, 0.03)), Vector3(0.26 * side, 0.6, -0.1), _mat(Color(0.3, 0.1, 0.32)))
			bar_y = 1.15
			bar_color = Color(0.3, 0.8, 0.4)
		"facility":
			bar_y = 1.55
			bar_color = Color(0.95, 0.75, 0.2)

	var bar := Node3D.new()
	bar.name = "Bar"
	bar.position = Vector3(0, bar_y, 0)
	bar.rotation_degrees = Vector3(0, CAM_YAW, 0)
	n.add_child(bar)
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.albedo_color = Color(0.05, 0.05, 0.07)
	_add_mesh(bar, _box(Vector3(0.64, 0.1, 0.02)), Vector3.ZERO, flat)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = bar_color
	var fill := _add_mesh(bar, _box(Vector3(0.6, 0.07, 0.04)), Vector3.ZERO, fill_mat)
	fill.name = "Fill"

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.34
	ring_mesh.outer_radius = 0.42
	var ring := _add_mesh(n, ring_mesh, Vector3(0, 0.04, 0), _mat(Color(0.95, 0.62, 0.15), 1.5))
	ring.name = "Ring"
	ring.visible = false
	return n


func _update_unit(key: String, kind: String, pos: Vector3, ratio: float, ring: bool, seen: Dictionary) -> void:
	seen[key] = true
	var n: Node3D = unit_nodes.get(key)
	if n == null:
		n = _make_unit(kind)
		unit_nodes[key] = n
	n.position = pos
	var bar: Node3D = n.get_node("Bar")
	bar.visible = ratio < 0.999
	var fill: MeshInstance3D = bar.get_node("Fill")
	var r := clampf(ratio, 0.02, 1.0)
	fill.scale.x = r
	fill.position.x = -0.3 * (1.0 - r)
	(n.get_node("Ring") as MeshInstance3D).visible = ring


func _sync_units() -> void:
	var seen := {}
	for e in game.enemies:
		var p: Vector2 = e["pos"]
		# 盤面の外にいる間は岩盤の上を歩かせる。
		var height := 0.0 if game.is_floor(Vector2i(p.round())) else ROCK_TOP
		_update_unit("e%d" % e["id"], e["type"], Vector3(p.x, height, p.y), e["hp"] / e["max_hp"], false, seen)
	for i in game.minions.size():
		var m = game.minions[i]
		if not m["hired"] or not m["alive"]:
			continue
		var p: Vector2 = m["pos"]
		var full: float = B.MINIONS[m["type"]]["hp"]
		_update_unit("m%d" % i, m["type"], Vector3(p.x, 0, p.y), m["hp"] / full, i == selected, seen)
	for c in game.facilities:
		var f = game.facilities[c]
		var full: float = B.FACILITIES[f["type"]]["hp"]
		if B.FACILITIES[f["type"]]["block"] and f["hp"] > 0.0 and f["hp"] < full:
			_update_unit("f%d_%d" % [c.x, c.y], "facility", Vector3(c.x, 0, c.y), f["hp"] / full, false, seen)
	var core_full: float = B.CORE["hp"]
	if game.core_hp < core_full:
		_update_unit("core", "facility", Vector3(game.core_cell.x, 0, game.core_cell.y), game.core_hp / core_full, false, seen)
	for key in unit_nodes.keys():
		if not seen.has(key):
			unit_nodes[key].queue_free()
			unit_nodes.erase(key)


func _draw_shots() -> void:
	fx_mesh.clear_surfaces()
	if game.shots.is_empty():
		return
	fx_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for s in game.shots:
		var col := Color(1.0, 0.85, 0.4)
		match s["kind"]:
			"enemy":
				col = Color(1.0, 0.35, 0.3)
			"mage", "succubus":
				col = Color(0.85, 0.5, 1.0)
		var a: Vector2 = s["from"]
		var b: Vector2 = s["to"]
		fx_mesh.surface_set_color(col)
		fx_mesh.surface_add_vertex(Vector3(a.x, 0.8, a.y))
		fx_mesh.surface_set_color(col)
		fx_mesh.surface_add_vertex(Vector3(b.x, 0.4, b.y))
	fx_mesh.surface_end()


# ---------------------------------------------------------------- 入力

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_pinch_dist = _touch_distance()
			_dragging = true
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var d := _touch_distance()
			if _pinch_dist > 0.0 and d > 0.0:
				cam.size = clampf(cam.size * _pinch_dist / d, ZOOM_MIN, ZOOM_MAX)
			_pinch_dist = d
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam.size = clampf(cam.size * 0.9, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam.size = clampf(cam.size * 1.1, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_press_pos = event.position
			else:
				if _pressed and not _dragging:
					_tap(event.position)
				_pressed = false
	elif event is InputEventMouseMotion and _pressed:
		if _touches.size() >= 2:
			return
		if not _dragging and event.position.distance_to(_press_pos) > 10.0:
			_dragging = true
		if _dragging:
			_pan(event.relative)


func _touch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _pan(rel: Vector2) -> void:
	var per_pixel := cam.size / _view_size().y
	var right := cam.basis.x
	var forward := -cam.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# 斜めから見ているので、奥行き方向は画面上で縮んで見える。その分を補う。
	var depth := 1.0 / sin(deg_to_rad(-CAM_PITCH))
	cam_target += (-right * rel.x + forward * rel.y * depth) * per_pixel
	_apply_camera()


## 画面上の点が指す地面（高さ0）の位置。x と y がマスの座標になる。
func _ground_point(p: Vector2) -> Vector2:
	var size := _view_size()
	var half_h := cam.size * 0.5
	var half_w := half_h * size.x / size.y
	var origin := cam.position
	origin += cam.basis.x * ((p.x / size.x) * 2.0 - 1.0) * half_w
	origin += cam.basis.y * (1.0 - (p.y / size.y) * 2.0) * half_h
	var dir := -cam.basis.z
	var t := -origin.y / dir.y
	var hit := origin + dir * t
	return Vector2(hit.x, hit.z)


## 地面や空中の点が画面上のどこに映るか。
func _screen_point(world: Vector3) -> Vector2:
	var size := _view_size()
	var half_h := cam.size * 0.5
	var half_w := half_h * size.x / size.y
	var rel := world - cam.position
	return Vector2(
		(rel.dot(cam.basis.x) / half_w + 1.0) * 0.5 * size.x,
		(1.0 - rel.dot(cam.basis.y) / half_h) * 0.5 * size.y)


func _minion_at(p: Vector2) -> int:
	var best := -1
	var best_d := 44.0
	for i in game.minions.size():
		var m = game.minions[i]
		if not m["hired"] or not m["alive"]:
			continue
		var pos: Vector2 = m["pos"]
		var d := _screen_point(Vector3(pos.x, 0.45, pos.y)).distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _tap(p: Vector2) -> void:
	if game.phase == "result":
		return
	var hit := _ground_point(p)
	var cell := Vector2i(roundi(hit.x), roundi(hit.y))
	if game.phase == "battle" or mode == "select":
		var mi := _minion_at(p)
		if mi >= 0:
			selected = -1 if mi == selected else mi
		elif selected >= 0:
			game.move_minion(selected, cell)
		return
	match mode:
		"remove":
			game.remove(cell)
		"dig":
			game.toggle_dig(cell)
		_:
			game.place(mode, cell)


# ---------------------------------------------------------------- UI

func _button(text: String, on_press: Callable, width: float = 170.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 46.0)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b


func _corner_box(preset: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preset == Control.PRESET_BOTTOM_RIGHT:
		box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	return box


func _center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.11, 0.96)
	style.border_color = Color(0.95, 0.62, 0.15, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	return panel


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Yu Gothic UI", "Meiryo", "Noto Sans CJK JP", "Noto Sans JP", "Hiragino Sans", "sans-serif",
	])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	root.theme = theme
	layer.add_child(root)

	# 状況表示は上側にまとめる。
	top_label = Label.new()
	info_label = Label.new()
	for label in [top_label, info_label]:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(label)
	top_label.position = Vector2(14, 8)
	info_label.position = Vector2(14, 38)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))

	# 準備中：左下に設置・採掘、右下に wave の選択と開始。
	build_box = _corner_box(Control.PRESET_BOTTOM_LEFT)
	root.add_child(build_box)
	var group := ButtonGroup.new()
	var modes := [["select", "配下を動かす"], ["wall", ""], ["arrow", ""], ["mage", ""], ["trap", ""], ["remove", "撤去（全額返還）"], ["dig", "採掘先を指定"]]
	for entry in modes:
		var key: String = entry[0]
		var text: String = entry[1]
		if B.FACILITIES.has(key):
			var spec: Dictionary = B.FACILITIES[key]
			text = "%s  資材%d" % [spec["name"], spec["materials"]]
			if int(spec["funds"]) > 0:
				text += " 資金%d" % spec["funds"]
		var b := _button(text, func(): mode = key, 210.0)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = key == mode
		build_box.add_child(b)
		mode_buttons[key] = b

	prep_box = _corner_box(Control.PRESET_BOTTOM_RIGHT)
	root.add_child(prep_box)
	prep_box.add_child(_button("研究・雇用", func(): manage_open = not manage_open, 230.0))
	var wave_row := HBoxContainer.new()
	wave_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_row.add_child(_button("◀", func(): wave_sel = maxi(0, wave_sel - 1), 52.0))
	wave_label = Label.new()
	wave_label.custom_minimum_size = Vector2(118, 0)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_row.add_child(wave_label)
	wave_row.add_child(_button("▶", func(): wave_sel = mini(game.unlocked - 1, wave_sel + 1), 52.0))
	prep_box.add_child(wave_row)
	start_button = _button("襲撃を迎え撃つ", _on_start, 230.0)
	prep_box.add_child(start_button)

	# 戦闘中：右下に全体魔法と速度。
	battle_box = _corner_box(Control.PRESET_BOTTOM_RIGHT)
	root.add_child(battle_box)
	speed_button = _button("速度 ×1", _on_speed, 230.0)
	battle_box.add_child(speed_button)
	spell_button = _button("", func(): game.cast_spell(), 230.0)
	battle_box.add_child(spell_button)

	# 研究・雇用（完成版では研究画面と武器防具画面に分ける）。
	manage_panel = _center_panel()
	root.add_child(manage_panel)
	var manage_box := VBoxContainer.new()
	manage_box.add_theme_constant_override("separation", 6)
	manage_panel.add_child(manage_box)
	for type in B.MINIONS:
		var b := _button("", func(): game.hire(type), 420.0)
		manage_box.add_child(b)
		hire_buttons[type] = b
	for key in B.RESEARCH:
		var b := _button("", func(): game.do_research(key), 420.0)
		manage_box.add_child(b)
		research_buttons[key] = b
	manage_box.add_child(_button("閉じる", func(): manage_open = false, 420.0))

	# 結果
	result_panel = _center_panel()
	root.add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 10)
	result_panel.add_child(result_box)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.custom_minimum_size = Vector2(420, 0)
	result_box.add_child(result_label)
	result_box.add_child(_button("準備に戻る", _on_result_ok, 420.0))

	build_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	prep_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	battle_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	manage_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _on_start() -> void:
	manage_open = false
	if game.start_wave(wave_sel):
		selected = -1


func _on_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0


func _on_result_ok() -> void:
	var result: Dictionary = game.last_result
	game.confirm_result()
	# 勝ったら次の wave を選んだ状態にする。
	if result.get("win", false):
		wave_sel = mini(game.unlocked - 1, int(result["wave"]) + 1)
	mode = "select"
	(mode_buttons["select"] as Button).button_pressed = true


func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	if float(cost.get("mana", 0.0)) > 0.0:
		parts.append("魔力%d" % int(cost["mana"]))
	if int(cost.get("funds", 0)) > 0:
		parts.append("資金%d" % int(cost["funds"]))
	if int(cost.get("materials", 0)) > 0:
		parts.append("資材%d" % int(cost["materials"]))
	return " ".join(parts)


func _wave_text(i: int) -> String:
	var info: Dictionary = game.wave_info(i)
	var parts: Array = []
	for type in info["counts"]:
		parts.append("%s%d" % [B.ENEMIES[type]["name"], info["counts"][type]])
	var text := "Wave %d：%s／%d方向から／報酬 資金%d" % [i + 1, "・".join(parts), info["directions"], info["reward"]]
	if info["replay"]:
		text += "（再挑戦）"
	return text


func _refresh_ui() -> void:
	var prep: bool = game.phase == "prep"
	var battle: bool = game.phase == "battle"
	var shown_wave: int = wave_sel if prep else game.wave_index
	var phase_name: String = {"prep": "準備", "battle": "戦闘", "result": "結果"}[game.phase]
	top_label.text = "ダンジョンLv1  Wave %d/%d  %s     魔力 %d/%d   資材 %d   資金 %d     コア %d/%d" % [
		shown_wave + 1, game.wave_count(), phase_name,
		int(game.mana), int(game.mana_cap()), game.materials, game.funds,
		int(ceil(game.core_hp)), int(B.CORE["hp"]),
	]
	build_box.visible = prep
	prep_box.visible = prep
	battle_box.visible = battle
	manage_panel.visible = prep and manage_open
	result_panel.visible = game.phase == "result"

	if prep:
		wave_sel = clampi(wave_sel, 0, game.unlocked - 1)
		wave_label.text = "Wave %d" % (wave_sel + 1)
		var hint := ""
		match mode:
			"select":
				hint = "配下をタップして選び、持ち場にするマスをタップ"
			"remove":
				hint = "撤去する設備をタップ"
			"dig":
				hint = "周辺の岩盤をタップして採掘先を指定（あと%dマス）。wave 終了時に盤面が広がる" % (int(B.DIG["per_wave"]) - game.dig_marks.size())
			_:
				hint = "%sを置くマスをタップ" % B.FACILITIES[mode]["name"]
		info_label.text = _wave_text(wave_sel) + "\n" + hint
		for type in hire_buttons:
			var spec: Dictionary = B.MINIONS[type]
			var hired := false
			for m in game.minions:
				if m["type"] == type and m["hired"]:
					hired = true
			var b: Button = hire_buttons[type]
			b.text = "%s：雇用済み" % spec["name"] if hired else "%s を雇用  資金%d" % [spec["name"], spec["hire"]]
			b.disabled = hired or game.funds < int(spec["hire"])
		for key in research_buttons:
			var spec: Dictionary = B.RESEARCH[key]
			var lv: int = game.research[key]
			var b: Button = research_buttons[key]
			if lv >= int(spec["max"]):
				b.text = "%s｜%s 段階%d（最大）" % [spec["kind"], spec["name"], lv]
				b.disabled = true
			else:
				b.text = "%s｜%s 段階%d→%d  %s" % [spec["kind"], spec["name"], lv, lv + 1, _cost_text(spec)]
				b.disabled = not game.can_afford(spec)
	elif battle:
		var waiting: int = game.spawn_queue.size()
		var text := "敵 %d（これから現れる数 %d）" % [game.enemies.size(), waiting]
		if game.buff_time > 0.0:
			text += "     攻撃力アップ 残り%.1f秒" % game.buff_time
		text += "\n配下をタップして選び、行き先のマスをタップ"
		info_label.text = text
		spell_button.text = "%s  魔力%d" % [B.SPELL["name"], int(B.SPELL["mana"])]
		spell_button.disabled = game.mana < float(B.SPELL["mana"])
		speed_button.text = "速度 ×%d" % int(speed)
	else:
		info_label.text = ""
		var r: Dictionary = game.last_result
		var lines: Array = []
		if r["win"]:
			lines.append("Wave %d　勝利" % (int(r["wave"]) + 1))
			lines.append("報酬　資金 +%d%s" % [r["reward"], "" if r["first"] else "（再挑戦のため減額）"])
		else:
			lines.append("Wave %d　失敗" % (int(r["wave"]) + 1))
			lines.append("ダンジョンコアが破壊された。失うものはなく、再挑戦できる")
		if int(r["dug"]) > 0:
			lines.append("採掘　資材 +%d／盤面が%dマス広がった" % [r["materials"], r["dug"]])
		if r["final"]:
			lines.append("ダンジョンLv1 の最後の wave をクリア（Lv2 は未実装）")
		result_label.text = "\n".join(lines)


# ---------------------------------------------------------------- 開発用

func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


## 開発用：決まった状況を作って画面を画像に保存する。
##   godot --path game -- --shot=out.png --scene=battle
func _run_shot(path: String) -> void:
	var scene := _arg("--scene=")
	game = Game.new(7)
	game.materials = 400
	game.funds = 400
	game.place("arrow", Vector2i(3, 1))
	game.place("mage", Vector2i(5, 3))
	game.place("trap", Vector2i(1, 3))
	for c in [Vector2i(2, 2), Vector2i(2, 4), Vector2i(4, 2)]:
		game.place("wall", c)
	game.hire("demon")
	game.hire("succubus")
	game.toggle_dig(Vector2i(3, -1))
	game.toggle_dig(Vector2i(7, 4))
	selected = 0
	if scene == "manage":
		manage_open = true
	if scene == "battle" or scene == "result":
		game.unlocked = 3
		game.start_wave(2)
		game.mana = 40.0
		game.cast_spell()
		var steps := 150 if scene == "battle" else 4000
		for i in steps:
			game.tick(0.05)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
