extends RefCounted
## 数値の定義。ここにある数値はすべて仮で、遊びながら調整する。
## 距離の単位は「マス」、時間の単位は「秒」。

## 初期盤面の一辺と、ダンジョンLv1で広げられる最大の一辺。
const BOARD_SIZE := 7
const BOARD_LIMIT_LV1 := 11

## 開始時の資源。
const START := {"mana": 10.0, "materials": 80, "funds": 60}

## ダンジョンコア（魔力タンク）。
const CORE := {"hp": 500.0}

## 魔力。regen は戦闘中に1秒あたり湧く量、cap はタンクの上限。
const MANA := {"regen": 2.0, "cap": 50.0}

## 採掘。per_wave は1 wave で掘れるマス数、materials は1マスあたりの資材。
const DIG := {"per_wave": 2, "materials": 20}

## クリア済み wave の再挑戦で得る報酬の割合。
const REPLAY_REWARD_RATE := 0.5

## 敵の経路探索で、防壁や塔を壊して通る場合に上乗せするコスト。
const WALL_PATH_COST := 6.0

## 近接攻撃が届く距離。
const MELEE_REACH := 1.3

## 同じ集団の敵が現れる間隔。
const SPAWN_INTERVAL := 0.9

## 設備。block が true のものは通行を塞ぎ、敵に壊される。
const FACILITIES := {
	"wall": {"name": "防壁", "hp": 90.0, "materials": 10, "funds": 0, "block": true},
	"arrow": {
		"name": "弓塔", "hp": 70.0, "materials": 30, "funds": 15, "block": true,
		"range": 2.6, "damage": 9.0, "interval": 0.8,
	},
	"mage": {
		"name": "魔法塔", "hp": 60.0, "materials": 25, "funds": 25, "block": true,
		"range": 2.1, "damage": 14.0, "interval": 1.6, "splash": 0.9,
	},
	"trap": {
		"name": "罠", "hp": 1.0, "materials": 15, "funds": 5, "block": false,
		"damage": 25.0, "interval": 3.0,
	},
}

## 敵。range が 0 のものは近接。
const ENEMIES := {
	"soldier": {"name": "兵士", "hp": 50.0, "speed": 0.75, "damage": 6.0, "interval": 0.9, "range": 0.0},
	"archer": {"name": "弓兵", "hp": 30.0, "speed": 0.65, "damage": 5.0, "interval": 1.1, "range": 2.4},
}

## 配下。hire は雇用に必要な資金。
## サキュバスの幻惑は「当てた敵の移動を遅くする」という仮の効果。
const MINIONS := {
	"demon": {
		"name": "デーモン", "hire": 40, "hp": 260.0, "speed": 2.2,
		"damage": 16.0, "interval": 0.7, "range": 1.3,
	},
	"succubus": {
		"name": "サキュバス", "hire": 30, "hp": 90.0, "speed": 2.0,
		"damage": 5.0, "interval": 1.0, "range": 2.4, "slow": 0.5, "slow_time": 2.0,
	},
}

## 全体魔法：数秒間の全体攻撃力アップ。対象は配下と塔（仮）。
const SPELL := {"name": "全体攻撃力アップ", "mana": 30.0, "duration": 6.0, "multiplier": 1.5}

## 研究。魔法研究は魔力と資金、武器研究は資金と資材で払う。
const RESEARCH := {
	"mana_regen": {"name": "汲み上げ量", "kind": "魔法研究", "mana": 20.0, "funds": 20, "materials": 0, "max": 3, "bonus": 0.25},
	"mana_cap": {"name": "蓄積上限", "kind": "魔法研究", "mana": 20.0, "funds": 20, "materials": 0, "max": 3, "bonus": 0.25},
	"weapon": {"name": "配下の武器", "kind": "武器研究", "mana": 0.0, "funds": 20, "materials": 20, "max": 3, "bonus": 0.2},
}

## ダンジョンLv1 の wave。
## directions は侵入してくる方向の数。slot はそのうち何番目の方向から来るか。
## at はその集団が現れ始める時刻。units は [種類, 数] の並び。
const WAVES := [
	{
		"reward": 30, "directions": 1,
		"groups": [
			{"slot": 0, "at": 0.0, "units": [["soldier", 4]]},
		],
	},
	{
		"reward": 50, "directions": 2,
		"groups": [
			{"slot": 0, "at": 0.0, "units": [["soldier", 4]]},
			{"slot": 1, "at": 6.0, "units": [["soldier", 2], ["archer", 2]]},
		],
	},
	{
		"reward": 80, "directions": 2,
		"groups": [
			{"slot": 0, "at": 0.0, "units": [["soldier", 5], ["archer", 2]]},
			{"slot": 1, "at": 6.0, "units": [["soldier", 3], ["archer", 2]]},
			{"slot": 0, "at": 16.0, "units": [["soldier", 2]]},
		],
	},
]
