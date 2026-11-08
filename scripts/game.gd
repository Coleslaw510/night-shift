extends Node3D
## Main game controller: builds the store, shelves, HUD, player, registers; spawns customers;
## runs the shift clock (10 PM -> 6 AM), doors, trash, stock hints and the end-of-shift summary.

const VERSION := "1.5.0"
const SHIFT_START_MIN := 22 * 60          # 10:00 PM
const SHIFT_LENGTH_MIN := 8 * 60          # until 6:00 AM
const SHIFT_REAL_SECONDS := 600.0         # ~10 real minutes per shift
const MAX_CUSTOMERS := 7
const TRASH_FILL_SECONDS := 150.0         # empty -> full with no customers
const TRASH_BONUS := 150                  # cents for taking a bag out
const CART_PAY := 75                      # cents for a returned stray cart
const BOX_UNITS := 12
const MILK_PRODUCT := 12
const MILK_ORDER_TOTAL := 8
const MILK_ORDER_REWARD := 300

var store := {}
var shelves: ShelfSystem
var hud: CanvasLayer
var player: CharacterBody3D
var registers: Array = []
var customers_root: Node3D
var cars_root: Node3D
var fuel_people_root: Node3D
var fuel_job: Dictionary = {}
var _spot_owner := {}
var _pump_owner := {}
var shift_over := false
var elapsed := 0.0
var spawned := 0
var spawn_t := 3.0
var trash := 0.35
var back_door_open := false
var freezer_open := false
var freezer_stock := {}
var milk_supply_boxes := 4
var milk_order_progress := 0
var milk_customer_claimed := false
var milk_customer_served := false
var complaint_level := 0.0
var clown_triggered := false
var driving_car: Node = null
var criminals_stopped := 0
var criminals_escaped := 0
var vehicle_exit_lock := 0.0
var driving_camera: Camera3D = null
var driving_cam_yaw := 0.0
var driving_cam_pitch := 0.0
var fuel_pedestrians := {}
var front_open := 0.0
var _hint_t := 0.0
var _cull_t := 0.0
var _shelf_cull := 0.0
var _change_reg: Node = null
var _sfx: Array = []
var touch_mode := false
var stats := {"earnings": 0, "tips": 0, "served": 0, "walked": 0, "stocked": 0, "oos": 0, "change_ok": 0, "change_bad": 0, "trash": 0, "carts": 0, "fuel": 0}
var cart_pay_mult := 1.0
var owned := {}
var ammo := 0
var snacks := 0
var vest := ""
var shop_from_pause := false
var shifts_done := 0
var play_seconds := 0.0
var mag_ammo := 0
var monster: Node = null
var monster_t := 0.0
var sim_mode := false
var allow_spawn := true
var cars_departed := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	Economy.load_data()
	for pidx in Products.FROZEN_ITEMS:
		freezer_stock[int(pidx)] = 8
	# Start the tutorial product partially depleted so the first job is meaningful.
	freezer_stock[MILK_PRODUCT] = 2
	touch_mode = is_touch()
	if touch_mode:
		_setup_mobile()
	store = StoreBuilder.build(self, self)
	shelves = ShelfSystem.new()
	add_child(shelves)
	shelves.build()
	shelves.stocked.connect(func(_p): stats.stocked += 1)
	_spawn_carts()
	for lane in store.lanes:
		var r = preload("res://scripts/register.gd").new()
		r.name = "Register%d" % (lane.index + 1)
		r.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(r)
		r.setup(lane, self)
		r.paid.connect(_on_paid)
		registers.append(r)
	customers_root = Node3D.new()
	customers_root.name = "Customers"
	customers_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(customers_root)
	cars_root = Node3D.new()
	cars_root.name = "Cars"
	cars_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(cars_root)
	fuel_people_root = Node3D.new()
	fuel_people_root.name = "FuelCustomers"
	fuel_people_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fuel_people_root)
	_spawn_ambient_cars()
	hud = preload("res://scripts/hud.gd").new()
	hud.touch_mode = touch_mode
	add_child(hud)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.menu_pressed.connect(_to_menu)
	hud.change_confirmed.connect(_on_change_confirmed)
	hud.change_cancelled.connect(close_change)
	hud.shop_buy.connect(try_buy)
	hud.shop_eat.connect(eat_snack)
	hud.shop_closed.connect(close_shop)
	player = preload("res://scripts/player.gd").new()
	player.name = "Player"
	player.position = Vector3(6.6, 0.05, 15.4)
	player.rotation.y = PI * 0.5
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.touch_mode = touch_mode
	# Every employee starts with the pistol; it is not a shop unlock.
	player.has_gun = true
	ammo = 32
	mag_ammo = 32
	player.prompt_changed.connect(hud.set_prompt)
	player.carry_changed.connect(_on_carry_changed)
	if NetworkSession.active:
		_setup_multiplayer()
	for i in 6:
		var a := AudioStreamPlayer.new()
		a.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(a)
		_sfx.append(a)
	var hum := AudioStreamPlayer.new()
	hum.stream = Sfx.get_stream("hum")
	hum.volume_db = -26.0
	hum.autoplay = true
	add_child(hum)
	capture_mouse(true)
	if touch_mode:
		var tc := TouchControls.new()
		tc.game = self
		tc.player = player
		add_child(tc)
	hud.toast("Check the order board, then take the milk box from the backroom pallet.", 6.0)
	_update_order_board()
	_spawn_targets()
	if SaveGame.boot_mode == "continue":
		_apply_save(SaveGame.read())
	SaveGame.boot_mode = ""
	_update_clock()
	_update_hints()
	Settings.bind(self)
	apply_graphics()

## Touch mode: phones/tablets, or desktop testing with `godot -- --touch`.
static func is_touch() -> bool:
	return OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")

func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (on and not touch_mode) else Input.MOUSE_MODE_VISIBLE

## Phones don't use the mouse-click binding, so a tap doesn't also press USE.
## Resolution, lights, and the FPS cap come from the graphics preset.
func _setup_mobile() -> void:
	InputMap.action_erase_events("interact")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	InputMap.action_add_event("interact", e)

func play_sfx(name: String) -> void:
	for a in _sfx:
		if not a.playing:
			a.stream = Sfx.get_stream(name)
			a.play()
			return

func toast(t: String) -> void:
	hud.toast(t)

