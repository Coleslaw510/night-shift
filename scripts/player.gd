extends CharacterBody3D
## First-person controller: WASD, mouse look, Shift sprint, Space jump, E/click interact
## (hold for stocking). Carry one thing: {"kind": "stock", "product": idx, "count": n}
## or {"kind": "trash"}. USE on a matching shelf slots it; otherwise USE or Q sets it
## down on the floor. Items never teleport back to where they came from.

signal prompt_changed(text: String)
signal carry_changed(carrying: Dictionary)

const WALK := 3.2
const SPRINT := 5.6
const JUMP := 4.2
const REACH := 2.6
const BOX_UNITS := 12
var base_sens := 0.0025
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var cam: Camera3D
var ray: RayCast3D
var _last_prompt := ""
var controls_enabled := true
var carrying: Dictionary = {}
var viewmodel: Node3D
var carry_node: Node3D
var _bob := 0.0
var touch_mode := false          # set by game.gd on phones/tablets
var touch_move := Vector2.ZERO   # from the virtual joystick
var sprint_toggle := false
var holding_cart: Node3D = null
var near_cart: Node3D = null
var riding: Node3D = null
var sleeve_mat: StandardMaterial3D
var flash: SpotLight3D
var has_light := false
var stamina := 100.0
var stamina_max := 100.0
var unlimited_sprint := true
var boost_t := 0.0
var has_gun := false
var gun_out := false
var gun_node: Node3D
var muzzle: MeshInstance3D
var muzzle_light: OmniLight3D
var _muzzle_t := 0.0
const MAG := 6

func _ready() -> void:
	Settings.load_settings()
	if not InputMap.has_action("cart"):
		InputMap.add_action("cart")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_C
		InputMap.action_add_event("cart", ev)
	if not InputMap.has_action("flashlight"):
		InputMap.add_action("flashlight")
		var fl := InputEventKey.new()
		fl.physical_keycode = KEY_F
		InputMap.action_add_event("flashlight", fl)
	if not InputMap.has_action("snack"):
		InputMap.add_action("snack")
		var sn := InputEventKey.new()
		sn.physical_keycode = KEY_1
		InputMap.action_add_event("snack", sn)
	if not InputMap.has_action("gun"):
		InputMap.add_action("gun")
		var gn := InputEventKey.new()
		gn.physical_keycode = KEY_G
		InputMap.action_add_event("gun", gn)
	if not InputMap.has_action("reload"):
		InputMap.add_action("reload")
		var rl := InputEventKey.new()
		rl.physical_keycode = KEY_R
		InputMap.action_add_event("reload", rl)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.62
	cam.fov = 66
	cam.near = 0.03
	add_child(cam)
	cam.current = true
	flash = SpotLight3D.new()
	flash.light_color = Color(1.0, 0.96, 0.85)
	flash.light_energy = 3.2
	flash.spot_range = 18.0
	flash.spot_angle = 26.0
	flash.visible = false
	cam.add_child(flash)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collide_with_areas = true
	ray.add_exception(self)
	cam.add_child(ray)
	_build_viewmodel()

func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.position = Vector3(0.27, -0.31, -0.55)
	cam.add_child(viewmodel)
	var skin := StoreBuilder.mat(Color(0.86, 0.64, 0.47), 0.0, 0.8)
	sleeve_mat = StoreBuilder.mat(Color(0.16, 0.28, 0.22), 0.0, 0.9).duplicate()
	var arm := Node3D.new()
	arm.rotation = Vector3(0.18, 0.42, -0.1)
	viewmodel.add_child(arm)
	StoreBuilder.box(arm, Vector3(0.12, 0.12, 0.5), Vector3(0.07, -0.13, 0.32), sleeve_mat)
	StoreBuilder.box(arm, Vector3(0.095, 0.095, 0.26), Vector3(0.04, -0.09, 0.05), skin)     # forearm
	StoreBuilder.box(arm, Vector3(0.12, 0.12, 0.12), Vector3(0.0, -0.04, -0.09), skin)       # fist
	for k in 3:
		StoreBuilder.box(arm, Vector3(0.03, 0.032, 0.03), Vector3(-0.065, -0.005 - k * 0.036, -0.12), skin)
	StoreBuilder.box(arm, Vector3(0.035, 0.03, 0.07), Vector3(-0.05, 0.03, -0.1), skin)    # thumb
	carry_node = Node3D.new()
	carry_node.position = Vector3(-0.2, -0.05, -0.15)
	viewmodel.add_child(carry_node)
	_build_gun(arm)

