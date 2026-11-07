extends Node3D
## Low-poly human customer with simple waypoint AI.
## States: ENTER -> SHOP -> QUEUED -> AT_REGISTER -> LEAVING.
## Movement is kinematic along aisle/corridor waypoints (see HANDOFF.md), no navmesh.
## Avoids the player and other customers by waiting (with a short timeout for customers).

signal finished(customer, paid: bool)

enum S { ENTER, SHOP, QUEUED, AT_REGISTER, LEAVING }

const AISLES := [-11.0, -8.0, -4.75, 0.0, 4.75, 8.0, 11.0]
const FRONT_Z := 3.0
const BACK_Z := -7.4
const PATIENCE := 150.0

var state := S.ENTER
var path: Array = []
var speed := 1.3
var items: Array = []        # Array of product dictionaries
var stops_left := 3
var wait_t := 0.0
var face_dir := Vector3.ZERO
var registers: Array = []
var game: Node = null
var my_register: Node = null
var queue_wait := 0.0
var phase := 0.0
var moving := false
var annoyed := 0
var blocked_t := 0.0
var _excuse_said := false

var body: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var basket: Node3D
var emote_label: Label3D
var _emote_t := 0.0

const SKINS := [Color(0.96, 0.8, 0.68), Color(0.88, 0.68, 0.52), Color(0.74, 0.54, 0.38), Color(0.56, 0.38, 0.25), Color(0.4, 0.27, 0.18)]
const HAIRS := [Color(0.07, 0.05, 0.04), Color(0.25, 0.15, 0.07), Color(0.45, 0.3, 0.15), Color(0.8, 0.68, 0.42), Color(0.5, 0.5, 0.5), Color(0.5, 0.15, 0.08)]
const TOPS := [Color(0.22, 0.24, 0.27), Color(0.15, 0.2, 0.32), Color(0.45, 0.12, 0.12), Color(0.2, 0.36, 0.25), Color(0.5, 0.48, 0.45), Color(0.6, 0.45, 0.15), Color(0.3, 0.2, 0.38), Color(0.1, 0.1, 0.11), Color(0.55, 0.3, 0.35)]
const PANTS := [Color(0.16, 0.22, 0.36), Color(0.11, 0.11, 0.12), Color(0.36, 0.32, 0.25), Color(0.28, 0.28, 0.3), Color(0.24, 0.27, 0.2), Color(0.25, 0.32, 0.45)]

func _ready() -> void:
	_build_body()
	stops_left = randi_range(2, 4)
	speed = randf_range(1.1, 1.45)
	path = [Vector3(StoreBuilder.DOOR_X, 0, 13.5), Vector3(StoreBuilder.DOOR_X, 0, FRONT_Z)]

func _part(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rough := 0.85) -> MeshInstance3D:
	return StoreBuilder.box(parent, size, pos, StoreBuilder.mat(c, 0.0, rough))

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p