func _process(delta: float) -> void:
	if get_tree().paused or shift_over:
		return
	if driving_car and is_instance_valid(driving_car):
		vehicle_exit_lock = maxf(0.0, vehicle_exit_lock - delta)
		player.global_position = driving_car.global_position + Vector3(0, 1.0, 0)
		if driving_camera:
			_update_driving_camera()
		if vehicle_exit_lock <= 0.0 and Input.is_action_just_pressed("interact"):
			exit_vehicle()
		return
	play_seconds += delta
	if NetworkSession.active and player:
		NetworkSession.submit_pose(player.global_position, player.rotation.y)
	_flicker()
	_doors(delta)
	elapsed += delta
	_update_clock()
	trash = minf(trash + delta / TRASH_FILL_SECONDS, 1.2)
	_collect_stray_carts()
	_run_fuel(delta)
	_update_can()
	_recover_registers()
	_cull_t -= delta
	if _cull_t <= 0.0 and player:
		_cull_t = 0.35
		shelves.update_cull(player.global_position.x, _shelf_cull)
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 0.5
		_update_hints()
	monster_t += delta
	# Neglected shelves, freezer stock, trash, and unhappy customers build pressure.
	if shelves and shelves.total_fill() < 0.38:
		complaint_level += delta * 0.025
	if trash > 0.8:
		complaint_level += delta * 0.01
	if monster == null and not clown_triggered and complaint_level >= 10.0 and elapsed >= 35.0:
		_spawn_monster()
	if elapsed >= SHIFT_REAL_SECONDS:
		end_shift()
		return
	spawn_t -= delta
	if allow_spawn and spawn_t <= 0.0 and elapsed < SHIFT_REAL_SECONDS * 0.95:
		spawn_t = randf_range(10.0, 22.0)
		if customers_root.get_child_count() < MAX_CUSTOMERS:
			if randf() < 0.55 and _free_pump() != null:
				spawn_fuel_car()
			else:
				spawn_customer()

func _spawn_monster() -> void:
	if monster != null:
		return
	monster = preload("res://scripts/monster.gd").new()
	monster.name = "TheBackroomThing"
	add_child(monster)
	var spawn_out_back := randf() < 0.35
	monster.global_position = Vector3(randf_range(-16.0, 16.0), 0, -47.0 if spawn_out_back else randf_range(-39.0, -20.0))
	monster.setup(self, player)
	clown_triggered = true
	# No warning text: the player hears the arrival and has to notice it.
	play_sfx("error")
	play_sfx("thud")

func monster_attack(_m: Node) -> void:
	if player == null or shift_over:
		return
	hud.toast("RUN. It found you.", 3.0)
	stats.earnings = maxi(0, int(stats.earnings) - 100)
	hud.set_money(stats.earnings)
	player.global_position = Vector3(6.6, 0.05, 15.4)

func take_freezer_item(product_idx: int) -> Dictionary:
	var left := int(freezer_stock.get(product_idx, 0))
	if left <= 0:
		return {"missing": Products.CATALOG[product_idx]}
	freezer_stock[product_idx] = left - 1
	return Products.CATALOG[product_idx]

func enter_vehicle(car: Node) -> void:
	if driving_car or car == null or car.vstate != Vehicle.V.PARKED:
		return
	if car.driver and is_instance_valid(car.driver):
		car.driver.queue_free()
		car.driver = null
	driving_car = car
	car.player_driver = true
	vehicle_exit_lock = 0.35
	player.controls_enabled = false
	player.set_carry({})
	player.cam.current = false
	if driving_camera == null:
		driving_camera = Camera3D.new()
		driving_camera.name = "DrivingCamera"
		driving_camera.fov = 58.0
		add_child(driving_camera)
	driving_camera.current = true
	driving_camera.global_position = car.global_position + Vector3(0, 9.5, 6.5)
	driving_camera.look_at(car.global_position, Vector3.UP)
	hud.toast("Driving view: joystick/WASD to steer. E to get out.")

func driving_look(rel: Vector2) -> void:
	if driving_car == null or not is_instance_valid(driving_car):
		return
	driving_cam_yaw -= rel.x * 2.8
	driving_cam_pitch = clampf(driving_cam_pitch - rel.y * 2.0, -0.55, 0.65)
	_update_driving_camera()

func _update_driving_camera() -> void:
	if driving_camera == null or driving_car == null or not is_instance_valid(driving_car):
		return
	var orbit := Vector3(0, 9.5, 6.5).rotated(Vector3.UP, driving_cam_yaw)
	# A small pitch adjustment lets the right-hand drag look toward the car or out ahead.
	orbit.y = clampf(9.5 + driving_cam_pitch * 8.0, 5.0, 13.0)
	driving_camera.global_position = driving_car.global_position + orbit
	driving_camera.look_at(driving_car.global_position + Vector3(0, 0.4, 0), Vector3.UP)

func exit_vehicle() -> void:
	if driving_car == null or not is_instance_valid(driving_car):
		driving_car = null
		return
	var car := driving_car
	driving_car = null
	car.player_driver = false
	car.vstate = Vehicle.V.PARKED
	player.global_position = car.door_position()
	player.controls_enabled = true
	if driving_camera:
		driving_camera.current = false
	player.cam.current = true
	hud.toast("Back on foot.")

func _setup_multiplayer() -> void:
	NetworkSession.player_joined.connect(_on_network_player_joined)
	NetworkSession.player_left.connect(_on_network_player_left)
	NetworkSession.pose_received.connect(_on_network_pose)
	var remotes := Node3D.new()
	remotes.name = "RemotePlayers"
	add_child(remotes)
	set_meta("remote_players", {})
	for id in NetworkSession.roster.keys():
		_on_network_player_joined(int(id), str(NetworkSession.roster[id]))
	NetworkSession.register_client()

func _on_network_player_joined(id: int, player_name: String) -> void:
	if id == multiplayer.get_unique_id():
		return
	var remotes: Node3D = get_node_or_null("RemotePlayers")
	if remotes == null or remotes.has_node("Peer%d" % id):
		return
	var remote := preload("res://scripts/remote_player.gd").new()
	remote.name = "Peer%d" % id
	remotes.add_child(remote)
	remote.setup(player_name)
	var map: Dictionary = get_meta("remote_players", {})
	map[id] = remote
	set_meta("remote_players", map)
	hud.toast("%s joined the night shift." % player_name)

func _on_network_player_left(id: int) -> void:
	var map: Dictionary = get_meta("remote_players", {})
	var remote: Node = map.get(id)
	if remote and is_instance_valid(remote):
		remote.queue_free()
	map.erase(id)
	set_meta("remote_players", map)

func _on_network_pose(id: int, pos: Vector3, yaw: float) -> void:
	var map: Dictionary = get_meta("remote_players", {})
	var remote: Node = map.get(id)
	if remote and is_instance_valid(remote):
		remote.apply_pose(pos, yaw)

