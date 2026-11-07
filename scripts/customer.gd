extends Node3D
## Low-poly human customer with simple waypoint AI.
## States: ENTER -> SHOP -> TO_QUEUE -> QUEUED -> AT_REGISTER -> LEAVING.
## Movement is kinematic along corridor waypoints (see HANDOFF.md layout), no navmesh.

signal finished(customer, paid: bool)

enum S { ENTER, SHOP, TO_QUEUE, QUEUED, AT_REGISTER, LEAVING }

const AISLES := [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]
const FRONT_Z := 3.0
const BACK_Z := -11.3
const PATIENCE := 150.0

var state := S.ENTER
var path: Array = []
var speed := 1.3
var items: Array = []        # Array of product dictionaries
var stops_left := 3
var wait_t := 0.0
var face_dir := Vector3.ZERO
var registers: Array = []
var my_register: Node = null
var queue_wait := 0.0
var phase := 0.0
var moving := false

var body: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var basket: Node3D

const SKINS := [Color(0.98, 0.84, 0.72), Color(0.88, 0.68, 0.52), Color(0.72, 0.52, 0.36), Color(0.55, 0.37, 0.24), Color(0.38, 0.25, 0.16)]
const HAIRS := [Color(0.08, 0.06, 0.05), Color(0.3, 0.18, 0.08), Color(0.6, 0.45, 0.2), Color(0.85, 0.75, 0.5), Color(0.55, 0.55, 0.55), Color(0.6, 0.15, 0.1)]
const SHIRTS := [Color(0.2, 0.3, 0.6), Color(0.6, 0.15, 0.15), Color(0.2, 0.5, 0.3), Color(0.5, 0.5, 0.5), Color(0.85, 0.7, 0.2), Color(0.35, 0.2, 0.45), Color(0.1, 0.1, 0.12), Color(0.9, 0.9, 0.88)]
const PANTS := [Color(0.15, 0.2, 0.35), Color(0.12, 0.12, 0.13), Color(0.4, 0.35, 0.28), Color(0.3, 0.3, 0.32), Color(0.25, 0.3, 0.2)]

func _ready() -> void:
	_build_body()
	stops_left = randi_range(2, 4)
	speed = randf_range(1.1, 1.5)
	path = [Vector3(StoreBuilder.DOOR_X, 0, 13.5), Vector3(StoreBuilder.DOOR_X, 0, FRONT_Z)]

