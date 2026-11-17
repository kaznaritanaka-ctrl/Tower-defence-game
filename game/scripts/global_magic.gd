class_name GlobalMagic
extends Node

## 全体魔法（最初の1種）：数秒間の全体攻撃力アップ。
## 対象範囲は施設＋配下の両方（2026-11-18決定）。消費は魔力。

var remaining := 0.0


func activate(mana_system) -> bool:
	if remaining > 0.0:
		return false
	if not mana_system.try_spend(Balance.BUFF_COST):
		return false
	remaining = Balance.BUFF_DURATION
	return true


func tick(dt: float) -> void:
	remaining = maxf(remaining - dt, 0.0)


func is_active() -> bool:
	return remaining > 0.0


func multiplier() -> float:
	return Balance.BUFF_MULTIPLIER if is_active() else 1.0