func vehicle_damaged_store(car: Node) -> void:
	if car.damage_reported:
		return
	car.damage_reported = true
	if store.has("damage"):
		# The damage prop is built at the storefront and stays there as persistent evidence.
		store.damage.visible = true
	if shelves and shelves.has_method("damage_row_near"):
		shelves.damage_row_near(car.global_position.x)
	complaint_level += 2.0
	hud.toast("CRASH! Shelves collapsed and glass shattered.", 4.0)
	play_sfx("thud")

func on_criminal_escaped(_c: Node) -> void:
	criminals_escaped += 1
	hud.toast("A thief got away with unpaid goods.")

func spawn_customer() -> Node:
	var spot: Variant = _take_spot()
	if spot == null:
		return _spawn_walker()
	var s: Dictionary = spot
	var car := Vehicle.new()
	cars_root.add_child(car)
	car.setup(self, s, false)
	_spot_owner[_spot_key(s)] = car
	return car

func _spawn_walker() -> Node:
	var c = preload("res://scripts/customer.gd").new()
	c.registers = registers
	c.game = self
	var door_z := StoreBuilder.D * 0.5
	c.wants_cart = randf() < 0.7
	c.position = Vector3(StoreBuilder.DOOR_X + randf_range(-0.4, 0.4), 0, door_z + 8.0)
	c.finished.connect(_on_customer_finished)
	customers_root.add_child(c)
	c.path.push_front(Vector3(StoreBuilder.DOOR_X, 0, door_z + 3.0))
	spawned += 1
	return c

func _spot_key(s: Dictionary) -> String:
	var p: Vector3 = s.pos
	return "%d_%d" % [int(round(p.x)), int(round(p.z))]

func _take_spot() -> Variant:
	for s in store.parking:
		var k := _spot_key(s)
		if not _spot_owner.has(k):
			_spot_owner[k] = true
			return s
	return null

func _free_pump() -> Variant:
	for p in store.pumps:
		if not _pump_owner.has(_spot_key(p)):
			return p
	return null

func spawn_fuel_car() -> Node:
	var pump: Variant = _free_pump()
	if pump == null:
		return null
	var p: Dictionary = pump
	var car := Vehicle.new()
	cars_root.add_child(car)
	car.setup(self, p, true)
	_pump_owner[_spot_key(p)] = car
	return car

func _spawn_ambient_cars() -> void:
	for paint in [Color(0.5, 0.08, 0.08), Color(0.16, 0.24, 0.38)]:
		var spot: Variant = _take_spot()
		if spot == null:
			return
		var s: Dictionary = spot
		var car := Vehicle.new()
		cars_root.add_child(car)
		car.place_parked(self, s, paint)
		_spot_owner[_spot_key(s)] = car

func release_vehicle(car: Node) -> void:
	if car.spot.is_empty():
		return
	var k := _spot_key(car.spot)
	if car.is_fuel:
		if _pump_owner.get(k) == car:
			_pump_owner.erase(k)
	elif _spot_owner.get(k) == car:
		_spot_owner.erase(k)

func on_car_parked(car: Node) -> void:
	if car.driver:
		return
	var c = preload("res://scripts/customer.gd").new()
	c.registers = registers
	c.game = self
	c.wants_cart = randf() < 0.7
	c.my_car = car
	c.position = car.door_position()
	c.finished.connect(_on_customer_finished)
	customers_root.add_child(c)
	car.driver = c
	spawned += 1

func on_car_at_pump(car: Node) -> void:
	car.say("CUSTOMER FUELING")
	var c = preload("res://scripts/customer.gd").new()
	c.registers = registers
	c.game = self
	c.my_car = car
	c.position = car.door_position()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.finished.connect(_on_customer_finished)
	fuel_people_root.add_child(c)
	fuel_pedestrians[car] = c

func on_car_gone(car: Node) -> void:
	cars_departed += 1
	var c: Node = fuel_pedestrians.get(car)
	if c and is_instance_valid(c):
		c.queue_free()
	fuel_pedestrians.erase(car)

func fuel_for(car: Node) -> Variant:
	if fuel_job.is_empty() or fuel_job.get("car") != car:
		return null
	return fuel_job

func fuel_is_running() -> bool:
	return not fuel_job.is_empty() and bool(fuel_job.get("running", false))

func fuel_interact(car: Node) -> void:
	if fuel_job.is_empty() or fuel_job.get("car") != car:
		var fill := randf() < 0.35
		var max_c := 4200
		var target := max_c if fill else randi_range(8, 36) * 100
		fuel_job = {"car": car, "target": target, "fill": fill, "max": max_c, "running": false, "value": 0.0}
		var msg := ("Fill it up — $%.2f" % (target / 100.0)) if fill else ("$%.2f of gas" % (target / 100.0))
		car.say(msg)
		hud.toast(msg, 4.0)
		return
	if not bool(fuel_job.running):
		fuel_job.running = true
		hud.show_fuel_meter(true)
		return
	fuel_stop()

func fuel_stop() -> void:
	_finish_fuel()

func _run_fuel(delta: float) -> void:
	if fuel_job.is_empty():
		return
	var car: Node = fuel_job.get("car")
	if is_instance_valid(car) and car.vstate == Vehicle.V.AT_PUMP and not bool(fuel_job.get("running", false)):
		car._stuck += delta
		if car._stuck > 75.0:
			car.say("")
			fuel_job = {}
			hud.show_fuel_meter(false)
			car.depart()
			return
	if not bool(fuel_job.get("running", false)):
		return
	fuel_job.value = float(fuel_job.value) + 820.0 * delta
	hud.set_fuel_meter(float(fuel_job.value), float(fuel_job.target), float(fuel_job.max))
	if float(fuel_job.value) >= float(fuel_job.max):
		_finish_fuel()

func _finish_fuel() -> void:
	if fuel_job.is_empty():
		return
	var value := float(fuel_job.value)
	var target := float(fuel_job.target)
	var err := absf(value - target)
	var acc := clampf(1.0 - err / maxf(target, 1.0), 0.0, 1.0)
	var pay := int(round(Economy.payout_f("fuel_base", 250.0) * acc))
	if err <= Economy.payout_f("fuel_perfect_cents", 150.0):
		pay += Economy.payout("fuel_perfect", 250)
	stats.earnings += pay
	stats.fuel = int(stats.fuel) + 1
	hud.set_money(stats.earnings)
	hud.toast("Fuel  +$%.2f" % (pay / 100.0))
	hud.show_fuel_meter(false)
	var car: Node = fuel_job.get("car")
	fuel_job = {}
	if is_instance_valid(car):
		car.say("Thanks")
		car.depart()