func set_carry(d: Dictionary) -> void:
	carrying = d
	for c in carry_node.get_children():
		c.queue_free()
	match d.get("kind", ""):
		"stock":
			var p: Dictionary = Products.CATALOG[d.product]
			var b := StoreBuilder.box(carry_node, Vector3(0.5, 0.34, 0.36), Vector3(0, -0.08, -0.2), StoreBuilder.mat(Color(0.56, 0.42, 0.26), 0.0, 0.95))
			StoreBuilder.box(b, Vector3(0.3, 0.12, 0.01), Vector3(0, 0.02, 0.181), StoreBuilder.mat(p.color))
			StoreBuilder.box(b, Vector3(0.51, 0.04, 0.08), Vector3(0, 0.17, 0), StoreBuilder.mat(Color(0.7, 0.6, 0.42)))
		"trash":
			var bag := StoreBuilder.box(carry_node, Vector3(0.36, 0.42, 0.32), Vector3(0.02, -0.18, -0.15), StoreBuilder.mat(Color(0.04, 0.04, 0.05), 0.0, 0.25))
			bag.rotation = Vector3(0.1, 0.4, 0.15)
			StoreBuilder.box(carry_node, Vector3(0.08, 0.1, 0.08), Vector3(0.02, 0.06, -0.15), StoreBuilder.mat(Color(0.04, 0.04, 0.05), 0.0, 0.25))
	carry_changed.emit(carrying)

func use_stock_unit() -> void:
	if carrying.get("kind", "") != "stock":
		return
	carrying.count -= 1
	_play("place")
	if carrying.count <= 0:
		set_carry({})
	else:
		carry_changed.emit(carrying)

func _build_gun(arm: Node3D) -> void:
	gun_node = Node3D.new()
	gun_node.position = Vector3(-0.02, 0.02, -0.12)
	gun_node.visible = false
	arm.add_child(gun_node)
	var metal := StoreBuilder.mat(Color(0.12, 0.12, 0.13), 0.0, 0.35, 0.75)
	var wood := StoreBuilder.mat(Color(0.42, 0.24, 0.12), 0.0, 0.6)
	StoreBuilder.box(gun_node, Vector3(0.07, 0.08, 0.55), Vector3(0, 0.02, -0.2), metal)
	StoreBuilder.box(gun_node, Vector3(0.06, 0.14, 0.16), Vector3(0, -0.06, 0.02), wood)
	StoreBuilder.box(gun_node, Vector3(0.05, 0.1, 0.08), Vector3(0, -0.08, -0.08), wood)
	muzzle = StoreBuilder.box(gun_node, Vector3(0.08, 0.08, 0.04), Vector3(0, 0.02, -0.5), StoreBuilder.mat(Color(1, 0.7, 0.2), 6.0))
	muzzle.visible = false
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1, 0.75, 0.35)
	muzzle_light.light_energy = 4.0
	muzzle_light.omni_range = 4.5
	muzzle_light.position = Vector3(0, 0.02, -0.55)
	muzzle_light.visible = false
	gun_node.add_child(muzzle_light)

func set_gun_out(on: bool) -> void:
	if not has_gun:
		return
	if on and not carrying.is_empty():
		return
	gun_out = on
	gun_node.visible = on
	_refresh_gun_hud()

func _refresh_gun_hud() -> void:
	var g := get_parent()
	if g == null or g.hud == null:
		return
	if gun_out:
		g.hud.set_status("SHOTGUN", "%d / %d" % [int(g.mag_ammo), int(g.ammo)], int(g.mag_ammo) > 0)
	elif carrying.is_empty():
		g.hud.set_status("", "")

func _fire() -> void:
	var g := get_parent()
	if g == null or not gun_out or _muzzle_t > 0.0:
		return
	if int(g.mag_ammo) <= 0:
		_play("click")
		return
	g.mag_ammo = int(g.mag_ammo) - 1
	_muzzle_t = 0.05
	muzzle.visible = true
	muzzle_light.visible = true
	_play("gunshot")
	_refresh_gun_hud()
	var space := get_world_3d().direct_space_state
	var dir := -cam.global_transform.basis.z
	var from := cam.global_position
	var to := from + dir * 45.0
	var exclude: Array = [self]
	for _i in 8:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		var col: Object = hit.collider
		if _is_customer(col):
			var cn := col as Node
			while cn and not cn.has_method("hit"):
				cn = cn.get_parent()
			if cn and cn.has_method("hit"):
				cn.hit()
				g.hud.toast("Hit")
			return
		if col.has_method("hit"):
			col.hit()
			g.hud.toast("Ping")
		return

