extends Node3D

## wave 構造試作の本体。準備 → 戦闘 → 結果の1サイクルを回す。
## 数値はすべて scripts/balance.gd の試作仮値を参照する（確定仕様ではない）。
## 画面はスマホ横画面を前提に、状況表示と操作を上側へまとめ、下部の帯は置かない。

enum Phase { PREP, COMBAT }

var board: Board
var mana: ManaSystem
var economy: Economy
var magic: GlobalMagic
var waves: WaveManager

var phase: int = Phase.PREP
var facilities: Dictionary = {} # Vector2i -> Facility（生存中のみ）
var destroyed_facilities: Array = [] # wave 終了後の復旧待ち
var minions: Array = []
var enemies: Array = []
var core_hp := 0.0
var last_wave_won := false
var current_wave := 0

var spawn_queue: Array = [] # 出現待ちのセル一覧
var spawn_timer := 0.0
var spawn_hp_mult := 1.0

var build_kind := "wall"
var remove_mode := false
var selected_minion = null

var entities_root: Node3D
var camera: Camera3D

var status_label: Label
var message_label: Label
var info_label: Label
var magic_button: Button
var start_button: Button
var wave_buttons: Array = []
var build_buttons: Dictionary = {}
var remove_button: Button


func _ready() -> void:
	mana = ManaSystem.new()
	add_child(mana)
	mana.setup()
	economy = Economy.new()
	add_child(economy)
	economy.setup()
	magic = GlobalMagic.new()
	add_child(magic)
	waves = WaveManager.new()
	add_child(waves)
	board = Board.new()
	add_child(board)
	board.setup(Balance.BOARD_INITIAL_SIZE)
	entities_root = Node3D.new()
	entities_root.name = "Entities"
	add_child(entities_root)
	core_hp = Balance.CORE_HP
	_setup_camera_and_light()
	_spawn_initial_minions()
	_build_ui()
	_center_camera()
	update_ui()
	message_label.text = "準備：施設を置き、周辺の岩盤をタップして採掘先を指定してください。"


func _process(delta: float) -> void:
	tick(delta)


func is_prep() -> bool:
	return phase == Phase.PREP


func is_combat() -> bool:
	return phase == Phase.COMBAT


## ロジックの1ステップ。実機では _process から、検証ではテストから直接呼ばれる。
func tick(dt: float) -> void:
	for f in facilities.values():
		if f is KoboldMine:
			f.animate(dt)
	if phase != Phase.COMBAT:
		return
	mana.tick(dt, true)
	magic.tick(dt)
	_spawn_tick(dt)
	for f in facilities.values():
		if f.alive:
			f.tick(dt, self)
	for m in minions:
		if m.alive:
			m.tick(dt, self)
	for e in enemies:
		if e.alive:
			e.tick(dt, self)
	_sweep()
	if core_hp <= 0.0:
		end_wave(false)
		return
	if spawn_queue.is_empty() and enemies.is_empty():
		end_wave(true)
		return
	update_ui()


func _sweep() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if not enemies[i].alive:
			enemies[i].queue_free()
			enemies.remove_at(i)
	for cell in facilities.keys().duplicate():
		var f = facilities[cell]
		if not f.alive:
			facilities.erase(cell)
			destroyed_facilities.append(f)
			f.visible = false