# ---------- money ----------
func _on_paid(res: Dictionary) -> void:
	stats.earnings += res.earned + res.tip
	stats.tips += res.tip
	stats.served += 1
	trash += 0.06
	if res.method == "cash":
		if res.correct:
			stats.change_ok += 1
		else:
			stats.change_bad += 1
	hud.set_money(stats.earnings)
	var msg := "+$%.2f" % ((res.earned + res.tip) / 100.0)
	if res.tip > 0:
		msg += "  (tip $%.2f)" % (res.tip / 100.0)
	if not res.correct:
		complaint_level += 1.0
	if not res.correct:
		var diff: int = res.change_given - res.change_due
		msg = ("Short-changed by $%.2f - complaint -$2.00" % (-diff / 100.0)) if diff < 0 else ("Gave $%.2f too much change" % (diff / 100.0))
	hud.toast(msg)

func open_change(reg: Node) -> void:
	_change_reg = reg
	player.controls_enabled = false
	capture_mouse(false)
	hud.open_change(reg.total, reg.payment.cash)

func close_change() -> void:
	_change_reg = null
	hud.close_change()
	player.controls_enabled = true
	if not shift_over:
		capture_mouse(true)

func _on_change_confirmed(given: int) -> void:
	if _change_reg:
		_change_reg.finish_cash(given)
	close_change()

func _recover_registers() -> void:
	for r in registers:
		var c: Node = r.front()
		if c == null or not is_instance_valid(c):
			continue
		if c.state == Customer.S.QUEUED and c.path.is_empty() and c.global_position.distance_to(r.spot(0)) < 1.15:
			c._arrived()
		elif c.state == Customer.S.AT_REGISTER and r.state == 0:
			r.customer_at_front(c)

func _spawn_targets() -> void:
	var spots: Array = [
		{"p": Vector3(6.5, 0.82, StoreBuilder.ROOM_Z - 4.5), "k": "can"},
		{"p": Vector3(7.2, 0.82, StoreBuilder.ROOM_Z - 4.5), "k": "can"},
		{"p": Vector3(7.9, 0.82, StoreBuilder.ROOM_Z - 4.5), "k": "can"},
		{"p": Vector3(8.6, 0.82, StoreBuilder.ROOM_Z - 4.5), "k": "bottle"},
		{"p": Vector3(16.2, 0.9, -31.2), "k": "bottle"},
		{"p": Vector3(16.8, 0.9, -31.2), "k": "can"},
		{"p": Vector3(17.4, 0.9, -31.2), "k": "bottle"},
	]
	for s in spots:
		var t = preload("res://scripts/target.gd").new()
		add_child(t)
		t.position = s.p
		t.setup(s.k)
	# A crate to sit the back-lot targets on.
	StoreBuilder.box(self, Vector3(2.6, 0.8, 0.6), Vector3(7.5, 0.4, StoreBuilder.ROOM_Z - 4.5), StoreBuilder.mat(Color(0.45, 0.32, 0.18)), true)

func _spawn_carts() -> void:
	for slot in store.corral.slots:
		var c := Cart.new()
		add_child(c)
		c.park(slot)

func nearest_free_cart(from: Vector3, who: Node = null) -> Node:
	var best: Node = null
	var best_d := 1.0e9
	for c in get_tree().get_nodes_in_group("cart"):
		if c.mode == Cart.M.HELD or c.mode == Cart.M.FOLLOW:
			continue
		if c.reserved_by and is_instance_valid(c.reserved_by) and c.reserved_by != who:
			continue
		var d: float = c.global_position.distance_to(from)
		if d < best_d:
			best = c
			best_d = d
	return best

func corral_point() -> Vector3:
	return store.corral.pos + Vector3(0, 0, 2.4)

func customer_return_cart(cart: Node) -> void:
	var slot: Variant = _free_cart_slot()
	if slot == null:
		cart.release()
		return
	cart.park(slot)

func _free_cart_slot() -> Variant:
	for s in store.corral.slots:
		var taken := false
		for c in get_tree().get_nodes_in_group("cart"):
			if c.mode == Cart.M.PARKED and c.global_position.distance_to(s) < 0.75:
				taken = true
				break
		if not taken:
			return s
	return null

func _collect_stray_carts() -> void:
	var origin: Vector3 = store.corral.pos
	var half: Vector3 = store.corral.half
	for c in get_tree().get_nodes_in_group("cart"):
		if c.mode != Cart.M.FREE or not c.touched_by_player or c.paid:
			continue
		var d: Vector3 = c.global_position - origin
		if absf(d.x) <= half.x and absf(d.z) <= half.z:
			c.paid = true
			var base := Economy.payout("cart", CART_PAY)
			var pay := int(round(float(base) * cart_pay_mult))
			stats.carts += 1
			stats.earnings += pay
			hud.set_money(stats.earnings)
			hud.toast("Cart returned  +$%.2f" % (pay / 100.0))
			var slot: Variant = _free_cart_slot()
			if slot != null:
				c.park(slot)

func _on_customer_finished(c: Node, did_pay: bool) -> void:
	if not did_pay:
		stats.walked += 1
	if did_pay and c != null and c.requested_milk and not milk_customer_served:
		milk_customer_served = true
		stats.earnings += MILK_ORDER_REWARD
		complaint_level = maxf(0.0, complaint_level - 2.0)
		hud.set_money(stats.earnings)
		hud.toast("MILK ORDER COMPLETE  +$%.2f" % (MILK_ORDER_REWARD / 100.0), 4.0)
		play_sfx("chime")
		_update_order_board()

func on_out_of_stock(_p: Dictionary) -> void:
	stats.oos += 1
	complaint_level += 0.15

func get_milk_product() -> int:
	return MILK_PRODUCT

func claim_milk_customer(_customer: Node) -> bool:
	if milk_order_progress < MILK_ORDER_TOTAL or milk_customer_claimed or milk_customer_served:
		return false
	milk_customer_claimed = true
	return true

func _update_order_board() -> void:
	var progress := mini(milk_order_progress, MILK_ORDER_TOTAL)
	var order_text := "[ ] RESTOCK MILK %d / %d" % [progress, MILK_ORDER_TOTAL]
	if progress >= MILK_ORDER_TOTAL and not milk_customer_served:
		order_text = "[ ] SERVE MILK CUSTOMER"
	elif milk_customer_served:
		order_text = "[x] MILK ORDER COMPLETE"
	if store.has("order_board") and is_instance_valid(store.order_board):
		store.order_board.text = "TONIGHT'S ORDERS\n%s\nFREEZER AISLE" % order_text

