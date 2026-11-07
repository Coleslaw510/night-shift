class_name Cart
extends RigidBody3D
## Shopping cart. Parked or loose carts are physics objects (shove them, walk up
## the rear ramp and ride). Held carts are pushed in front of the player.
## A customer cart is kinematic and follows them.

enum M { FREE, HELD, FOLLOW, PARKED }

var mode := M.FREE
var follower: Node3D = null
var touched_by_player := false
var paid := false
var reserved_by: Node = null

func _ready() -> void:
	add_to_group("cart")
	mass = 12.0
	continuous_cd = true
	can_sleep = true
	linear_damp = 0.8
	angular_damp = 2.0
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	_build()

func _build() -> void:
	var metal := StoreBuilder.mat(Color(0.72, 0.74, 0.76), 0.15, 0.35, 0.7)
	var plastic := StoreBuilder.mat(Color(0.15, 0.38, 0.72), 0.0, 0.45)
	var wheel := StoreBuilder.mat(Color(0.08, 0.08, 0.08))
	# basket
	StoreBuilder.box(self, Vector3(0.62, 0.04, 0.9), Vector3(0, 0.38, 0.05), plastic)
	for sx in [-0.3, 0.3]:
		StoreBuilder.box(self, Vector3(0.03, 0.32, 0.9), Vector3(sx, 0.54, 0.05), plastic)
	StoreBuilder.box(self, Vector3(0.62, 0.32, 0.03), Vector3(0, 0.54, 0.5), plastic)
	StoreBuilder.box(self, Vector3(0.62, 0.22, 0.03), Vector3(0, 0.5, -0.4), plastic)
	# frame + handle
	StoreBuilder.box(self, Vector3(0.5, 0.04, 0.85), Vector3(0, 0.22, 0.05), metal)
	StoreBuilder.box(self, Vector3(0.08, 0.7, 0.08), Vector3(-0.24, 0.7, -0.42), metal)
	StoreBuilder.box(self, Vector3(0.08, 0.7, 0.08), Vector3(0.24, 0.7, -0.42), metal)
	StoreBuilder.box(self, Vector3(0.62, 0.05, 0.05), Vector3(0, 1.02, -0.42), StoreBuilder.mat(Color(0.1, 0.1, 0.1)))
	for wx in [-0.28, 0.28]:
		for wz in [-0.28, 0.38]:
			var w := StoreBuilder.cyl(self, 0.1, 0.06, Vector3(wx, 0.1, wz), wheel)
			w.rotation.z = PI * 0.5
	# child seat flap
	StoreBuilder.box(self, Vector3(0.4, 0.03, 0.22), Vector3(0, 0.62, 0.32), plastic)
	var body := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.66, 0.55, 0.95)
	body.shape = box
	body.position = Vector3(0, 0.48, 0.05)
	add_child(body)
	# low ramp at the back so the player can walk up into the basket
	var ramp := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(0.5, 0.08, 0.7)
	ramp.shape = rb
	ramp.position = Vector3(0, 0.2, -0.55)
	ramp.rotation.x = deg_to_rad(-28)
	add_child(ramp)

func hold(by: Node3D) -> void:
	mode = M.HELD
	follower = by
	touched_by_player = true
	paid = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func follow(by: Node3D) -> void:
	mode = M.FOLLOW
	follower = by
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func release() -> void:
	mode = M.FREE
	follower = null
	freeze = false
	sleeping = false

func park(at: Vector3) -> void:
	mode = M.PARKED
	follower = null
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = Vector3(at.x, 0.0, at.z)
	rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if mode == M.HELD and is_instance_valid(follower):
		var fwd: Vector3 = -follower.global_transform.basis.z
		fwd.y = 0
		if fwd.length() < 0.01:
			fwd = Vector3(0, 0, -1)
		fwd = fwd.normalized()
		var want := follower.global_position + fwd * 1.35
		want.y = 0.0
		var step: Vector3 = want - global_position
		step.y = 0
		if step.length() > 0.03:
			var space := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.45, 0), want + Vector3(0, 0.45, 0))
			q.exclude = [self, follower]
			if space.intersect_ray(q).is_empty():
				global_position = global_position.move_toward(Vector3(want.x, 0, want.z), 6.0 * delta)
		global_position.y = 0
		rotation.y = lerp_angle(rotation.y, atan2(fwd.x, fwd.z), minf(1.0, 10.0 * delta))
	elif mode == M.FOLLOW and is_instance_valid(follower):
		var back: Vector3 = follower.global_transform.basis.z
		back.y = 0
		if back.length() < 0.01:
			back = Vector3(0, 0, 1)
		back = back.normalized()
		global_position = follower.global_position + back * 0.95
		global_position.y = 0
		rotation.y = follower.rotation.y
	elif mode == M.FREE and linear_velocity.length() < 0.05:
		global_position.y = 0

func get_prompt(p: Node) -> String:
	if p.holding_cart == self:
		return "[E] Let go of the cart"
	if p.holding_cart != null:
		return ""
	if mode == M.FOLLOW:
		return "Someone's using this cart"
	if mode == M.PARKED:
		return "[E] Grab a cart"
	return "[E] Grab cart"

func interact(p: Node) -> void:
	if mode == M.FOLLOW and follower != p:
		return
	p.toggle_cart(self)