func _build_body() -> void:
	var skin: Color = SKINS.pick_random()
	var hair: Color = HAIRS.pick_random()
	var top: Color = TOPS.pick_random()
	var pants: Color = PANTS.pick_random()
	var hoodie := randf() < 0.65
	var shoe := Color(0.9, 0.9, 0.88) if randf() < 0.5 else Color(0.12, 0.12, 0.12)
	body = Node3D.new()
	body.scale = Vector3(randf_range(0.95, 1.1), randf_range(0.93, 1.06), randf_range(0.95, 1.08))
	add_child(body)
	# legs + sneakers
	leg_l = _pivot(body, Vector3(-0.1, 0.9, 0))
	leg_r = _pivot(body, Vector3(0.1, 0.9, 0))
	for leg in [leg_l, leg_r]:
		_part(leg, Vector3(0.16, 0.44, 0.18), Vector3(0, -0.22, 0), pants)
		_part(leg, Vector3(0.145, 0.4, 0.16), Vector3(0, -0.62, 0), pants)
		_part(leg, Vector3(0.16, 0.08, 0.28), Vector3(0, -0.86, 0.04), shoe)
		_part(leg, Vector3(0.165, 0.03, 0.29), Vector3(0, -0.895, 0.04), Color(0.95, 0.95, 0.95) if shoe.r < 0.5 else Color(0.2, 0.2, 0.2))
	# torso: hips, chest, shoulders
	_part(body, Vector3(0.38, 0.14, 0.22), Vector3(0, 0.96, 0), pants)
	_part(body, Vector3(0.42, 0.52, 0.25), Vector3(0, 1.28, 0), top)
	_part(body, Vector3(0.48, 0.1, 0.26), Vector3(0, 1.5, 0), top)
	if hoodie:
		_part(body, Vector3(0.3, 0.12, 0.01), Vector3(0, 1.12, 0.13), top.darkened(0.2))   # pocket
		_part(body, Vector3(0.34, 0.2, 0.1), Vector3(0, 1.6, -0.13), top.darkened(0.1))    # hood
		for dx in [-0.05, 0.05]:
			_part(body, Vector3(0.015, 0.14, 0.01), Vector3(dx, 1.4, 0.13), Color(0.9, 0.9, 0.9))
	else:
		_part(body, Vector3(0.43, 0.06, 0.255), Vector3(0, 1.04, 0), pants.darkened(0.4))  # belt
	_part(body, Vector3(0.1, 0.08, 0.1), Vector3(0, 1.58, 0), skin)  # neck
	# head with simple face
	var head := _pivot(body, Vector3(0, 1.73, 0))
	_part(head, Vector3(0.21, 0.25, 0.23), Vector3.ZERO, skin)
	for ex in [-0.11, 0.11]:
		_part(head, Vector3(0.03, 0.06, 0.05), Vector3(ex, 0.0, 0), skin.darkened(0.06))   # ears
	_part(head, Vector3(0.04, 0.06, 0.04), Vector3(0, -0.02, 0.125), skin.darkened(0.08))  # nose
	for ex in [-0.05, 0.05]:
		_part(head, Vector3(0.035, 0.03, 0.01), Vector3(ex, 0.025, 0.116), Color(0.95, 0.95, 0.95))
		_part(head, Vector3(0.018, 0.022, 0.01), Vector3(ex, 0.025, 0.121), Color(0.06, 0.05, 0.05))
		_part(head, Vector3(0.05, 0.012, 0.01), Vector3(ex, 0.06, 0.117), hair.darkened(0.2))  # brows
	_part(head, Vector3(0.07, 0.014, 0.01), Vector3(0, -0.075, 0.116), Color(0.45, 0.2, 0.18))  # mouth
	if randf() < 0.3 and skin.v > 0.5:
		_part(head, Vector3(0.18, 0.06, 0.02), Vector3(0, -0.1, 0.11), hair)   # beard
	var style := randi() % 5
	match style:
		0:  # short
			_part(head, Vector3(0.225, 0.07, 0.245), Vector3(0, 0.13, -0.005), hair)
			_part(head, Vector3(0.225, 0.16, 0.05), Vector3(0, 0.06, -0.105), hair)
		1:  # long
			_part(head, Vector3(0.23, 0.08, 0.25), Vector3(0, 0.13, -0.005), hair)
			_part(head, Vector3(0.24, 0.4, 0.07), Vector3(0, -0.06, -0.11), hair)
			for sx in [-0.115, 0.115]:
				_part(head, Vector3(0.03, 0.26, 0.17), Vector3(sx, 0.0, -0.03), hair)
		2:  # cap
			var cap_c: Color = TOPS.pick_random()
			_part(head, Vector3(0.235, 0.08, 0.25), Vector3(0, 0.15, 0), cap_c)
			_part(head, Vector3(0.2, 0.02, 0.12), Vector3(0, 0.12, 0.17), cap_c)
			_part(head, Vector3(0.225, 0.1, 0.05), Vector3(0, 0.05, -0.105), hair)
		3:  # hood up (or buzz cut)
			if hoodie:
				_part(head, Vector3(0.26, 0.3, 0.27), Vector3(0, 0.03, -0.03), top.darkened(0.1))
				_part(head, Vector3(0.2, 0.22, 0.02), Vector3(0, 0.0, 0.11), skin)
			else:
				_part(head, Vector3(0.222, 0.03, 0.24), Vector3(0, 0.125, 0), hair)
		_:  # curly / tall top
			_part(head, Vector3(0.25, 0.12, 0.26), Vector3(0, 0.15, -0.01), hair)
			_part(head, Vector3(0.25, 0.15, 0.06), Vector3(0, 0.05, -0.11), hair)
	# arms with hands
	arm_l = _pivot(body, Vector3(-0.28, 1.5, 0))
	arm_r = _pivot(body, Vector3(0.28, 1.5, 0))
	for arm in [arm_l, arm_r]:
		_part(arm, Vector3(0.11, 0.32, 0.12), Vector3(0, -0.16, 0), top)
		_part(arm, Vector3(0.1, 0.28, 0.11), Vector3(0, -0.45, 0), top if hoodie else skin)
		_part(arm, Vector3(0.08, 0.1, 0.09), Vector3(0, -0.63, 0), skin)
	# red shopping basket in the right hand
	basket = _pivot(arm_r, Vector3(0.05, -0.7, 0.0))
	var red := Color(0.75, 0.1, 0.1)
	_part(basket, Vector3(0.22, 0.02, 0.36), Vector3(0, -0.22, 0), red)
	for sx in [-0.11, 0.11]:
		_part(basket, Vector3(0.015, 0.16, 0.36), Vector3(sx, -0.14, 0), red)
	for sz in [-0.18, 0.18]:
		_part(basket, Vector3(0.22, 0.16, 0.015), Vector3(0, -0.14, sz), red)
	_part(basket, Vector3(0.02, 0.02, 0.2), Vector3(0, -0.02, 0), Color(0.2, 0.2, 0.2))
	basket.visible = false
	emote_label = Label3D.new()
	emote_label.position = Vector3(0, 2.15, 0)
	emote_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	emote_label.font_size = 40
	emote_label.pixel_size = 0.004
	emote_label.outline_size = 8
	emote_label.visible = false
	add_child(emote_label)
	# Collider so the player bumps into customers
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.88
	sb.add_child(cs)
	add_child(sb)