# ---------- interactables (target for Interact colliders built by StoreBuilder) ----------
func get_prompt_for(body: Node, _p: Node) -> String:
	var tag: Dictionary = body.tag
	match tag.kind:
		"crate":
			var p: Dictionary = Products.CATALOG[tag.product]
			if not player.carrying.is_empty():
				return "Hands full  (Q to put a box back)"
			return "[E] Grab a box of %s  (%d%% on shelves)" % [p.name, int(shelves.fill_ratio(tag.product) * 100)]
		"supply_pallet":
			if milk_supply_boxes <= 0:
				return "MILK PALLET EMPTY"
			if not player.carrying.is_empty():
				return "Hands full  (drop what you are carrying first)"
			return "[E] Take MILK BOX  (8 units)  — %d boxes left" % milk_supply_boxes
		"can":
			if player.carrying.get("kind", "") == "trash":
				return "Take the bag to the dumpster out back"
			if trash < 0.25:
				return "Trash can (%d%% full)" % int(trash * 100)
			if not player.carrying.is_empty():
				return "Hands full"
			return "[E] Take out the trash bag (%d%% full)" % int(minf(trash, 1.0) * 100)
		"dumpster":
			if player.carrying.get("kind", "") == "trash":
				return "[E] Toss the bag in the dumpster"
			return "Dumpster"
		"back_door":
			return "[E] %s back door" % ("Close" if back_door_open else "Open")
		"freezer":
			var low := 0
			for v in freezer_stock.values(): low += int(v)
			if freezer_open and player.carrying.get("kind", "") == "stock" and int(player.carrying.product) in Products.FROZEN_ITEMS:
				return "[E] Stock freezer with %s" % Products.CATALOG[player.carrying.product].name
			return "[E] Refill freezer from a back-room box  (%d frozen items left)" % low if freezer_open else "[E] Open freezer doors  (%d frozen items)" % low
		"checkout_gun":
			return "Pistol issued to every employee"
		"locker":
			if owned.has("gun_locker"):
				return "Gun locker (empty)" if player.has_gun else "[E] Take the pistol"
			return "LOCKED - buy a key at the back office"
		"terminal":
			return "[E] Back office terminal"
	return ""

func on_interact(body: Node, _p: Node) -> void:
	var tag: Dictionary = body.tag
	match tag.kind:
		"crate":
			if player.carrying.is_empty():
				player.set_carry({"kind": "stock", "product": tag.product, "count": BOX_UNITS})
				play_sfx("place")
		"supply_pallet":
			if milk_supply_boxes > 0 and player.carrying.is_empty():
				milk_supply_boxes -= 1
				player.set_carry({"kind": "stock", "product": MILK_PRODUCT, "count": MILK_ORDER_TOTAL})
				_update_order_board()
				hud.toast("Milk box taken. Bring it to the freezer aisle.", 3.0)
				play_sfx("place")
		"can":
			if player.carrying.is_empty() and trash >= 0.25:
				trash = 0.0
				_update_can()
				player.set_carry({"kind": "trash"})
				play_sfx("place")
		"dumpster":
			if player.carrying.get("kind", "") == "trash":
				player.set_carry({})
				stats.trash += 1
				var bonus := Economy.payout("trash", TRASH_BONUS)
				stats.earnings += bonus
				hud.set_money(stats.earnings)
				hud.toast("+$%.2f  Clean store bonus" % (bonus / 100.0))
				play_sfx("thud")
		"back_door":
			toggle_back_door()
		"freezer":
			if not freezer_open:
				freezer_open = true
				hud.toast("Freezer doors open — milk, pizza, and frozen goods are visible.")
			else:
				var c: Dictionary = player.carrying
				if c.get("kind", "") == "stock" and int(c.product) in Products.FROZEN_ITEMS:
					var product_idx := int(c.product)
					freezer_stock[product_idx] = mini(12, int(freezer_stock.get(product_idx, 0)) + 1)
					player.use_stock_unit()
					if product_idx == MILK_PRODUCT:
						milk_order_progress = mini(MILK_ORDER_TOTAL, milk_order_progress + 1)
						_update_order_board()
						if milk_order_progress == MILK_ORDER_TOTAL:
							hud.toast("Milk restocked. Now serve the customer asking for it.", 4.0)
						else:
							hud.toast("Freezer stocked: %d / %d milk units" % [milk_order_progress, MILK_ORDER_TOTAL], 2.0)
					else:
						hud.toast("Freezer stocked.", 2.0)
					if player.carrying.is_empty():
						freezer_open = false
				else:
					hud.toast("Bring a frozen box from the back room.")
			var doors: Array = store.freezer.doors
			for i in doors.size():
				var door: Node3D = doors[i]
				var closed_z := float(door.get_meta("closed_z", door.position.z))
				door.set_meta("closed_z", closed_z)
				var closed_rot := float(door.get_meta("closed_rot", 0.0))
				door.set_meta("closed_rot", closed_rot)
				var open_z := closed_z + 0.03
				var open_rot := 1.05
				var tw := create_tween().set_parallel(true)
				tw.tween_property(door, "position:z", open_z if freezer_open else closed_z, 0.35).set_trans(Tween.TRANS_BACK)
				tw.tween_property(door, "rotation:x", open_rot if freezer_open else closed_rot, 0.35).set_trans(Tween.TRANS_BACK)
			play_sfx("click")
		"checkout_gun":
			if player.has_gun:
				hud.toast("You already took the pistol.")
			else:
				player.has_gun = true
				if ammo == 0 and mag_ammo == 0:
					ammo = 6
				hud.toast("Pistol ready. G to equip. R reloads 8 shots.")
				play_sfx("click")
		"locker":
			if not owned.has("gun_locker"):
				hud.toast("It's locked. Buy a key on the back office terminal.")
				play_sfx("error")
			elif player.has_gun:
				hud.toast("You already took the pistol.")
			else:
				player.has_gun = true
				if ammo == 0 and mag_ammo == 0:
					ammo = 6
				hud.toast("Pistol ready. G to equip, R to reload 8 shots.")
				play_sfx("click")
		"broom":
			if player.carrying.is_empty():
				player.set_carry({"kind": "broom"})
				hud.toast("Broom equipped. Sweep up the mess.")
		"terminal":
			open_shop(false)

func sweep_debris(p: Node) -> bool:
	for d in get_tree().get_nodes_in_group("sweepable"):
		if is_instance_valid(d) and d.global_position.distance_to(p.global_position) < 2.4:
			d.queue_free()
			stats.trash += 1
			hud.toast("Swept up the mess.")
			return true
	return false

