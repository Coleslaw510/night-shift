class_name Vehicle
extends AnimatableBody3D
## Simple lot car. Drives a short waypoint path, waits, then leaves.
## Shoppers park and walk in. Fuel customers stop at a pump.

enum V { TO_SPOT, PARKED, TO_PUMP, AT_PUMP, TO_EXIT, DONE }

const COLORS := [Color(0.55, 0.08, 0.08), Color(0.15, 0.22, 0.38), Color(0.85, 0.75, 0.2), Color(0.2, 0.32, 0.22), Color(0.45, 0.45, 0.48), Color(0.55, 0.25, 0.12)]

var vstate := V.TO_SPOT
var path: Array = []
var speed := 7.0
var game: Node = null
var spot: Dictionary = {}
var is_fuel := false
var driver: Node = null
var player_driver := false
var damage_reported := false
var _stuck := 0.0
var _creeps := 0
var blurb: Label3D

func setup(g: Node, dest: Dictionary, fuel: bool) -> void:
	game = g
	spot = dest
	is_fuel = fuel
	add_to_group("vehicle")
	sync_to_physics = false
	_build(COLORS[randi() % COLORS.size()])
	var gate := _gate()
	global_position = gate + Vector3(randf_range(-1.5, 1.5), 0, 3.0)
	var dest_pos: Vector3 = dest.pos
	if fuel:
		dest_pos += Vector3(0, 0, 2.6)
		vstate = V.TO_PUMP
	else:
		vstate = V.TO_SPOT
	path = [gate, Vector3(dest_pos.x, 0, gate.z - 3.0), dest_pos]

func place_parked(g: Node, dest: Dictionary, paint: Color) -> void:
	game = g
	spot = dest
	is_fuel = false
	add_to_group("vehicle")
	sync_to_physics = false
	_build(paint)
	global_position = dest.pos
	rotation.y = float(dest.yaw)
	vstate = V.PARKED

func _build(paint: Color) -> void:
	var body := StoreBuilder.mat(paint, 0.0, 0.35, 0.45)
	StoreBuilder.box(self, Vector3(1.8, 0.55, 4.2), Vector3(0, 0.55, 0), body)
	StoreBuilder.box(self, Vector3(1.6, 0.5, 2.0), Vector3(0, 1.05, -0.15), body)
	StoreBuilder.box(self, Vector3(1.5, 0.38, 1.7), Vector3(0, 1.08, -0.15), StoreBuilder.mat(Color(0.05, 0.07, 0.1, 0.85), 0.0, 0.1))
	for wx in [-0.85, 0.85]:
		for wz in [-1.35, 1.35]:
			var w := StoreBuilder.cyl(self, 0.32, 0.22, Vector3(wx, 0.32, wz), StoreBuilder.mat(Color(0.05, 0.05, 0.05)))
			w.rotation.z = PI * 0.5
	for lx in [-0.55, 0.55]:
		StoreBuilder.box(self, Vector3(0.28, 0.1, 0.04), Vector3(lx, 0.62, 2.08), StoreBuilder.mat(Color(1, 0.95, 0.75), 0.8))
		StoreBuilder.box(self, Vector3(0.22, 0.08, 0.04), Vector3(lx, 0.62, -2.08), StoreBuilder.mat(Color(0.7, 0.05, 0.05), 0.5))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.9, 1.4, 4.3)
	cs.shape = sh
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)
	blurb = Label3D.new()
	blurb.position = Vector3(0, 2.1, 0)
	blurb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	blurb.font_size = 48
	blurb.pixel_size = 0.004
	blurb.modulate = Color(1, 0.9, 0.4)
	blurb.visible = false
	add_child(blurb)

func say(text: String) -> void:
	blurb.text = text
	blurb.visible = text != ""

func door_position() -> Vector3:
	var side: Vector3 = global_transform.basis.x
	side.y = 0
	if side.length() < 0.01:
		side = Vector3(1, 0, 0)
	return global_position + side.normalized() * 1.7

