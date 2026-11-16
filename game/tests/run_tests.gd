extends SceneTree
## ゲームロジックの確認。画面を使わずに実行する。
##   godot --headless --path game -s res://tests/run_tests.gd

const Game = preload("res://core/game.gd")
const B = preload("res://core/balance.gd")

var _failed := 0
var _passed := 0


func _init() -> void:
	_test_board()
	_test_economy()
	_test_wave_lose_and_win()
	_test_blockade()
	_test_mana_and_spell()
	_test_minions()
	_test_dig_and_directions()
	print("passed %d / failed %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


## 戦闘を最後まで進める。終わらなければ false。
func _run(g, limit: float = 600.0) -> bool:
	var t := 0.0
	while g.phase == "battle" and t < limit:
		g.tick(0.05)
		t += 0.05
	return g.phase == "result"


func _strong_defence(g) -> void:
	g.materials = 9999
	g.funds = 9999
	for c in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 4), Vector2i(4, 4)]:
		g.place("arrow", c)
	for c in [Vector2i(3, 2), Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 4)]:
		g.place("mage", c)
	g.hire("demon")
	g.hire("succubus")


func _test_board() -> void:
	var g = Game.new(1)
	_check(g.floor_cells.size() == 49, "初期盤面は7×7")
	_check(g.core_cell == Vector2i(3, 3), "コアは中央")
	_check(g.is_rock(Vector2i(-1, 3)) and g.is_rock(Vector2i(3, 7)), "盤面に接する外側は岩盤")
	_check(not g.is_rock(Vector2i(-1, -1)), "斜めにしか接しないマスは岩盤に数えない")
	_check(not g.is_rock(Vector2i(-2, 3)), "盤面から離れたマスは掘れない")
	_check(g.rock_cells().size() == 28, "初期の岩盤は28マス")


func _test_economy() -> void:
	var g = Game.new(1)
	var m0: int = g.materials
	var f0: int = g.funds
	_check(g.place("arrow", Vector2i(1, 1)), "弓塔を設置できる")
	_check(g.materials == m0 - 30 and g.funds == f0 - 15, "設置で資材と資金を消費する")
	_check(not g.place("wall", Vector2i(1, 1)), "同じマスには置けない")
	_check(not g.place("wall", g.core_cell), "コアのマスには置けない")
	_check(not g.place("wall", Vector2i(-1, 0)), "盤面の外には置けない")
	_check(g.remove(Vector2i(1, 1)), "撤去できる")
	_check(g.materials == m0 and g.funds == f0, "撤去は全額返還")
	g.materials = 0
	_check(not g.place("wall", Vector2i(1, 1)), "資材が足りなければ置けない")
	g.funds = 39
	_check(not g.hire("demon"), "資金が足りなければ雇用できない")
	g.funds = 40
	_check(g.hire("demon") and g.funds == 0, "配下は資金で雇用する")
	_check(not g.hire("demon"), "同じ配下は二重に雇用できない")
	g.funds = 100
	g.materials = 100
	g.mana = 0.0
	_check(not g.do_research("mana_regen"), "魔法研究は魔力がなければできない")
	g.mana = 20.0
	_check(g.do_research("mana_regen") and g.mana == 0.0 and g.funds == 80, "魔法研究は魔力と資金を消費する")
	_check(is_equal_approx(g.mana_regen(), 2.5), "汲み上げ量の研究で供給量が増える")
	_check(g.do_research("weapon") and g.funds == 60 and g.materials == 80, "武器研究は資金と資材を消費する")


func _test_wave_lose_and_win() -> void:
	var g = Game.new(2)
	_check(not g.start_wave(1), "未解禁の wave には挑戦できない")
	_check(g.start_wave(0), "wave 1 を開始できる")
	_check(not g.place("wall", Vector2i(1, 1)), "戦闘中は設置できない")
	_check(not g.remove(Vector2i(1, 1)) and not g.hire("demon"), "戦闘中は撤去と雇用ができない")
	_check(_run(g), "防衛なしの wave が終わる")
	_check(not g.last_result["win"], "防衛なしではコアが破壊されて失敗")
	_check(g.unlocked == 1 and g.last_result["reward"] == 0, "失敗では解禁も報酬もない")
	g.confirm_result()
	_check(g.core_hp == B.CORE["hp"], "失敗してもコアは復旧する")

	_strong_defence(g)
	var funds_before: int = g.funds
	g.start_wave(0)
	_check(_run(g) and g.last_result["win"], "十分な防衛で wave 1 に勝利")
	_check(g.funds == funds_before + 30, "初回クリアは満額の報酬")
	_check(g.unlocked == 2, "クリアで次の wave を解禁")
	g.confirm_result()
	funds_before = g.funds
	g.start_wave(0)
	_run(g)
	_check(g.last_result["win"] and g.funds == funds_before + 15, "再挑戦の報酬は減額")
	g.confirm_result()
	g.start_wave(1)
	_check(_run(g) and g.last_result["win"], "wave 2 に勝利")
	g.confirm_result()
	g.start_wave(2)
	_check(_run(g), "wave 3 が終わる")
	_check(g.unlocked == 3, "解禁は wave の数を超えない")
	for c in g.facilities:
		_check(g.facilities[c]["hp"] > 0.0, "壊れた設備は wave 終了後に復旧する")
	for m in g.minions:
		_check(m["alive"] and Vector2(m["home"]) == m["pos"], "配下は wave 終了後に持ち場へ復帰する")