func toggle_back_door() -> void:
	back_door_open = not back_door_open
	var hinge: Node3D = store.back_door.hinge
	var tw := create_tween()
	tw.tween_property(hinge, "rotation:y", PI * 0.5 if back_door_open else 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	play_sfx("click")

func _doors(delta: float) -> void:
	var dpos := Vector3(StoreBuilder.DOOR_X, 0, StoreBuilder.D * 0.5)
	var want := player.global_position.distance_to(dpos) < 3.0
	if not want:
		for c in customers_root.get_children():
			if c.global_position.distance_to(dpos) < 3.2:
				want = true
				break
	var was := front_open
	front_open = move_toward(front_open, 1.0 if want else 0.0, delta * 2.2)
	if was == 0.0 and front_open > 0.0:
		play_sfx("chime")
	var fd: Dictionary = store.front_door
	for i in 2:
		var p: Node3D = fd.panels[i]
		p.position.x = lerpf(fd.closed_x[i], fd.open_x[i], front_open)

func _update_can() -> void:
	var bag: MeshInstance3D = store.can.bag
	bag.visible = trash > 0.05
	var f := clampf(trash, 0.0, 1.15)
	bag.scale.y = maxf(f, 0.05) * 2.6
	bag.position.y = 0.05 + f * 0.39

func has_fast_ring() -> bool:
	return owned.has("fast_ring")

func has_flashlight() -> bool:
	return owned.has("flashlight")

func _on_carry_changed(c: Dictionary) -> void:
	if hud and hud.has_method("set_inventory"):
		hud.set_inventory("PISTOL" if player.has_gun else "EMPTY", "EMPTY" if c.is_empty() else str(c.get("kind", "")).to_upper())
	match c.get("kind", ""):
		"stock":
			hud.set_status("CARRYING", "%s   %d LEFT — HOLD E ON ITS SHELF, OR DROP IT" % [Products.CATALOG[c.product].name.to_upper(), c.count], true)
		"trash":
			hud.set_status("CARRYING", "TRASH BAG — DUMPSTER OUT BACK, OR DROP IT", false)
		_:
			hud.set_status("", "")

func _update_hints() -> void:
	var lines: Array = []
	if milk_order_progress < MILK_ORDER_TOTAL:
		lines.append("ORDER: RESTOCK MILK %d / %d  — BACKROOM PALLET → FREEZER" % [milk_order_progress, MILK_ORDER_TOTAL])
	elif not milk_customer_served:
		lines.append("ORDER: SERVE THE MILK CUSTOMER  — FREEZER AISLE")
	else:
		lines.append("ORDER COMPLETE: MILK  — GOOD WORK")
	var low: Array = shelves.low_products(0.3)
	if not low.is_empty():
		lines.append("LOW STOCK: " + ", ".join(low.slice(0, 3)) + (" +%d" % (low.size() - 3) if low.size() > 3 else ""))
	var stray := 0
	for c in get_tree().get_nodes_in_group("cart"):
		if c.mode == Cart.M.FREE:
			stray += 1
	if stray > 0:
		lines.append("STRAY CARTS: %d  (return them to the corral)" % stray)
	if complaint_level >= 5.0:
		lines.append("CUSTOMER COMPLAINTS: %d%%" % mini(99, int(complaint_level * 7.0)))
	if trash >= 1.0:
		lines.append("TRASH IS OVERFLOWING!")
	elif trash >= 0.7:
		lines.append("Trash is getting full")
	for r in registers:
		if r.state == 2:
			lines.append("LANE %d: CUSTOMER WAITING TO PAY" % (r.index + 1))
		elif r.state == 1:
			lines.append("LANE %d: ITEMS TO SCAN" % (r.index + 1))
	hud.set_tasks(lines)

# ---------- clock / shift ----------
func clock_text() -> String:
	var mins := SHIFT_START_MIN + int(elapsed / SHIFT_REAL_SECONDS * SHIFT_LENGTH_MIN)
	mins = mins % (24 * 60)
	var h := mins / 60
	var m := mins % 60
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, ampm]

func _update_clock() -> void:
	hud.set_clock(clock_text())

func end_shift() -> void:
	if shift_over:
		return
	if _change_reg:
		close_change()
	shift_over = true
	shifts_done += 1
	elapsed = SHIFT_REAL_SECONDS
	save_progress()
	_update_clock()
	player.controls_enabled = false
	customers_root.process_mode = Node.PROCESS_MODE_DISABLED
	hud.show_fuel_meter(false)
	capture_mouse(false)
	hud.set_prompt("")
	hud.show_summary(stats)

func apply_graphics() -> void:
	# Brightness is shared. Presets add shadows and accent lights, not a darker store.
	var p := Settings.gfx_preset
	var bright := clampf(Settings.gfx_brightness, 0.55, 1.6)
	var max_tier := 2
	var glow := 0.45
	var msaa := Viewport.MSAA_2X
	var shadows := false
	_shelf_cull = 0.0
	match p:
		"low":
			max_tier = 0
			glow = 0.22
			msaa = Viewport.MSAA_DISABLED
		"medium":
			max_tier = 1
			glow = 0.35
			msaa = Viewport.MSAA_DISABLED
		"ultra":
			max_tier = 2
			glow = 0.6
			msaa = Viewport.MSAA_4X
			shadows = true
		_:
			max_tier = 2
			glow = 0.45
			msaa = Viewport.MSAA_2X
	var vp := get_viewport()
	vp.msaa_3d = msaa
	vp.scaling_3d_scale = clampf(Settings.gfx_scale, 0.5, 1.0)
	Engine.max_fps = Settings.fps_cap
	if player and player.cam:
		player.cam.far = 220.0
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = c.environment
			env.ambient_light_energy = 0.72 * bright
			env.tonemap_exposure = 1.12 * bright
			env.glow_enabled = true
			env.glow_intensity = glow
			env.fog_enabled = true
			env.fog_density = 0.01
			env.fog_light_color = Color(0.14, 0.13, 0.11)
		elif c is DirectionalLight3D or c.is_in_group("fill_light"):
			var fill := c as DirectionalLight3D
			if fill:
				fill.light_energy = 0.62 * bright
				fill.shadow_enabled = shadows
	for entry in store.lights:
		var light := entry as Light3D
		if light == null:
			continue
		var tier := int(light.get_meta("tier", 2))
		var on := tier <= max_tier
		light.visible = on
		var base_e := float(light.get_meta("base", 1.0))
		var base_r := float(light.get_meta("base_range", 8.0))
		if light is OmniLight3D:
			light.omni_range = base_r
		elif light is SpotLight3D:
			light.spot_range = base_r
			light.shadow_enabled = shadows and on and tier == 0
		light.light_energy = base_e if on else 0.0
		light.set_meta("run", light.light_energy)
	if shelves and player:
		shelves.update_cull(player.global_position.x, _shelf_cull)