func _spawn_tick(dt: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_timer -= dt
	while spawn_timer <= 0.0 and not spawn_queue.is_empty():
		var cell: Vector2i = spawn_queue.pop_front()
		var e := Enemy.new()
		entities_root.add_child(e)
		e.setup(board.cell_to_world(cell), Balance.ENEMY_HP * spawn_hp_mult)
		e.spawn_cell = cell
		enemies.append(e)
		spawn_timer += Balance.SPAWN_INTERVAL
	if spawn_queue.is_empty():
		spawn_timer = 0.0


func damage_core(amount: float) -> void:
	core_hp = maxf(core_hp - amount, 0.0)


func facility_at(cell: Vector2i):
	return facilities.get(cell, null)


# ---- 準備フェーズの操作 ----

func place_facility(kind: String, cell: Vector2i) -> bool:
	if phase != Phase.PREP:
		return false
	if not board.is_playable(cell) or board.is_core(cell) or facilities.has(cell):
		return false
	for m in minions:
		if m.current_cell() == cell:
			return false
	var d: Dictionary = Balance.FACILITIES[kind]
	if not economy.spend(int(d["cost_materials"]), int(d["cost_funds"])):
		return false
	var f: Facility
	if kind == "mine":
		f = KoboldMine.new()
	else:
		f = Facility.new()
	entities_root.add_child(f)
	f.setup(kind, cell, board.cell_to_world(cell))
	facilities[cell] = f
	update_ui()
	return true


func remove_facility(cell: Vector2i) -> bool:
	if phase != Phase.PREP:
		return false
	var f = facilities.get(cell, null)
	if f == null:
		return false
	var d: Dictionary = Balance.FACILITIES[f.kind]
	economy.refund(int(d["cost_materials"]), int(d["cost_funds"]))
	facilities.erase(cell)
	f.queue_free()
	update_ui()
	return true


## 採掘先の指定（準備中のみ。タップ順キュー、再タップで取消：2026-11-18決定）。
func toggle_mining(cell: Vector2i) -> bool:
	if phase != Phase.PREP:
		return false
	if board.toggle_designation(cell):
		board.rebuild_visuals()
		update_ui()
		return true
	return false


func order_minion(m, cell: Vector2i) -> void:
	if m == null or not m.alive:
		return
	if not board.is_playable(cell) or facilities.has(cell):
		return
	m.order_move(board, facilities, cell)
	if phase == Phase.PREP:
		m.home_cell = cell


# ---- 戦闘フェーズ ----

func start_wave(n: int) -> bool:
	if phase != Phase.PREP:
		return false
	if n < 1 or n > waves.unlocked_wave or n > waves.wave_count():
		return false
	var plan := waves.make_spawn_plan(board, facilities, n)
	if plan.is_empty():
		return false
	current_wave = n
	waves.selected_wave = n
	spawn_queue = plan
	spawn_timer = 0.0
	spawn_hp_mult = float(waves.wave_def(n)["hp_multiplier"])
	core_hp = Balance.CORE_HP
	phase = Phase.COMBAT
	message_label.text = "wave %d 開始。出現位置は開始時に抽選されました。" % n
	update_ui()
	return true


func cast_global_magic() -> bool:
	if phase != Phase.COMBAT:
		return false
	var ok := magic.activate(mana)
	if ok:
		message_label.text = "全体魔法：施設と配下の攻撃力が上がっています。"
		update_ui()
	return ok


func end_wave(won: bool) -> void:
	last_wave_won = won
	# 採掘分は勝敗にかかわらず wave 終了時に反映する（盤面拡張＋資材）
	var applied := board.apply_designated()
	if not applied.is_empty():
		economy.add_materials(applied.size() * Balance.MATERIALS_PER_MINED_CELL)
		_center_camera()
	var reward := 0
	if won:
		reward = waves.reward_for(current_wave)
		economy.add_funds(reward)
		waves.mark_cleared(current_wave)
	for e in enemies:
		e.queue_free()
	enemies.clear()
	spawn_queue.clear()
	# 壊れた施設と倒れた配下は復帰する。恒久的な損失はない
	for f in destroyed_facilities:
		f.restore()
		facilities[f.cell] = f
	destroyed_facilities.clear()
	for f in facilities.values():
		f.hp = f.max_hp
	for m in minions:
		m.restore(board)
	selected_minion = null
	core_hp = Balance.CORE_HP
	phase = Phase.PREP
	if won:
		message_label.text = "wave %d クリア。資金 +%d を獲得しました。" % [current_wave, reward]
	else:
		message_label.text = "コアが破壊されました。同じ wave に再挑戦できます（損失はありません）。"
	if not applied.is_empty():
		message_label.text += " 採掘した %d マスが盤面に加わり、資材 +%d。" % [
			applied.size(), applied.size() * Balance.MATERIALS_PER_MINED_CELL
		]
	update_ui()


# ---- 入力 ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var origin := camera.project_ray_origin(mb.position)
			var dir := camera.project_ray_normal(mb.position)
			if absf(dir.y) < 0.0001:
				return
			var t := -origin.y / dir.y
			if t < 0.0:
				return
			var point := origin + dir * t
			var cell := Vector2i(roundi(point.x), roundi(point.z))
			_handle_tap(cell, point)


func _handle_tap(cell: Vector2i, point: Vector3) -> void:
	var tapped_minion = null
	var bd := 0.7
	for m in minions:
		if not m.alive:
			continue
		var d := Vector2(m.position.x, m.position.z).distance_to(Vector2(point.x, point.z))
		if d < bd:
			bd = d
			tapped_minion = m
	if tapped_minion != null:
		selected_minion = tapped_minion
		message_label.text = "%s を選択しました。行き先をタップしてください。" % tapped_minion.label()
		return
	if phase == Phase.PREP:
		if remove_mode:
			if remove_facility(cell):
				message_label.text = "撤去しました（全額返還）。"
			return
		if facilities.has(cell):
			# 名称はタップした対象だけ表示する（常時ラベルは置かない）
			message_label.text = facilities[cell].label()
			return
		if board.is_playable(cell) and not board.is_core(cell):
			if selected_minion != null:
				order_minion(selected_minion, cell)
			else:
				place_facility(build_kind, cell)
			return
		if board.is_rock_candidate(cell) or board.designated.has(cell):
			toggle_mining(cell)
			return
	else:
		if selected_minion != null and board.is_playable(cell):
			order_minion(selected_minion, cell)


# ---- 見た目と UI ----

func _setup_camera_and_light() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.42, 0.52)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -28, 0)
	light.light_energy = 1.15
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)


