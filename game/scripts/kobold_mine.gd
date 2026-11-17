class_name KoboldMine
extends Facility

## 採掘所は当面、コボルドが出入りする動きを見せるだけの設備（AGENTS.md）。
## 攻撃・強化などのゲーム上の機能は持たせない。

var _kobold: MeshInstance3D
var _t := 0.0


func setup(p_kind: String, p_cell: Vector2i, world: Vector3) -> void:
	super.setup(p_kind, p_cell, world)
	_kobold = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.16
	cap.height = 0.5
	_kobold.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.55, 0.25)
	_kobold.material_override = m
	_kobold.position = Vector3(0, 0.25, 0.1)
	add_child(_kobold)


func animate(dt: float) -> void:
	if _kobold == null or not alive:
		return
	_t += dt
	var s := (sin(_t * 1.3) + 1.0) * 0.5
	_kobold.position = Vector3(0, 0.25, lerpf(0.1, -1.05, s))


func tick(_dt: float, _game) -> void:
	pass # 迎撃などの機能は持たない