func _flicker() -> void:
	# Two fixtures misbehave, like any good night-shift store.
	var fr := Engine.get_process_frames()
	for i in [4, 9, maxi(0, store.lights.size() - 1), maxi(0, store.lights.size() - 2)]:
		if i >= store.lights.size():
			continue
		var l: OmniLight3D = store.lights[i]
		if not l.visible:
			continue
		var on := randf() > 0.12 if fr % 300 < 70 else true
		var run := float(l.get_meta("run", l.get_meta("base")))
		l.light_energy = run * (1.0 if on else 0.1)
		if not l.has_meta("fixture"):
			continue
		var f: Node3D = l.get_meta("fixture")
		if f == null:
			continue
		for t in f.get_children():
			if t is MeshInstance3D and t.get_index() > 0:
				t.visible = on

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not shift_over:
		if _change_reg:
			close_change()
		else:
			set_paused(not get_tree().paused)

func set_paused(on: bool) -> void:
	get_tree().paused = on
	hud.show_pause(on)
	capture_mouse(not on)

func open_shop(from_pause: bool) -> void:
	shop_from_pause = from_pause
	if not from_pause:
		player.controls_enabled = false
		capture_mouse(false)
	hud.show_shop(_shop_rows())

func close_shop() -> void:
	hud.hide_shop()
	if not shop_from_pause and not get_tree().paused and not shift_over and _change_reg == null:
		player.controls_enabled = true
		capture_mouse(true)
	shop_from_pause = false

func _shop_rows() -> Array:
	var rows: Array = []
	for it in Economy.items():
		var id := str(it.get("id", ""))
		var kind := str(it.get("kind", ""))
		var price := int(it.get("price", 0))
		var req := str(it.get("requires", ""))
		var disabled: bool = int(stats.earnings) < price
		var label := "%s   $%.2f   %s" % [it.get("name", id), price / 100.0, it.get("desc", "")]
		if kind == "unlock" and owned.has(id):
			label = "%s   OWNED" % it.get("name", id)
			disabled = true
		elif kind == "vest" and vest == id:
			label = "%s   WORN" % it.get("name", id)
			disabled = true
		elif req != "" and not owned.has(req):
			label += "   (need %s)" % req
			disabled = true
		elif kind == "ammo":
			label = "Shell box   $%.2f   (you have %d)" % [price / 100.0, ammo]
		elif kind == "snack":
			label = "Stamina snack   $%.2f   (you have %d)" % [price / 100.0, snacks]
		rows.append({"id": id, "label": label, "disabled": disabled})
	return rows

func try_buy(id: String) -> void:
	var it := Economy.item(id)
	if it.is_empty():
		return
	var kind := str(it.get("kind", ""))
	var price := int(it.get("price", 0))
	var req := str(it.get("requires", ""))
	if req != "" and not owned.has(req):
		hud.toast("That's locked")
		return
	if kind == "unlock" and owned.has(id):
		return
	if kind == "vest" and vest == id:
		return
	if stats.earnings < price:
		hud.toast("Not enough cash")
		play_sfx("error")
		return
	stats.earnings -= price
	hud.set_money(stats.earnings)
	match kind:
		"unlock":
			owned[id] = true
			if id == "cart_bonus":
				cart_pay_mult = Economy.payout_f("cart_bonus_mult", 2.0)
			if id == "flashlight":
				player.has_light = true
		"ammo":
			ammo += int(it.get("amount", 8))
		"snack":
			snacks += 1
		"vest":
			vest = id
			owned[id] = true
			var col: Array = it.get("color", [0.2, 0.3, 0.2])
			player.set_vest(Color(float(col[0]), float(col[1]), float(col[2])))
	play_sfx("click")
	hud.toast("Bought %s" % it.get("name", id))
	hud.show_shop(_shop_rows())

func eat_snack() -> void:
	if snacks <= 0:
		hud.toast("No snacks. Buy one at the back office.")
		return
	snacks -= 1
	player.eat_boost()
	hud.toast("Ate a snack. Sprint's easier.")
	play_sfx("click")
	if hud.shop_panel.visible:
		hud.show_shop(_shop_rows())

func save_progress() -> bool:
	if sim_mode:
		return false
	return SaveGame.write(_save_blob())

func _save_blob() -> Dictionary:
	return {
		"version": SaveGame.VERSION,
		"money": int(stats.earnings),
		"owned": owned.duplicate(),
		"ammo": ammo,
		"snacks": snacks,
		"vest": vest,
		"mag": mag_ammo,
		"shifts_done": shifts_done,
		"play_seconds": play_seconds,
		"shift_active": not shift_over,
		"shift_elapsed": elapsed,
		"stats": stats.duplicate(),
		"cart_pay_mult": cart_pay_mult,
	}

func _apply_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	var saved_stats = d.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for k in saved_stats:
			stats[k] = saved_stats[k]
	stats.earnings = int(d.get("money", stats.earnings))
	var own = d.get("owned", {})
	if typeof(own) == TYPE_DICTIONARY:
		owned = own.duplicate()
	ammo = int(d.get("ammo", 0))
	snacks = int(d.get("snacks", 0))
	vest = str(d.get("vest", ""))
	mag_ammo = int(d.get("mag", 0))
	shifts_done = int(d.get("shifts_done", 0))
	play_seconds = float(d.get("play_seconds", 0.0))
	if owned.has("cart_bonus"):
		cart_pay_mult = Economy.payout_f("cart_bonus_mult", 2.0)
	if bool(d.get("shift_active", false)):
		elapsed = float(d.get("shift_elapsed", 0.0))
	if hud:
		hud.set_money(int(stats.earnings))
	if vest != "" and player:
		var it := Economy.item(vest)
		var col: Array = it.get("color", [])
		if col.size() >= 3:
			player.set_vest(Color(float(col[0]), float(col[1]), float(col[2])))
	if player and owned.has("flashlight"):
		player.has_light = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_progress()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _to_menu() -> void:
	save_progress()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# ---------- test hooks (used by tests/*.gd only) ----------
var test_results := {}

func debug_tick(frame: int) -> void:
	if frame == 5:
		for i in 5:
			var c: Node = _spawn_walker()
			c.wants_cart = false
			c.my_cart = null
			c.speed = 2.6
			c.stops_left = 1
			c.test_fast = true
			c.state = Customer.S.ENTER
			c.position = Vector3(0, 0, Customer.FRONT_Z)
			c.path = [Vector3(0, 0, 1.0)]
		_self_tests()
	if frame % 15 == 0:
		for r in registers:
			if not r.belt.is_empty():
				r.scan(r.belt[0])
			elif r.state == 2:
				if r.payment.method == "card":
					r.finish_card()
				else:
					var due: int = r.change_due()
					var coins: Array = r.make_change(due)
					var given := 0
					for c in coins:
						given += c
					var res: Dictionary = r.finish_cash(given)
					if not res.get("correct", false):
						test_results["cash_flow"] = false
	if frame == 1700:
		end_shift()