func _part(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	return StoreBuilder.box(parent, size, pos, StoreBuilder.mat(c, 0.0, 0.85))

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p

func _build_body() -> void:
	var skin: Color = SKINS.pick_random()
	var hair: Color = HAIRS.pick_random()
	var shirt: Color = SHIRTS.pick_random()
	var pants: Color = PANTS.pick_random()
	var shoes := Color(0.1, 0.1, 0.1) if randf() < 0.6 else Color(0.85, 0.85, 0.85)
	var h := randf_range(0.92, 1.06)
	body = Node3D.new()
	body.scale = Vector3(randf_range(0.95, 1.12), h, randf_range(0.95, 1.1))
	add_child(body)
	leg_l = _pivot(body, Vector3(-0.1, 0.88, 0))
	leg_r = _pivot(body, Vector3(0.1, 0.88, 0))
	for leg in [leg_l, leg_r]:
		_part(leg, Vector3(0.15, 0.82, 0.17), Vector3(0, -0.41, 0), pants)
		_part(leg, Vector3(0.16, 0.08, 0.26), Vector3(0, -0.84, 0.04), shoes)
	_part(body, Vector3(0.42, 0.6, 0.24), Vector3(0, 1.18, 0), shirt)
	_part(body, Vector3(0.1, 0.06, 0.1), Vector3(0, 1.5, 0), skin)
	var head := _pivot(body, Vector3(0, 1.64, 0))
	_part(head, Vector3(0.22, 0.26, 0.24), Vector3.ZERO, skin)
	_part(head, Vector3(0.05, 0.06, 0.05), Vector3(0, -0.01, 0.13), skin.darkened(0.08))  # nose
	for ex in [-0.055, 0.055]:
		_part(head, Vector3(0.04, 0.03, 0.01), Vector3(ex, 0.03, 0.121), Color(0.05, 0.05, 0.05))
	_part(head, Vector3(0.24, 0.08, 0.26), Vector3(0, 0.13, -0.01), hair)
	_part(head, Vector3(0.24, 0.16, 0.06), Vector3(0, 0.05, -0.11), hair)
	if randf() < 0.35:  # cap
		_part(head, Vector3(0.25, 0.07, 0.27), Vector3(0, 0.16, 0), SHIRTS.pick_random())
		_part(head, Vector3(0.2, 0.02, 0.12), Vector3(0, 0.13, 0.17), SHIRTS.pick_random())
	arm_l = _pivot(body, Vector3(-0.27, 1.44, 0))
	arm_r = _pivot(body, Vector3(0.27, 1.44, 0))
	for arm in [arm_l, arm_r]:
		_part(arm, Vector3(0.11, 0.34, 0.12), Vector3(0, -0.17, 0), shirt)
		_part(arm, Vector3(0.09, 0.28, 0.1), Vector3(0, -0.47, 0), skin)
	# Shopping basket in right hand
	basket = _pivot(arm_r, Vector3(0.06, -0.68, 0.0))
	var red := Color(0.8, 0.1, 0.1)
	_part(basket, Vector3(0.22, 0.02, 0.36), Vector3(0, -0.2, 0), red)
	for sx in [-0.11, 0.11]:
		_part(basket, Vector3(0.015, 0.16, 0.36), Vector3(sx, -0.12, 0), red)
	for sz in [-0.18, 0.18]:
		_part(basket, Vector3(0.22, 0.16, 0.015), Vector3(0, -0.12, sz), red)
	_part(basket, Vector3(0.02, 0.02, 0.2), Vector3(0, 0.0, 0), Color(0.2, 0.2, 0.2))
	basket.visible = false
	# Collider so the player bumps into customers
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	sb.add_child(cs)
	add_child(sb)

func _add_item_to_basket(p: Dictionary) -> void:
	basket.visible = true
	items.append(p)
	var n := items.size() - 1
	var s: Vector3 = p.size * 0.6
	var m := _part(basket, s, Vector3(-0.05 + (n % 2) * 0.1, -0.19 + s.y * 0.5 + int(n / 4) * 0.06, -0.12 + (n / 2 % 2) * 0.16), p.color)
	m.name = "Item%d" % n

func clear_basket() -> void:
	for c in basket.get_children():
		if c.name.begins_with("Item"):
			c.queue_free()
	basket.visible = false

# ---------- routing ----------
func _route(from: Vector3, to: Vector3) -> Array:
	# Walk only along aisle centers (AISLES x) and the two cross corridors (FRONT_Z, BACK_Z).
	var on_from_corr := absf(from.z - FRONT_Z) < 0.1 or absf(from.z - BACK_Z) < 0.1
	if on_from_corr and absf(from.z - to.z) < 0.1:
		return [to]
	if absf(from.x - to.x) < 0.05 and _is_aisle(from.x):
		return [to]
	var cz := FRONT_Z
	if to.z <= BACK_Z + 0.1:
		cz = BACK_Z
	elif to.z < FRONT_Z - 0.1 and (from.z + to.z) * 0.5 < (FRONT_Z + BACK_Z) * 0.5:
		cz = BACK_Z
	var pts: Array = []
	if on_from_corr:
		var c := FRONT_Z if absf(from.z - FRONT_Z) < 0.1 else BACK_Z
		if absf(c - cz) > 0.1:
			var ax := _nearest_aisle(from.x)
			pts.append(Vector3(ax, 0, c))
			pts.append(Vector3(ax, 0, cz))
	else:
		pts.append(Vector3(from.x, 0, cz))
	pts.append(Vector3(to.x, 0, cz))
	pts.append(to)
	return pts

func _is_aisle(x: float) -> bool:
	for a in AISLES:
		if absf(a - x) < 0.05:
			return true
	return false

func _nearest_aisle(x: float) -> float:
	var best: float = AISLES[0]
	for a in AISLES:
		if absf(a - x) < absf(best - x):
			best = a
	return best

func _next_stop() -> void:
	var target: Vector3
	if randf() < 0.25:
		target = Vector3(randf_range(-8.0, 8.0), 0, -12.8)
		face_dir = Vector3(0, 0, -1)
	else:
		var ax: float = AISLES.pick_random()
		target = Vector3(ax, 0, randf_range(-8.3, 0.3))
		var side := 1.0 if ax < -9 else (-1.0 if ax > 9 else (1.0 if randf() < 0.5 else -1.0))
		face_dir = Vector3(side, 0, 0)
	path = _path_to(target)

func _path_to(target: Vector3) -> Array:
	if position.z < -12.0:  # at the freezer: step back into the back corridor first
		var from := Vector3(position.x, 0, BACK_Z)
		var pts: Array = [from]
		pts.append_array(_route(from, target))
		return pts
	return _route(position, target)

# ---------- register API ----------
func set_queue_spot(spot: Vector3) -> void:
	if state == S.QUEUED or state == S.AT_REGISTER:
		path = [spot]
		state = S.QUEUED

func pay_and_leave() -> void:
	state = S.LEAVING
	clear_basket()
	var lx := position.x
	path = [Vector3(lx, 0, 10.5), Vector3(StoreBuilder.DOOR_X, 0, 10.5), Vector3(StoreBuilder.DOOR_X, 0, 17.5)]
	finished.emit(self, true)

func _give_up() -> void:
	if my_register:
		my_register.leave(self)
	state = S.LEAVING
	clear_basket()
	var lx := position.x
	path = [Vector3(lx, 0, FRONT_Z), Vector3(StoreBuilder.DOOR_X, 0, FRONT_Z), Vector3(StoreBuilder.DOOR_X, 0, 17.5)]
	finished.emit(self, false)

# ---------- update ----------
func _process(delta: float) -> void:
	moving = false
	if not path.is_empty():
		var tgt: Vector3 = path[0]
		var d := tgt - position
		d.y = 0
		var step := speed * delta
		if d.length() <= step:
			position = Vector3(tgt.x, 0, tgt.z)
			path.pop_front()
			if path.is_empty():
				_arrived()
		else:
			var dir := d.normalized()
			position += dir * step
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 10 * delta))
			moving = true
	else:
		if face_dir != Vector3.ZERO:
			rotation.y = lerp_angle(rotation.y, atan2(face_dir.x, face_dir.z), minf(1.0, 6 * delta))
		_idle(delta)
	_animate(delta)

