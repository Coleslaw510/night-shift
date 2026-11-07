extends Node3D
## Main game controller: builds the store, shelves, HUD, player, registers; spawns customers;
## runs the shift clock (10 PM -> 6 AM), doors, trash, stock hints and the end-of-shift summary.

const VERSION := "1.1"
const SHIFT_START_MIN := 22 * 60          # 10:00 PM
const SHIFT_LENGTH_MIN := 8 * 60          # until 6:00 AM
const SHIFT_REAL_SECONDS := 600.0         # ~10 real minutes per shift
const MAX_CUSTOMERS := 7
const TRASH_FILL_SECONDS := 150.0         # empty -> full with no customers
const TRASH_BONUS := 150                  # cents for taking a bag out
const CART_PAY := 75                      # cents for a returned stray cart
const BOX_UNITS := 12

var store := {}
var shelves: ShelfSystem
var hud: CanvasLayer
var player: CharacterBody3D
var registers: Array = []
var customers_root: Node3D
var shift_over := false
var elapsed := 0.0
var spawned := 0
var spawn_t := 3.0
var trash := 0.35
var back_door_open := false
var front_open := 0.0
var _hint_t := 0.0
var _change_reg: Node = null
var _sfx: Array = []
var touch_mode := false
var stats := {"earnings": 0, "tips": 0, "served": 0, "walked": 0, "stocked": 0, "oos": 0, "change_ok": 0, "change_bad": 0, "trash": 0, "carts": 0}
var cart_pay_mult := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	touch_mode = is_touch()
	if touch_mode:
		_setup_mobile()
	store = StoreBuilder.build(self, self)
	if touch_mode:
		_mobile_env()
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
	hud = preload("res://scripts/hud.gd").new()
	hud.touch_mode = touch_mode
	add_child(hud)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.menu_pressed.connect(_to_menu)
	hud.change_confirmed.connect(_on_change_confirmed)
	hud.change_cancelled.connect(close_change)
	player = preload("res://scripts/player.gd").new()
	player.name = "Player"
	player.position = Vector3(6.6, 0.05, 15.4)
	player.rotation.y = PI * 0.5
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.touch_mode = touch_mode
	player.prompt_changed.connect(hud.set_prompt)
	player.carry_changed.connect(_on_carry_changed)
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
	hud.toast("One register, on your right. Stockroom is straight through the back.", 6.0)
	_update_clock()
	_update_hints()

## Touch mode: phones/tablets, or desktop testing with `godot -- --touch`.
static func is_touch() -> bool:
	return OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")

func capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (on and not touch_mode) else Input.MOUSE_MODE_VISIBLE

## Mobile preset: no tap-to-interact via emulated mouse clicks, no MSAA, lighter glow/fog,
## slightly lower 3D resolution, 60 fps cap. The look is kept (same lights and materials).
func _setup_mobile() -> void:
	InputMap.action_erase_events("interact")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	InputMap.action_add_event("interact", e)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 0.8
	Engine.max_fps = 60

func _mobile_env() -> void:
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = c.environment
			env.glow_intensity = 0.55
			env.adjustment_enabled = false

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
	_flicker()
	_doors(delta)
	elapsed += delta
	_update_clock()
	trash = minf(trash + delta / TRASH_FILL_SECONDS, 1.2)
	_collect_stray_carts()
	_update_can()
	_recover_registers()
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 0.5
		_update_hints()
	if elapsed >= SHIFT_REAL_SECONDS:
		end_shift()
		return
	spawn_t -= delta
	if spawn_t <= 0.0 and elapsed < SHIFT_REAL_SECONDS * 0.95:
		spawn_t = randf_range(10.0, 22.0)
		if customers_root.get_child_count() < MAX_CUSTOMERS:
			spawn_customer()

func spawn_customer() -> Node:
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

func _spawn_carts() -> void:
	for slot in store.corral.slots:
		var c := Cart.new()
		add_child(c)
		c.park(slot)