func _center_camera() -> void:
	var center := board.world_center()
	camera.position = center + Vector3(0, 17.0, 10.5)
	camera.look_at(center, Vector3.UP)
	camera.size = board.extent() * 1.30 + 3.0


func _spawn_initial_minions() -> void:
	var core := board.core_cell
	_add_minion("demon", core + Vector2i(1, 0))
	_add_minion("succubus", core + Vector2i(-1, 0))


func _add_minion(species: String, cell: Vector2i) -> void:
	var m := Minion.new()
	entities_root.add_child(m)
	m.setup(species, board, cell)
	minions.append(m)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_top = 8
	top.offset_right = -10
	layer.add_child(top)
	status_label = Label.new()
	top.add_child(status_label)
	info_label = Label.new()
	top.add_child(info_label)
	message_label = Label.new()
	top.add_child(message_label)
	var row := HBoxContainer.new()
	top.add_child(row)
	for i in waves.wave_count():
		var b := Button.new()
		b.text = "Wave %d" % (i + 1)
		var n := i + 1
		b.pressed.connect(func() -> void:
			waves.selected_wave = n
			update_ui()
		)
		row.add_child(b)
		wave_buttons.append(b)
	start_button = Button.new()
	start_button.text = "襲撃開始"
	start_button.pressed.connect(func() -> void: start_wave(waves.selected_wave))
	row.add_child(start_button)
	magic_button = Button.new()
	magic_button.text = "全体魔法：攻撃力アップ（魔力 %d）" % int(Balance.BUFF_COST)
	magic_button.pressed.connect(func() -> void: cast_global_magic())
	row.add_child(magic_button)
	var build_row := HBoxContainer.new()
	top.add_child(build_row)
	for kind in ["wall", "archer", "mage", "mine"]:
		var b := Button.new()
		b.text = String(Balance.FACILITIES[kind]["label"])
		b.toggle_mode = true
		var k: String = kind
		b.pressed.connect(func() -> void:
			build_kind = k
			remove_mode = false
			update_ui()
		)
		build_row.add_child(b)
		build_buttons[kind] = b
	remove_button = Button.new()
	remove_button.text = "撤去"
	remove_button.toggle_mode = true
	remove_button.pressed.connect(func() -> void:
		remove_mode = remove_button.button_pressed
		update_ui()
	)
	build_row.add_child(remove_button)


func update_ui() -> void:
	if status_label == null:
		return
	var phase_text := "準備中" if phase == Phase.PREP else "戦闘中"
	status_label.text = "ダンジョンLv1 / Wave %d（全%d） / %s / 魔力 %d/%d / 資金 %d / 資材 %d / コア %d" % [
		waves.selected_wave, waves.wave_count(), phase_text,
		int(mana.mana), int(mana.cap), economy.funds, economy.materials, int(core_hp),
	]
	if phase == Phase.PREP:
		var d := waves.wave_def(waves.selected_wave)
		var cleared_text := "（クリア済み：再挑戦は報酬減額）" if waves.is_cleared(waves.selected_wave) else ""
		info_label.text = "次の襲撃：侵入者 ×%d / %d方向から %s / 採掘指定 %d件" % [
			int(d["count"]), int(d["directions"]), cleared_text, board.designated.size(),
		]
	else:
		var alive_count := 0
		for e in enemies:
			if e.alive:
				alive_count += 1
		var buff_text := ("発動中（残り %.0f 秒）" % magic.remaining) if magic.is_active() else "未発動"
		info_label.text = "戦闘中：出現待ち %d / 交戦中 %d / 全体魔法 %s" % [
			spawn_queue.size(), alive_count, buff_text,
		]
	start_button.visible = phase == Phase.PREP
	magic_button.visible = phase == Phase.COMBAT
	magic_button.disabled = magic.is_active() or mana.mana < Balance.BUFF_COST
	for i in wave_buttons.size():
		wave_buttons[i].disabled = (i + 1) > waves.unlocked_wave
	for kind in build_buttons.keys():
		build_buttons[kind].button_pressed = (build_kind == kind and not remove_mode)