func _is_customer(n: Object) -> bool:
	var node := n as Node
	while node:
		if node is Customer:
			return true
		node = node.get_parent()
	return false

func _reload() -> void:
	var g := get_parent()
	if g == null or not has_gun:
		return
	var need := MAG - int(g.mag_ammo)
	if need <= 0 or int(g.ammo) <= 0:
		return
	var take := mini(need, int(g.ammo))
	g.ammo = int(g.ammo) - take
	g.mag_ammo = int(g.mag_ammo) + take
	_play("reload")
	_refresh_gun_hud()

func set_vest(c: Color) -> void:
	if sleeve_mat:
		sleeve_mat.albedo_color = c

func eat_boost() -> void:
	stamina = stamina_max
	boost_t = 40.0

func _toggle_light() -> void:
	var g := get_parent()
	if g and g.has_method("has_flashlight") and not g.has_flashlight() and not has_light:
		return
	has_light = true
	flash.visible = not flash.visible

func drop_carried() -> void:
	if carrying.is_empty():
		return
	var d := carrying.duplicate(true)
	var ahead := -global_transform.basis.z
	ahead.y = 0
	if ahead.length() < 0.01:
		ahead = Vector3(0, 0, -1)
	var pos := global_position + ahead.normalized() * 0.75
	pos.y = 0.4
	set_carry({})
	var item := preload("res://scripts/dropped_item.gd").new()
	var root := get_parent()
	if root:
		root.add_child(item)
		item.setup(d, pos)
	_play("place")

func _valid_place(t: Node) -> bool:
	if t == null or not ("tag" in t) or not (t.tag is Dictionary):
		return false
	var kind := str(t.tag.get("kind", ""))
	if carrying.get("kind", "") == "stock" and kind == "shelf" and t.target and t.target.has_method("_player_slot"):
		var i: int = t.target._player_slot(t, self)
		if i < 0:
			return false
		var s: Dictionary = t.target.slots[i]
		return int(s.product) == int(carrying.product) and int(s.count) < int(s.cap)
	if carrying.get("kind", "") == "trash" and kind == "dumpster":
		return true
	return false

func _play(sfx: String) -> void:
	var g := get_parent()
	if g and g.has_method("play_sfx"):
		g.play_sfx(sfx)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := base_sens * Settings.mouse_sens
		rotate_y(-event.relative.x * s)
		cam.rotate_x(-event.relative.y * s)
		cam.rotation.x = clamp(cam.rotation.x, -1.45, 1.45)
	elif event.is_action_pressed("interact"):
		if not touch_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var g := get_parent()
		if g and g.has_method("fuel_is_running") and g.fuel_is_running():
			g.fuel_stop()
			return
		var t := _target()
		if gun_out and (t == null or not _keeps_interact(t)):
			_fire()
			return
		if not carrying.is_empty():
			if _valid_place(t):
				t.interact(self)
			else:
				drop_carried()
			return
		if t:
			t.interact(self)
	elif event.is_action_pressed("drop"):
		drop_carried()
	elif event.is_action_pressed("cart"):
		toggle_cart(null)
	elif event.is_action_pressed("flashlight"):
		_toggle_light()
	elif event.is_action_pressed("snack"):
		var g := get_parent()
		if g and g.has_method("eat_snack"):
			g.eat_snack()
	elif event.is_action_pressed("gun"):
		set_gun_out(not gun_out)
	elif event.is_action_pressed("reload"):
		_reload()
	elif event.is_action_pressed("fire"):
		_fire()

func touch_look(rel: Vector2) -> void:
	if not controls_enabled:
		return
	rotate_y(-rel.x)
	cam.rotate_x(-rel.y)
	cam.rotation.x = clamp(cam.rotation.x, -1.45, 1.45)

