extends StaticBody3D
## A product sitting on a checkout belt. Look at it and press E / click to scan.

var product: Dictionary
var register: Node

func setup(p: Dictionary, reg: Node) -> void:
	product = p
	register = reg
	var s: Vector3 = p.size * 0.9
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = StoreBuilder.mat(p.color, 0.1, 0.6)
	add_child(mi)
	StoreBuilder.box(mi, Vector3(s.x * 0.8, s.y * 0.3, 0.004), Vector3(0, s.y * 0.08, s.z * 0.5 + 0.002), StoreBuilder.mat(Products.label_color(p)))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = s.max(Vector3(0.12, 0.12, 0.12)) + Vector3(0.04, 0.04, 0.04)
	cs.shape = sh
	add_child(cs)

func get_prompt(_p: Node = null) -> String:
	return "[E] Scan %s  $%.2f" % [product.name, product.price]

func interact(_player: Node) -> void:
	register.scan(self)
