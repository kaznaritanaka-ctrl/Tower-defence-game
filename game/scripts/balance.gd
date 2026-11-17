class_name Balance
extends RefCounted

## ============================================================
## 試作仮値（確定仕様ではない）
##
## ここにある数値はすべて、wave 構造の試作を動かすための仮置きである。
## AGENTS.md と docs の方針どおり、数値は試作で遊びながら決める。
## 調整はこのファイルだけを触ること。仕様文書の確定値として扱わない。
## ============================================================

const BOARD_INITIAL_SIZE := 7

const CORE_HP := 100.0

# 魔力（戦闘中にのみ湧く）
const MANA_START := 20.0
const MANA_CAP := 100.0
const MANA_PER_SECOND := 6.0

# 全体魔法（数秒間の全体攻撃力アップ。対象は施設＋配下の両方：2026-11-18決定）
const BUFF_COST := 30.0
const BUFF_DURATION := 6.0
const BUFF_MULTIPLIER := 1.5

# 経済の初期値
const FUNDS_START := 150
const MATERIALS_START := 50
const MATERIALS_PER_MINED_CELL := 5
const RETRY_REWARD_RATE := 0.5

# 経路探索：施設のあるマスを通るコスト（迂回との比較に使う）
const PATH_BLOCKER_COST := 8.0
const SPAWN_INTERVAL := 0.8

# 施設（hp / damage / range=マス単位の距離 / interval=秒 / cost）
const FACILITIES := {
	"wall": {"hp": 60.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "cost_materials": 2, "cost_funds": 0, "label": "防壁"},
	"archer": {"hp": 40.0, "damage": 8.0, "range": 2.6, "interval": 0.9, "cost_materials": 5, "cost_funds": 10, "label": "弓塔"},
	"mage": {"hp": 35.0, "damage": 14.0, "range": 2.2, "interval": 1.4, "cost_materials": 8, "cost_funds": 15, "label": "魔法塔"},
	"mine": {"hp": 40.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "cost_materials": 6, "cost_funds": 5, "label": "採掘所"},
}

# 配下
const MINIONS := {
	"demon": {"hp": 120.0, "damage": 16.0, "range": 1.35, "interval": 0.8, "speed": 2.2, "label": "デーモン"},
	"succubus": {"hp": 80.0, "damage": 6.0, "range": 1.35, "interval": 1.0, "speed": 2.4, "label": "サキュバス"},
}

# サキュバスの幻惑（範囲内の敵1体を数秒間同士討ちさせる：2026-11-18決定）
const CHARM_RANGE := 2.4
const CHARM_DURATION := 4.0
const CHARM_COOLDOWN := 6.0

# 敵（GAME_DESIGN に兵種の定義がないため、試作では基本の侵入者1種のみ）
const ENEMY_HP := 30.0
const ENEMY_DAMAGE := 6.0
const ENEMY_SPEED := 0.85
const ENEMY_ATTACK_INTERVAL := 1.0
const ENEMY_ATTACK_RANGE := 1.2

# wave 定義（ダンジョンLv1の3つ）
const WAVES := [
	{"count": 6, "directions": 1, "hp_multiplier": 1.0, "reward_funds": 40},
	{"count": 9, "directions": 2, "hp_multiplier": 1.4, "reward_funds": 60},
	{"count": 12, "directions": 3, "hp_multiplier": 1.9, "reward_funds": 90},
]
