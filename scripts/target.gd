extends StaticBody3D
## Practice can or bottle. The shotgun knocks it over. It stands back up.

var down := false

func setup(kind: String) -> void:
	add_to_group("target")
	if kind == "bottle":
		StoreBuilder.cyl(self, 0.06, 0.28, Vector3(0, 0.14, 0), StoreBuilder.mat(Color(0.25, 0.55, 0.35, 0.85)))
		StoreBuilder.cyl(self, 0.025, 0.08, Vector3(0, 0.32, 0), StoreBuilder.mat(Color(0.2, 0.45, 0.28, 0.85)))
	else:
		StoreBuilder.cyl(self, 0.07, 0.16, Vector3(0, 0.08, 0), StoreBuilder.mat(Color(0.75, 0.15, 0.12)))
		StoreBuilder.cyl(self, 0.055, 0.02, Vector3(0, 0.17, 0), StoreBuilder.mat(Color(0.85, 0.8, 0.7)))
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.08
	sh.height = 0.32
	cs.shape = sh
	cs.position.y = 0.16
	add_child(cs)

func hit() -> void:
	if down:
		return
	down = true
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", deg_to_rad(78), 0.12)
	tw.tween_interval(2.4)
	tw.tween_property(self, "rotation:z", 0.0, 0.25)
	tw.tween_callback(func(): down = false)