func _test_blockade() -> void:
	var g = Game.new(3)
	g.materials = 9999
	for c in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(4, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]:
		_check(g.place("wall", c), "コアを囲む防壁を置ける")
	g.start_wave(0)
	_check(_run(g), "完全封鎖でも wave が終わる")
	_check(not g.last_result["win"], "完全封鎖でも敵は防壁を壊してコアに届く")


func _test_mana_and_spell() -> void:
	var g = Game.new(4)
	_strong_defence(g)
	g.mana = 0.0
	_check(not g.cast_spell(), "準備中は全体魔法を使えない")
	g.start_wave(0)
	_check(not g.cast_spell(), "魔力が足りなければ使えない")
	for i in 200:
		g.tick(0.05)
	if g.phase == "battle":
		_check(g.mana >= 19.0, "戦闘中に魔力が湧く")
	g.mana = 40.0
	if g.phase == "battle":
		_check(g.cast_spell() and is_equal_approx(g.mana, 10.0), "全体魔法は魔力を消費する")
		_check(g.buff_time > 0.0, "全体魔法で攻撃力アップの時間が始まる")
	_run(g)
	var carried: float = g.mana
	g.confirm_result()
	_check(carried > 0.0 and g.mana == carried, "魔力の残量は次へ持ち越す")
	_check(g.mana <= g.mana_cap(), "魔力は上限を超えない")
	g.start_wave(0)
	_check(g.mana == carried, "次の wave は持ち越した魔力から始まる")


func _test_minions() -> void:
	var g = Game.new(5)
	g.funds = 9999
	g.materials = 9999
	_check(not g.move_minion(0, Vector2i(1, 1)), "雇用していない配下は動かせない")
	g.place("wall", g.minions[0]["home"])
	g.hire("demon")
	_check(not g.is_blocked(g.minions[0]["home"]), "持ち場が塞がっていれば雇用時に空いたマスへ移る")
	_check(g.move_minion(0, Vector2i(1, 1)), "準備中は持ち場を変えられる")
	_check(g.minions[0]["home"] == Vector2i(1, 1), "持ち場が更新される")
	g.place("wall", Vector2i(5, 5))
	_check(not g.move_minion(0, Vector2i(5, 5)), "防壁のマスへは動かせない")
	_check(not g.place("wall", Vector2i(1, 1)), "配下の持ち場には防壁を置けない")
	g.start_wave(0)
	_check(g.move_minion(0, Vector2i(5, 1)), "戦闘中に移動を指示できる")
	for i in 80:
		g.tick(0.05)
	if g.minions[0]["alive"]:
		_check(Vector2(g.minions[0]["pos"]).distance_to(Vector2(5, 1)) < 0.01, "配下は指示したマスに着く")


func _test_dig_and_directions() -> void:
	var g = Game.new(6)
	_check(not g.toggle_dig(Vector2i(3, 3)), "床は採掘先にできない")
	_check(g.toggle_dig(Vector2i(3, -1)) and g.toggle_dig(Vector2i(7, 3)), "岩盤を採掘先に指定できる")
	_check(not g.toggle_dig(Vector2i(-1, 3)), "1 wave で掘れる数を超えて指定できない")
	var m0: int = g.materials
	g.start_wave(0)
	_check(not g.is_floor(Vector2i(3, -1)), "戦闘中に盤面は広がらない")
	_check(g.spawn_dirs.size() == 1, "wave 1 は1方向")
	_run(g)
	_check(g.is_floor(Vector2i(3, -1)) and g.is_floor(Vector2i(7, 3)), "wave 終了時に盤面が広がる")
	_check(g.materials == m0 + 40, "採掘した分の資材を得る（失敗した wave でも）")
	_check(g.dig_marks.is_empty(), "採掘先の指定は消える")
	g.confirm_result()
	g.unlocked = 3
	g.start_wave(2)
	_check(g.spawn_dirs.size() == 2 and g.spawn_dirs[0] != g.spawn_dirs[1], "wave 3 は異なる2方向")
	var info: Dictionary = g.wave_info(2)
	_check(info["counts"]["soldier"] == 10 and info["counts"]["archer"] == 4, "wave 3 の編成は兵士10・弓兵4")
	# 方向は毎回抽選される
	var seen := {}
	for s in 20:
		var h = Game.new(100 + s)
		h.start_wave(0)
		seen[h.spawn_dirs[0]] = true
	_check(seen.size() >= 3, "侵入方向は挑戦のたびに変わる")