func _arrived() -> void:
	match state:
		S.ENTER:
			state = S.SHOP
			_next_stop()
		S.SHOP:
			wait_t = randf_range(1.5, 3.0)
		S.TO_QUEUE:
			pass
		S.QUEUED:
			face_dir = Vector3(0, 0, 1)
			if my_register and my_register.is_front(self):
				state = S.AT_REGISTER
				face_dir = Vector3(-1, 0, 0)
				my_register.customer_at_front(self)
		S.LEAVING:
			queue_free()

func _idle(delta: float) -> void:
	match state:
		S.SHOP:
			if wait_t > 0.0:
				wait_t -= delta
				arm_l.rotation.x = lerp(arm_l.rotation.x, -1.6, minf(1.0, 6 * delta))  # reach
				if wait_t <= 0.0:
					for k in randi_range(1, 2):
						_add_item_to_basket(Products.random())
					stops_left -= 1
					if stops_left > 0:
						_next_stop()
					else:
						_go_queue()
		S.QUEUED, S.AT_REGISTER:
			queue_wait += delta
			if queue_wait > PATIENCE:
				_give_up()

func _go_queue() -> void:
	var best: Node = null
	for r in registers:
		if best == null or r.queue_size() < best.queue_size():
			best = r
	my_register = best
	state = S.QUEUED
	var spot: Vector3 = best.join(self)
	var lx: float = best.lane_x
	var pts := _path_to(Vector3(lx, 0, FRONT_Z))
	pts.append(spot)
	path = pts

func _animate(delta: float) -> void:
	if moving:
		phase += delta * speed * 6.0
		var s := sin(phase) * 0.55
		leg_l.rotation.x = s
		leg_r.rotation.x = -s
		arm_l.rotation.x = -s * 0.7
		arm_r.rotation.x = s * 0.3
	else:
		leg_l.rotation.x = lerp(leg_l.rotation.x, 0.0, minf(1.0, 8 * delta))
		leg_r.rotation.x = lerp(leg_r.rotation.x, 0.0, minf(1.0, 8 * delta))
		arm_r.rotation.x = lerp(arm_r.rotation.x, 0.0, minf(1.0, 8 * delta))
		if not (state == S.SHOP and wait_t > 0.0):
			arm_l.rotation.x = lerp(arm_l.rotation.x, 0.0, minf(1.0, 8 * delta))