func _self_tests() -> void:
	# change maths
	var ok := true
	for cents in [0, 1, 23, 99, 623, 1377, 4999]:
		var s := 0
		for c in preload("res://scripts/register.gd").make_change(cents):
			s += c
		ok = ok and s == cents
	test_results["make_change"] = ok
	# stocking: empty a slot, refill it from a box
	var i := shelves.slot_index(2, 1, 1, 3)
	var slot: Dictionary = shelves.slots[i]
	slot.count = 0
	var miss := true
	for li in 4:
		shelves.slots[shelves.slot_index(2, 1, li, 3)].count = 0
	var got: Dictionary = shelves.take(2, 1, StoreBuilder.SHELF_Z0 + 0.15 + 3.5 * shelves.slot_len)
	miss = got.has("missing")
	var n: int = mini(3, slot.cap)
	player.set_carry({"kind": "stock", "product": slot.product, "count": n})
	var placed := 0
	for k in n:
		if shelves.place(i, slot.product) == "":
			player.use_stock_unit()
			placed += 1
	var wrong := shelves.place(i, (slot.product + 1) % Products.CATALOG.size()) != ""
	test_results["stocking"] = miss and placed == n and slot.count == n and player.carrying.is_empty() and wrong
	# trash loop
	trash = 0.9
	on_interact(store.can.body, player)
	var carrying_trash: bool = player.carrying.get("kind", "") == "trash"
	on_interact(store.dumpster, player)
	test_results["trash"] = carrying_trash and stats.trash == 1 and player.carrying.is_empty()
	# doors + locker prompt
	toggle_back_door()
	test_results["locker"] = get_prompt_for(store.locker, player).begins_with("LOCKED")

func debug_open_routes() -> void:
	front_open = 1.0
	var fd: Dictionary = store.front_door
	for i in 2:
		var p: Node3D = fd.panels[i]
		p.position.x = fd.open_x[i]
	back_door_open = true
	var hinge: Node3D = store.back_door.hinge
	hinge.rotation.y = PI * 0.5

## Returns "" when every waypoint segment is clear at chest and knee height.
## A blocked segment names the collider so a sealed doorway shows up in CI.
func debug_route_block() -> String:
	var space := get_world_3d().direct_space_state
	var door_x := StoreBuilder.STOCK_DOOR_X
	var desk := Vector3(-4.6, 1.0, -17.0)
	var routes: Array = [
		["stockroom", [Vector3(0, 1, 8), Vector3(0, 1, -13.2), Vector3(door_x, 1, -13.2), Vector3(door_x, 1, -15.2), Vector3(door_x, 1, -18.5)]],
		["back office", [Vector3(door_x, 1, -18.0), desk]],
		["gun locker", [Vector3(door_x, 1, -18.5), Vector3(-18.0, 1, -20.0), Vector3(-18.0, 1, -30.0)]],
		["back door", [Vector3(0, 1, -22.0), Vector3(0, 1, -28.0), Vector3(10, 1, -32.0), Vector3(StoreBuilder.BACK_DOOR_X, 1, -33.2), Vector3(StoreBuilder.BACK_DOOR_X, 1, -36.0)]],
		["dumpster", [Vector3(StoreBuilder.BACK_DOOR_X, 1, -36.0), Vector3(StoreBuilder.BACK_DOOR_X - 3.0, 1, StoreBuilder.ROOM_Z - 2.2)]],
		["front door", [Vector3(0, 1, 18), Vector3(0, 1, 26)]],
		["fuel bay", [Vector3(0, 1, 28), Vector3(0, 1, 44), Vector3(24, 1, 44), Vector3(StoreBuilder.FUEL_POS.x, 1, 42), Vector3(StoreBuilder.FUEL_POS.x, 1, StoreBuilder.FUEL_POS.z + 4.0)]],
	]
	for route in routes:
		var name: String = route[0]
		var pts: Array = route[1]
		for i in pts.size() - 1:
			for height in [0.55, 1.15]:
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[i + 1]
				a.y = height
				b.y = height
				var q := PhysicsRayQueryParameters3D.create(a, b)
				q.collide_with_areas = false
				var hit := space.intersect_ray(q)
				if not hit.is_empty():
					var col: Object = hit.collider
					var who := "body"
					if col is Node:
						who = str(col.name)
						var p: Node = col.get_parent()
						if p:
							who = "%s/%s" % [p.name, col.name]
					return "%s blocked %s -> %s by %s" % [name, a, b, who]
	return ""

func debug_report() -> bool:
	print("SMOKE: spawned=%d stats=%s tests=%s clock=%s over=%s" % [spawned, stats, test_results, clock_text(), shift_over])
	var ok: bool = spawned >= 5 and stats.served >= 1 and shift_over
	for k in ["make_change", "stocking", "trash", "locker"]:
		ok = ok and test_results.get(k, false)
	return ok and test_results.get("cash_flow", true)

## Screenshot helper: poses the camera for named shots.
func debug_pose(shot: String) -> void:
	player.cam.rotation.x = 0.0
	match shot:
		"interior":
			player.position = Vector3(0.0, 0.05, 18.5)
			player.rotation.y = 0.0
			player.cam.rotation.x = deg_to_rad(-8)
		"outside":
			player.position = Vector3(BACK_DOOR_POS().x - 3.0, 0.05, StoreBuilder.ROOM_Z - 6.0)
			player.rotation.y = PI - 0.4
			player.cam.rotation.x = deg_to_rad(-8)
		"stockroom":
			player.position = Vector3(0.0, 0.05, StoreBuilder.ZB - 1.5)
			player.rotation.y = 0.0
			player.cam.rotation.x = deg_to_rad(-10)
		"icon":
			hud.visible = false
			player.viewmodel.visible = false
			player.position = Vector3(-6.0, 0.05, 34.0)
			player.rotation.y = 0.0
			player.cam.rotation.x = deg_to_rad(2)
		"front":
			player.position = Vector3(-6.0, 0.05, 40.0)
			player.rotation.y = 0.0
			player.cam.rotation.x = deg_to_rad(-4)
		"lot":
			player.position = Vector3(-2.0, 0.05, 44.0)
			player.rotation.y = 0.0
			player.cam.rotation.x = deg_to_rad(-6)
		"fuel":
			player.position = Vector3(StoreBuilder.FUEL_POS.x, 0.05, StoreBuilder.FUEL_POS.z + 9.0)
			player.rotation.y = 0.0
			player.cam.rotation.x = deg_to_rad(-10)

func BACK_DOOR_POS() -> Vector3:
	return Vector3(StoreBuilder.BACK_DOOR_X, 0, StoreBuilder.ROOM_Z)
