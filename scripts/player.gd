extends CharacterBody3D
## First-person controller: WASD, mouse look, Shift sprint, Space jump, E/click interact
## (hold for stocking), Q to put down a carried stock box. Has a scanner viewmodel and can
## carry one thing: {"kind": "stock", "product": idx, "count": n} or {"kind": "trash"}.

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
var scanner: Node3D
var beam: MeshInstance3D
var carry_node: Node3D
var _beam_t := 0.0
var _bob := 0.0
var touch_mode := false          # set by game.gd on phones/tablets
var touch_move := Vector2.ZERO   # from the virtual joystick
var sprint_toggle := false

func _ready() -> void:
	Settings.load_settings()
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
	var sleeve := StoreBuilder.mat(Color(0.16, 0.28, 0.22), 0.0, 0.9)     # green work shirt
	var plastic := StoreBuilder.mat(Color(0.27, 0.27, 0.28), 0.0, 0.4, 0.2)
	var arm := Node3D.new()
	arm.rotation = Vector3(0.18, 0.42, -0.1)
	viewmodel.add_child(arm)
	StoreBuilder.box(arm, Vector3(0.12, 0.12, 0.5), Vector3(0.07, -0.13, 0.32), sleeve)
	StoreBuilder.box(arm, Vector3(0.095, 0.095, 0.26), Vector3(0.04, -0.09, 0.05), skin)     # forearm
	StoreBuilder.box(arm, Vector3(0.12, 0.12, 0.12), Vector3(0.0, -0.04, -0.09), skin)       # fist
	for k in 3:
		StoreBuilder.box(arm, Vector3(0.03, 0.032, 0.03), Vector3(-0.065, -0.005 - k * 0.036, -0.12), skin)
	StoreBuilder.box(arm, Vector3(0.035, 0.03, 0.07), Vector3(-0.05, 0.03, -0.1), skin)    # thumb
	scanner = Node3D.new()
	scanner.position = Vector3(-0.005, 0.0, -0.1)
	scanner.scale = Vector3(0.8, 0.8, 0.8)
	scanner.rotation.x = 0.15
	arm.add_child(scanner)
	var handle := StoreBuilder.box(scanner, Vector3(0.07, 0.22, 0.08), Vector3(0, 0.02, 0), plastic)
	handle.rotation.x = 0.28
	StoreBuilder.box(scanner, Vector3(0.11, 0.11, 0.24), Vector3(0, 0.15, -0.06), plastic)        # body
	StoreBuilder.box(scanner, Vector3(0.13, 0.13, 0.07), Vector3(0, 0.155, -0.2), plastic)        # head
	StoreBuilder.box(scanner, Vector3(0.05, 0.03, 0.005), Vector3(0, 0.175, 0.062), StoreBuilder.mat(Color(0.55, 0.95, 0.2), 1.5))  # status screen
	StoreBuilder.box(scanner, Vector3(0.1, 0.08, 0.005), Vector3(0, 0.155, -0.236), StoreBuilder.mat(Color(1, 0.12, 0.05), 2.5))
	StoreBuilder.box(scanner, Vector3(0.03, 0.05, 0.03), Vector3(0, 0.07, -0.06), StoreBuilder.mat(Color(0.25, 0.25, 0.27)))  # trigger
	beam = StoreBuilder.box(scanner, Vector3(0.08, 0.004, 1.4), Vector3(0, 0.155, -0.95), StoreBuilder.unshaded(Color(1, 0.1, 0.05, 0.6)))
	beam.visible = false
	carry_node = Node3D.new()
	carry_node.position = Vector3(-0.2, -0.05, -0.15)
	viewmodel.add_child(carry_node)

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

func scan_flash() -> void:
	_beam_t = 0.12
	beam.visible = true

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
		var t := _target()
		if t:
			t.interact(self)
	elif event.is_action_pressed("drop"):
		if carrying.get("kind", "") == "stock":
			set_carry({})
			var g := get_parent()
			if g and g.has_method("toast"):
				g.toast("Put the box back in the stockroom.")

func touch_look(rel: Vector2) -> void:
	if not controls_enabled:
		return
	rotate_y(-rel.x)
	cam.rotate_x(-rel.y)
	cam.rotation.x = clamp(cam.rotation.x, -1.45, 1.45)

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
	var spd := SPRINT if (Input.is_action_pressed("sprint") or sprint_toggle) else WALK
	velocity.x = move_toward(velocity.x, dir.x * spd, 40 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 40 * delta)
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.5 and is_on_floor():
		_bob += delta * hs * 2.6
	cam.position.y = 1.62 + sin(_bob * 2.0) * 0.025
	viewmodel.position = Vector3(0.27 + cos(_bob) * 0.008, -0.31 + absf(sin(_bob)) * 0.01, -0.55)
	if _beam_t > 0.0:
		_beam_t -= delta
		if _beam_t <= 0.0:
			beam.visible = false
	scanner.visible = carrying.is_empty()
	var p := ""
	var t := _target()
	if t and t.has_method("get_prompt"):
		p = t.get_prompt(self)
	if p != _last_prompt:
		_last_prompt = p
		prompt_changed.emit(p)
