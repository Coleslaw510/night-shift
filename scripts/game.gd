extends Node3D
## Main game controller: builds the store, HUD, player, registers; spawns customers;
## runs the shift clock (10 PM -> 6 AM) and shows the end-of-shift summary.

const SHIFT_START_MIN := 22 * 60          # 10:00 PM
const SHIFT_LENGTH_MIN := 8 * 60          # until 6:00 AM
const SHIFT_REAL_SECONDS := 600.0         # ~10 real minutes per shift
const MAX_CUSTOMERS := 7

var store := {}
var hud: CanvasLayer
var player: CharacterBody3D
var registers: Array = []
var customers_root: Node3D
var shift_over := false
var elapsed := 0.0
var earnings := 0.0
var served := 0
var walked := 0
var spawned := 0
var spawn_t := 3.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	store = StoreBuilder.build(self)
	for lane in store.lanes:
		var r = preload("res://scripts/register.gd").new()
		r.name = "Register%d" % (lane.index + 1)
		r.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(r)
		r.setup(lane)
		r.paid.connect(_on_paid)
		registers.append(r)
	customers_root = Node3D.new()
	customers_root.name = "Customers"
	customers_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(customers_root)
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.menu_pressed.connect(_to_menu)
	player = preload("res://scripts/player.gd").new()
	player.name = "Player"
	player.position = Vector3(-8.8, 0.05, 11.0)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.prompt_changed.connect(hud.set_prompt)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.toast("Customers check out at lanes 1 and 2. Look at items on the belt and press E.", 6.0)
	_update_clock()

func _process(delta: float) -> void:
	if get_tree().paused or shift_over:
		return
	_flicker()
	elapsed += delta
	_update_clock()
	if elapsed >= SHIFT_REAL_SECONDS:
		end_shift()
		return
	spawn_t -= delta
	# Stop letting people in for the last ~5% of the shift.
	if spawn_t <= 0.0 and elapsed < SHIFT_REAL_SECONDS * 0.95:
		spawn_t = randf_range(10.0, 22.0)
		if customers_root.get_child_count() < MAX_CUSTOMERS:
			spawn_customer()

func spawn_customer() -> Node:
	var c = preload("res://scripts/customer.gd").new()
	c.registers = registers
	c.position = Vector3(StoreBuilder.DOOR_X + randf_range(-0.5, 0.5), 0, 17.5)
	c.finished.connect(_on_customer_finished)
	customers_root.add_child(c)
	spawned += 1
	return c

func _on_paid(amount: float) -> void:
	earnings += amount
	served += 1
	hud.set_money(earnings)
	hud.toast("+$%.2f  Thanks, come again!" % amount)

func _on_customer_finished(_c: Node, did_pay: bool) -> void:
	if not did_pay:
		walked += 1
		hud.toast("A customer got tired of waiting and left.")

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
	shift_over = true
	elapsed = SHIFT_REAL_SECONDS
	_update_clock()
	player.controls_enabled = false
	customers_root.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_prompt("")
	hud.show_summary(earnings, served, walked)

func _flicker() -> void:
	# Two fixtures misbehave, like any good night-shift store.
	for i in [3, 8]:
		if i >= store.lights.size():
			continue
		var l: OmniLight3D = store.lights[i]
		var on := randf() > 0.08 if Engine.get_process_frames() % 240 < 60 else true
		l.visible = on
		var f: MeshInstance3D = l.get_meta("fixture")
		f.visible = on

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not shift_over:
		set_paused(not get_tree().paused)

func set_paused(on: bool) -> void:
	get_tree().paused = on
	hud.show_pause(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# ---------- test hooks (used by tests/*.gd only) ----------
func debug_tick(frame: int) -> void:
	if frame == 5:
		for i in 4:
			spawn_customer()
	if frame % 20 == 0:
		for r in registers:
			if not r.belt.is_empty():
				r.scan(r.belt[0])
	if frame == 1700:
		end_shift()

func debug_report() -> bool:
	print("SMOKE: spawned=%d served=%d walked=%d earnings=%.2f clock=%s over=%s" % [spawned, served, walked, earnings, clock_text(), shift_over])
	return spawned >= 4 and served >= 1 and shift_over

func debug_screenshot_setup(frame: int) -> void:
	if frame == 2:
		Engine.time_scale = 12.0
		for i in 5:
			spawn_customer()
	if frame == 140:
		Engine.time_scale = 1.0
		get_tree().paused = true
		hud.toast("")
		player.position = Vector3(-8.3, 0.05, 9.6)
		player.rotation.y = atan2(-(-4.0 - -8.3), -(3.0 - 9.6))
		player.cam.rotation.x = deg_to_rad(-10)
