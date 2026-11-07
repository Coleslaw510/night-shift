extends RigidBody3D
## A box or trash bag the player set down. It stays in the world until someone
## picks it up. Nothing teleports back to a shelf or a crate.

var data: Dictionary = {}

func setup(d: Dictionary, pos: Vector3) -> void:
	data = d.duplicate(true)
	position = pos
	position.y = 0.45
	mass = 3.0
	continuous_cd = true
	linear_damp = 0.4
	angular_damp = 1.2
	var kind := str(data.get("kind", ""))
	if kind == "stock":
		var p: Dictionary = Products.CATALOG[int(data.product)]
		var b := StoreBuilder.box(self, Vector3(0.5, 0.34, 0.36), Vector3(0, 0.17, 0), StoreBuilder.mat(Color(0.56, 0.42, 0.26), 0.0, 0.95))
		StoreBuilder.box(b, Vector3(0.3, 0.12, 0.01), Vector3(0, 0.02, 0.181), StoreBuilder.mat(p.color))
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.52, 0.36, 0.38)
		cs.shape = sh
		cs.position.y = 0.18
		add_child(cs)
	else:
		StoreBuilder.box(self, Vector3(0.36, 0.42, 0.32), Vector3(0, 0.21, 0), StoreBuilder.mat(Color(0.04, 0.04, 0.05), 0.0, 0.25))
		var cs2 := CollisionShape3D.new()
		var sh2 := BoxShape3D.new()
		sh2.size = Vector3(0.38, 0.44, 0.34)
		cs2.shape = sh2
		cs2.position.y = 0.22
		add_child(cs2)

func get_prompt(p: Node) -> String:
	if not p.carrying.is_empty():
		return "Hands full"
	if str(data.get("kind", "")) == "stock":
		var prod: Dictionary = Products.CATALOG[int(data.product)]
		return "[E] Pick up %s  (%d left)" % [prod.name, int(data.count)]
	return "[E] Pick up the trash bag"

func interact(p: Node) -> void:
	if not p.carrying.is_empty():
		return
	p.set_carry(data.duplicate(true))
	queue_free()