func toggle_cart(which: Node3D) -> void:
	if holding_cart:
		holding_cart.release()
		holding_cart = null
		return
	if not carrying.is_empty():
		return
	var cart: Node3D = which if which != null else near_cart
	if cart == null or not is_instance_valid(cart):
		return
	if cart.mode == Cart.M.FOLLOW:
		return
	if cart.mode == Cart.M.PARKED:
		cart.release()
	cart.hold(self)
	holding_cart = cart

func _keeps_interact(t: Node) -> bool:
	if not ("tag" in t) or not (t.tag is Dictionary):
		return t.has_method("interact")
	var kind := str(t.tag.get("kind", ""))
	return kind in ["register", "shelf", "crate", "can", "dumpster", "back_door", "freezer", "terminal", "locker"]

func _push_carts() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n: Object = col.get_collider()
		if n is Cart and n.mode == Cart.M.FREE and n != holding_cart:
			n.apply_central_impulse(-col.get_normal() * 1.6)
			n.touched_by_player = true

func _ride(delta: float) -> void:
	if holding_cart or not is_inside_tree():
		riding = null
		return
	var on: Node3D = null
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.4, 0), global_position + Vector3(0, -0.6, 0))
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and hit.collider is Cart and hit.collider.mode == Cart.M.FREE and global_position.y > 0.2:
		on = hit.collider
	riding = on
	if riding == null:
		return
	riding.touched_by_player = true
	riding.freeze = false
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back") + touch_move
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	if dir.length() > 0.1:
		riding.apply_central_force(dir.normalized() * 220.0)
		riding.angular_velocity.y = 0
	# stay in the basket while the cart rolls
	var flat: Vector3 = riding.global_position
	global_position.x = lerpf(global_position.x, flat.x, minf(1.0, 8.0 * delta))
	global_position.z = lerpf(global_position.z, flat.z, minf(1.0, 8.0 * delta))

func _nearest_cart() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := 1.7
	for c in get_tree().get_nodes_in_group("cart"):
		if c.mode == Cart.M.FOLLOW:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d < best_d:
			best = c
			best_d = d
	return best

func _target() -> Node:
	if not ray.is_colliding():
		return null
	var n: Node = ray.get_collider()
	while n and not n.has_method("interact"):
		n = n.get_parent()
		if n is Viewport:
			return null
	return n

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var dir := Vector3.ZERO
	if controls_enabled:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back") + touch_move
		inp = inp.limit_length(1.0)
		dir = (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP
		if Input.is_action_pressed("interact") and (touch_mode or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
			var ht := _target()
			if ht and ht.has_method("hold_interact"):
				ht.hold_interact(self, delta)
	if boost_t > 0.0:
		boost_t -= delta
	var want_sprint := Input.is_action_pressed("sprint") or sprint_toggle
	var sprinting := want_sprint
	if unlimited_sprint:
		stamina = stamina_max
	else:
		if sprinting:
			stamina = maxf(0.0, stamina - 22.0 * delta)
		else:
			stamina = minf(stamina_max, stamina + 14.0 * delta)
			sprinting = sprinting and stamina > 6.0
	var spd := (SPRINT * (1.18 if boost_t > 0.0 else 1.0)) if sprinting else WALK
	velocity.x = move_toward(velocity.x, dir.x * spd, 40 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 40 * delta)
	move_and_slide()
	_push_carts()
	_ride(delta)
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.5 and is_on_floor():
		_bob += delta * hs * 2.6
	cam.position.y = 1.62 + sin(_bob * 2.0) * 0.025
	viewmodel.position = Vector3(0.27 + cos(_bob) * 0.008, -0.31 + absf(sin(_bob)) * 0.01, -0.55)
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
		if _muzzle_t <= 0.0 and muzzle:
			muzzle.visible = false
			muzzle_light.visible = false
	if gun_node:
		gun_node.visible = gun_out and carrying.is_empty()
		if not carrying.is_empty():
			gun_out = false
	near_cart = holding_cart if holding_cart != null else _nearest_cart()
	var p := ""
	var t := _target()
	if t and t.has_method("get_prompt"):
		p = t.get_prompt(self)
	if p == "" and near_cart and near_cart.has_method("get_prompt"):
		p = near_cart.get_prompt(self)
	var g2 := get_parent()
	if g2 and g2.hud:
		g2.hud.set_stamina(stamina / stamina_max, boost_t > 0.0)
	if p != _last_prompt:
		_last_prompt = p
		prompt_changed.emit(p)