func emote(text: String, c := Color(1, 0.4, 0.3), secs := 2.5) -> void:
	emote_label.text = text
	emote_label.modulate = c
	emote_label.visible = true
	_emote_t = secs

func _add_item_to_basket(p: Dictionary) -> void:
	basket.visible = true
	items.append(p)
	var n := items.size() - 1
	var s: Vector3 = p.size * 0.6
	var m := _part(basket, s, Vector3(-0.05 + (n % 2) * 0.1, -0.21 + s.y * 0.5 + int(n / 4) * 0.06, -0.12 + (n / 2 % 2) * 0.16), p.color)
	m.name = "Item%d" % n

func clear_basket() -> void:
	for c in basket.get_children():
		if String(c.name).begins_with("Item"):
			c.queue_free()
	basket.visible = false

# ---------- routing ----------
func _route(from: Vector3, to: Vector3) -> Array:
	# Walk only along aisle centers (AISLES x) and the two cross corridors (FRONT_Z, BACK_Z).
	var on_from_corr := absf(from.z - FRONT_Z) < 0.1 or absf(from.z - BACK_Z) < 0.1
	if on_from_corr and absf(from.z - to.z) < 0.1:
		return [to]
	if absf(from.x - to.x) < 0.05 and (_is_aisle(from.x) or absf(from.x) < 2.0):
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

var _stop_row := -1
var _stop_side := 0

func _next_stop() -> void:
	var target: Vector3
	_stop_row = -1
	if randf() < 0.25:
		target = Vector3(randf_range(-3.4, 3.4), 0, StoreBuilder.ZB + 2.0)
		face_dir = Vector3(0, 0, -1)
	else:
		var ax: float = AISLES.pick_random()
		var side := 1.0 if ax < -10 else (-1.0 if ax > 10 else (1.0 if randf() < 0.5 else -1.0))
		face_dir = Vector3(side, 0, 0)
		var shelf_x := _nearest_shelf(ax + side * 1.5)
		_stop_row = StoreBuilder.SHELF_X.find(shelf_x)
		_stop_side = -int(side)
		if absf(ax) < 0.1:
			ax = side * 1.7   # wide center aisle: walk up close to the shelf
		target = Vector3(ax, 0, randf_range(StoreBuilder.SHELF_Z0 + 0.6, 0.0))
	path = _path_to(target)

func _nearest_shelf(x: float) -> float:
	var best: float = StoreBuilder.SHELF_X[0]
	for s in StoreBuilder.SHELF_X:
		if absf(s - x) < absf(best - x):
			best = s
	return best

func _path_to(target: Vector3) -> Array:
	if position.z < BACK_Z - 0.5:  # at the freezer: step back into the back corridor first
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

## Decide how to pay a total (in cents). Returns {"method": "cash"/"card", "cash": cents}.
func choose_payment(total: int) -> Dictionary:
	if randf() < 0.3:
		return {"method": "card", "cash": 0}
	var opts: Array = []
	for step in [100, 500, 1000, 2000]:
		var v: int = int(ceil(total / float(step))) * step
		if v > total and not opts.has(v):
			opts.append(v)
	if total > 1500:
		opts.append(int(ceil(total / 2000.0)) * 2000 + 2000)
	if opts.is_empty() or randf() < 0.1:
		return {"method": "cash", "cash": total}
	return {"method": "cash", "cash": opts.pick_random()}

