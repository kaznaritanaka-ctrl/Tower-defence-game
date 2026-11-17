class_name ManaSystem
extends Node

## 魔力（ダンジョンコア＝魔力タンク）。
## 戦闘中にのみ地下から湧き、上限まで貯まる。残量は次 wave へ持ち越す。
## 実時間の蓄積やオフライン精算は作らない（廃止した設計）。

var mana := 0.0
var cap := 0.0


func setup() -> void:
	mana = Balance.MANA_START
	cap = Balance.MANA_CAP


func tick(dt: float, in_combat: bool) -> void:
	if in_combat:
		mana = minf(mana + Balance.MANA_PER_SECOND * dt, cap)


func try_spend(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true
