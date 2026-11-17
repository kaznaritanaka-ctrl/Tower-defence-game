extends SceneTree

## ロジックのスモークテスト（ヘッドレス実行専用）。
## 実行： Godot --headless --path game --script <game/tests/smoke_test.gd の絶対パス>
## Main の tick を手動で進め、実時間に依存せず検証する。各チェックは PASS/FAIL を出す。

var failures: Array = []
var passes := 0
var _started := false


func check(name: String, cond: bool) -> void:
	if cond:
		passes += 1
		print("PASS: ", name)
	else:
		failures.append(name)
		print("FAIL: ", name)


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)


## 本体は最初のフレームで _ready が済んでから走らせる（_initialize 時点では未初期化）。
func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	_run()
	quit(1 if not failures.is_empty() else 0)
	return true


func _run() -> void:
	var main = root.get_child(0)

	var board = main.board
	var core: Vector2i = board.core_cell

	# 初期状態
	check("初期フェーズは準備", main.is_prep())
	check("盤面は7x7", board.cells.size() == 49)

	# 配下をコア周囲から退避させる（後の防壁テストと干渉させない）
	var demon = null
	var succ = null
	for mn in main.minions:
		if mn.species == "demon":
			demon = mn
		elif mn.species == "succubus":
			succ = mn
	demon.place_at(board, Vector2i(0, 0))
	succ.place_at(board, Vector2i(6, 6))

	# 採掘指定（準備中・タップ順キュー）
	var cand: Array = board.rock_candidates()
	check("岩盤の候補がある", cand.size() > 0)
	var mine_cell: Vector2i = cand[0]
	check("採掘指定できる", main.toggle_mining(mine_cell))
	check("指定キューに入る", board.designated.has(mine_cell))

	# 魔力は準備中に湧かない
	var m0: float = main.mana.mana
	main.tick(2.0)
	check("準備中は魔力が湧かない", is_equal_approx(main.mana.mana, m0))

	# 防壁でコアを完全封鎖しても、経路は防壁マスを通って返る（破壊して進む）
	var nbs: Array = board.neighbors4(core)
	var placed := 0
	for nb in nbs:
		if main.place_facility("wall", nb):
			placed += 1
	check("コア周囲に防壁を置ける", placed == 4)
	var src: Vector2i = board.perimeter_cells()[0]
	var path: Array = Pathfinding.find_path(board, main.facilities, src, core)
	check("封鎖時も経路が返る", path.size() > 0 and path[path.size() - 1] == core)
	var through_wall := false
	for c in path:
		if main.facilities.has(c):
			through_wall = true
	check("経路が防壁マスを含む（迂回不能なら破壊が選ばれる）", through_wall)
	var mats_before_remove: int = main.economy.materials
	for nb in nbs:
		main.remove_facility(nb)
	check("撤去で全額返還される", main.economy.materials == mats_before_remove + 4 * 2)

	# 全体魔法バフは施設と配下の両方に効く
	var tower_cell: Vector2i = core + Vector2i(0, 2)
	check("弓塔を置ける", main.place_facility("archer", tower_cell))
	var tower = main.facilities[tower_cell]
	check("バフ前の施設ダメージは素の値", is_equal_approx(tower.current_damage(main.magic), 8.0))
	main.mana.mana = main.mana.cap
	check("全体魔法を発動できる", main.magic.activate(main.mana))
	check("バフが施設に効く", is_equal_approx(tower.current_damage(main.magic), 12.0))
	check("バフが配下に効く", is_equal_approx(demon.current_damage(main.magic), 24.0))
	main.magic.tick(Balance.BUFF_DURATION + 1.0)
	check("バフは時間で切れる", not main.magic.is_active())

	# wave 1 開始。魔力は戦闘中にだけ湧く
	var funds_pre: int = main.economy.funds
	var mats_pre: int = main.economy.materials
	check("wave1を開始できる", main.start_wave(1))
	check("戦闘フェーズになる", main.is_combat())
	var mana_pre: float = main.mana.mana
	main.tick(1.0)
	check("戦闘中は魔力が湧く", main.mana.mana > mana_pre)

	# 出現は外周から
	var guard := 0
	while main.enemies.size() < 2 and guard < 200:
		main.tick(0.1)
		guard += 1
	check("敵が出現する", main.enemies.size() >= 2)
	var all_perim := true
	for e in main.enemies:
		if not board.is_perimeter(e.spawn_cell):
			all_perim = false
	check("出現セルは外周", all_perim)

	# 出現地点からコアへの経路がある
	var e0 = main.enemies[0]
	var p2: Array = Pathfinding.find_path(board, main.facilities, e0.spawn_cell, core)
	check("出現地点からコアへの経路がある", p2.size() > 0 and p2[p2.size() - 1] == core)

	# 幻惑：サキュバスの隣の敵が同士討ちに転じる
	e0.hp = e0.max_hp
	var adj = null
	for nb in board.neighbors4(e0.current_cell()):
		if board.is_playable(nb) and not main.facilities.has(nb) and nb != core:
			adj = nb
			break
	check("サキュバスを敵の隣へ置ける", adj != null)
	if adj != null:
		succ.place_at(board, adj)
		succ.charm_cooldown = 0.0
		main.tick(0.1)
		var charmed = null
		for e in main.enemies:
			if e.is_charmed():
				charmed = e
		check("幻惑がかかる", charmed != null)
		if charmed != null:
			main.tick(0.1)
			check("幻惑中は敵同士を狙う", charmed.current_target is Enemy)

	# wave 1 をクリアまで進める（テスト側で敵を倒し切る）
	guard = 0
	while not main.is_prep() and guard < 4000:
		main.tick(0.2)
		for e in main.enemies.duplicate():
			if e.alive:
				e.take_damage(100000.0)
		guard += 1
	check("wave1をクリアできる", main.is_prep() and main.last_wave_won)
	check("クリアで次waveが解禁される", main.waves.unlocked_wave >= 2)
	var gain1: int = main.economy.funds - funds_pre
	check("クリア報酬の資金が入る", gain1 == 40)
	check("採掘セルが盤面に加わる", board.is_playable(mine_cell))
	check("wave終了時に資材が入る", main.economy.materials == mats_pre + Balance.MATERIALS_PER_MINED_CELL)

	# クリア済み wave の再挑戦は報酬減額
	var funds_pre2: int = main.economy.funds
	check("クリア済みwaveを再挑戦できる", main.start_wave(1))
	guard = 0
	while not main.is_prep() and guard < 4000:
		main.tick(0.2)
		for e in main.enemies.duplicate():
			if e.alive:
				e.take_damage(100000.0)
		guard += 1
	var gain2: int = main.economy.funds - funds_pre2
	check("再挑戦の報酬は減額される", gain2 == 20 and gain2 < gain1)

	print("----")
	print("SMOKE TEST: %d passed, %d failed" % [passes, failures.size()])
	if not failures.is_empty():
		print("FAILED CHECKS: ", failures)
	quit(1 if not failures.is_empty() else 0)