func pay_and_leave(mood := "") -> void:
	state = S.LEAVING
	clear_basket()
	if mood != "":
		emote(mood, Color(0.5, 1, 0.6) if mood.begins_with("Thanks") else Color(1, 0.4, 0.3))
	var lx := position.x
	path = [Vector3(lx, 0, 10.3), Vector3(StoreBuilder.DOOR_X, 0, 10.3), Vector3(StoreBuilder.DOOR_X, 0, 18.0), Vector3(StoreBuilder.DOOR_X + randf_range(-3, 3), 0, 27.0)]
	finished.emit(self, true)

func _give_up(reason := "Forget this...") -> void:
	if my_register:
		my_register.leave(self)
	state = S.LEAVING
	clear_basket()
	emote(reason)
	path = _path_to(Vector3(StoreBuilder.DOOR_X, 0, FRONT_Z))
	path.append_array([Vector3(StoreBuilder.DOOR_X, 0, 18.0), Vector3(StoreBuilder.DOOR_X + randf_range(-3, 3), 0, 27.0)])
	finished.emit(self, false)

# ---------- update ----------
func _blocked(dir: Vector3) -> bool:
	if game == null:
		return false
	var others: Array = [game.player]
	others.append_array(game.customers_root.get_children())
	for o in others:
		if o == self or not is_instance_valid(o):
			continue
		var rel: Vector3 = o.global_position - global_position
		rel.y = 0
		var ahead := rel.dot(dir)
		var lateral := (rel - dir * ahead).length()
		if ahead > 0.05 and ahead < 0.85 and lateral < 0.45:
			if o == game.player:
				return true
			# Customers: queue members never push through each other; others give up after 1.5 s.
			if blocked_t < 1.5 or state == S.QUEUED:
				return true
	return false

func _process(delta: float) -> void:
	moving = false
	if _emote_t > 0.0:
		_emote_t -= delta
		if _emote_t <= 0.0:
			emote_label.visible = false
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
			if _blocked(dir):
				blocked_t += delta
				if blocked_t > 3.0 and not _excuse_said and game and game.player.global_position.distance_to(global_position) < 1.2:
					_excuse_said = true
					emote("Excuse me!", Color(1, 0.9, 0.5))
			else:
				blocked_t = 0.0
				_excuse_said = false
				position += dir * step
				moving = true
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 10 * delta))
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
		S.QUEUED:
			face_dir = Vector3(0, 0, 1)
			if my_register and my_register.is_front(self):
				state = S.AT_REGISTER
				face_dir = Vector3(signf(my_register.counter_x - position.x), 0, 0)
				my_register.customer_at_front(self)
		S.LEAVING:
			queue_free()

func _grab() -> void:
	for k in randi_range(1, 2):
		if _stop_row < 0:   # freezer never runs out
			_add_item_to_basket(Products.CATALOG[Products.FROZEN_ITEMS.pick_random()])
			continue
		var got: Dictionary = game.shelves.take(_stop_row, _stop_side, position.z) if game else Products.random()
		if got.has("missing"):
			annoyed += 1
			queue_wait += 20.0
			emote("Out of %s?!" % got.missing.name)
			if game:
				game.on_out_of_stock(got.missing)
			break
		_add_item_to_basket(got)

func _idle(delta: float) -> void:
	match state:
		S.SHOP:
			if wait_t > 0.0:
				wait_t -= delta
				arm_l.rotation.x = lerp(arm_l.rotation.x, -1.6, minf(1.0, 6 * delta))  # reach
				if wait_t <= 0.0:
					_grab()
					stops_left -= 1
					if stops_left > 0:
						_next_stop()
					elif items.is_empty():
						_give_up("Nothing I wanted...")
					else:
						_go_queue()
		S.QUEUED, S.AT_REGISTER:
			queue_wait += delta
			if queue_wait > PATIENCE:
				_give_up("Too slow!")

func _go_queue() -> void:
	var best: Node = null
	for r in registers:
		if best == null or r.queue_size() < best.queue_size():
			best = r
	my_register = best
	state = S.QUEUED
	var spot: Vector3 = best.join(self)
	var pts := _path_to(Vector3(best.lane_x, 0, FRONT_Z))
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
		var w := minf(1.0, 8 * delta)
		leg_l.rotation.x = lerp(leg_l.rotation.x, 0.0, w)
		leg_r.rotation.x = lerp(leg_r.rotation.x, 0.0, w)
		arm_r.rotation.x = lerp(arm_r.rotation.x, 0.0, w)
		if not (state == S.SHOP and wait_t > 0.0):
			arm_l.rotation.x = lerp(arm_l.rotation.x, 0.0, w)