func nearest_free_cart(from: Vector3) -> Node:
	var best: Node = null
	var best_d := 1.0e9
	for c in get_tree().get_nodes_in_group("cart"):
		if c.mode == Cart.M.HELD or c.mode == Cart.M.FOLLOW:
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
			var pay := int(round(float(CART_PAY) * cart_pay_mult))
			stats.carts += 1
			stats.earnings += pay
			hud.set_money(stats.earnings)
			hud.toast("Cart returned  +$%.2f" % (pay / 100.0))
			var slot: Variant = _free_cart_slot()
			if slot != null:
				c.park(slot)

func _on_customer_finished(_c: Node, did_pay: bool) -> void:
	if not did_pay:
		stats.walked += 1

func on_out_of_stock(_p: Dictionary) -> void:
	stats.oos += 1

# ---------- interactables (target for Interact colliders built by StoreBuilder) ----------
func get_prompt_for(body: Node, _p: Node) -> String:
	var tag: Dictionary = body.tag
	match tag.kind:
		"crate":
			var p: Dictionary = Products.CATALOG[tag.product]
			if not player.carrying.is_empty():
				return "Hands full  (Q to put a box back)"
			return "[E] Grab a box of %s  (%d%% on shelves)" % [p.name, int(shelves.fill_ratio(tag.product) * 100)]
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
		"locker":
			return "LOCKED - For emergencies only"
	return ""

func on_interact(body: Node, _p: Node) -> void:
	var tag: Dictionary = body.tag
	match tag.kind:
		"crate":
			if player.carrying.is_empty():
				player.set_carry({"kind": "stock", "product": tag.product, "count": BOX_UNITS})
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
				stats.earnings += TRASH_BONUS
				hud.set_money(stats.earnings)
				hud.toast("+$%.2f  Clean store bonus" % (TRASH_BONUS / 100.0))
				play_sfx("thud")
		"back_door":
			toggle_back_door()
		"locker":
			hud.toast("It's locked. Manager's note: \"ONLY if something gets in.\"")
			play_sfx("error")

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
	return false

func _on_carry_changed(c: Dictionary) -> void:
	match c.get("kind", ""):
		"stock":
			hud.set_status("CARRYING", "%s   %d LEFT — HOLD E ON ITS SHELF, OR DROP IT" % [Products.CATALOG[c.product].name.to_upper(), c.count], true)
		"trash":
			hud.set_status("CARRYING", "TRASH BAG — DUMPSTER OUT BACK, OR DROP IT", false)
		_:
			hud.set_status("", "")

func _update_hints() -> void:
	var lines: Array = []
	var low: Array = shelves.low_products(0.3)
	if not low.is_empty():
		lines.append("LOW STOCK: " + ", ".join(low.slice(0, 3)) + (" +%d" % (low.size() - 3) if low.size() > 3 else ""))
	var stray := 0
	for c in get_tree().get_nodes_in_group("cart"):
		if c.mode == Cart.M.FREE:
			stray += 1
	if stray > 0:
		lines.append("STRAY CARTS: %d  (return them to the corral)" % stray)
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
	elapsed = SHIFT_REAL_SECONDS
	_update_clock()
	player.controls_enabled = false
	customers_root.process_mode = Node.PROCESS_MODE_DISABLED
	capture_mouse(false)
	hud.set_prompt("")
	hud.show_summary(stats)

func _flicker() -> void:
	# Two fixtures misbehave, like any good night-shift store.
	var fr := Engine.get_process_frames()
	for i in [4, 9]:
		if i >= store.lights.size():
			continue
		var l: OmniLight3D = store.lights[i]
		var on := randf() > 0.12 if fr % 300 < 70 else true
		l.light_energy = l.get_meta("base") * (1.0 if on else 0.1)
		var f: Node3D = l.get_meta("fixture")
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

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# ---------- test hooks (used by tests/*.gd only) ----------
var test_results := {}

func debug_tick(frame: int) -> void:
	if frame == 5:
		for i in 5:
			spawn_customer()
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
			player.position = Vector3(StoreBuilder.FUEL_POS.x - 6.0, 0.05, StoreBuilder.FUEL_POS.z + 6.0)
			player.rotation.y = deg_to_rad(140)
			player.cam.rotation.x = deg_to_rad(-6)

func BACK_DOOR_POS() -> Vector3:
	return Vector3(StoreBuilder.BACK_DOOR_X, 0, StoreBuilder.ROOM_Z)