func depart() -> void:
	if vstate == V.TO_EXIT or vstate == V.DONE:
		return
	say("")
	vstate = V.TO_EXIT
	var gate := _gate()
	path = [Vector3(global_position.x, 0, gate.z - 4.0), Vector3(0, 0, gate.z - 4.0), gate, gate + Vector3(0, 0, 5)]
	_stuck = 0.0

func _gate() -> Vector3:
	return Vector3(0, 0, StoreBuilder.FENCE.position.y + StoreBuilder.FENCE.size.y - 2.0)

func _blocked(dir: Vector3) -> bool:
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v == self:
			continue
		var rel: Vector3 = v.global_position - global_position
		rel.y = 0
		var ahead := rel.dot(dir)
		if ahead > 0.2 and ahead < 5.2 and (rel - dir * ahead).length() < 1.7:
			return true
	if game and is_instance_valid(game.player):
		var relp: Vector3 = game.player.global_position - global_position
		relp.y = 0
		var aheadp := relp.dot(dir)
		if aheadp > 0.2 and aheadp < 3.4 and (relp - dir * aheadp).length() < 1.3:
			return true
	return false

func _physics_process(delta: float) -> void:
	if player_driver:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if game and is_instance_valid(game.player) and game.player.touch_move.length() > inp.length():
			inp = game.player.touch_move
		# Top-down arcade driving: joystick/WASD directly chooses a world direction.
		var dir := Vector3(inp.x, 0, inp.y)
		if game and game.driving_camera:
			var forward: Vector3 = -game.driving_camera.global_transform.basis.z
			forward.y = 0
			forward = forward.normalized()
			var right: Vector3 = game.driving_camera.global_transform.basis.x
			right.y = 0
			right = right.normalized()
			dir = right * inp.x + forward * -inp.y
		if dir.length() > 0.05:
			dir = dir.normalized()
			global_position += dir * 9.5 * delta
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 10.0))
			# Trigger damage as soon as the car reaches the storefront, even if the glass collision stops it.
			var at_store_front := global_position.x > -20.0 and global_position.x < 20.0 and global_position.z > 18.0 and global_position.z < 24.5
			if game and at_store_front and game.has_method("vehicle_damaged_store"):
				game.vehicle_damaged_store(self)
		return
	if vstate == V.PARKED or vstate == V.AT_PUMP or vstate == V.DONE:
		return
	if path.is_empty():
		_arrived()
		return
	var tgt: Vector3 = path[0]
	var d: Vector3 = tgt - global_position
	d.y = 0
	if d.length() <= 0.4:
		path.pop_front()
		if path.is_empty():
			_arrived()
		return
	var dir := d.normalized()
	if _blocked(dir):
		_stuck += delta
		if _stuck > 5.0:
			_stuck = 0.0
			_creeps += 1
			if _creeps >= 3:
				path.clear()
				_arrived()
			else:
				global_position += Vector3(0.8 if global_position.x < 0 else -0.8, 0, 0.3)
		return
	_stuck = 0.0
	global_position += dir * minf(speed * delta, d.length())
	global_position.y = 0
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 6.0 * delta))

func _arrived() -> void:
	_creeps = 0
	_stuck = 0.0
	match vstate:
		V.TO_SPOT:
			global_position = spot.pos
			rotation.y = float(spot.get("yaw", PI))
			vstate = V.PARKED
			if game:
				game.on_car_parked(self)
		V.TO_PUMP:
			vstate = V.AT_PUMP
			if game:
				game.on_car_at_pump(self)
		_:
			vstate = V.DONE
			if game:
				game.on_car_gone(self)
			queue_free()

func _exit_tree() -> void:
	if game and game.has_method("release_vehicle"):
		game.release_vehicle(self)

func get_prompt(_p: Node) -> String:
	if vstate == V.PARKED and game != null and not player_driver:
		return "[E] Drive this car"
	if vstate != V.AT_PUMP or game == null:
		return ""
	if game.fuel_for(self) == null:
		return "[E] Ask how much gas"
	if game.fuel_is_running():
		return "[E] Stop the pump"
	return "[E] Start fueling"

func interact(_p: Node) -> void:
	if vstate == V.PARKED and game:
		game.enter_vehicle(self)
	elif vstate == V.AT_PUMP and game:
		game.fuel_interact(self)
