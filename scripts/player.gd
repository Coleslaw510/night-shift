extends CharacterBody3D
## First-person controller: WASD, mouse look, Shift sprint, Space jump, E/click interact.
## Interactables: any collider (or its parent) with `interact(player)` and `get_prompt()`.

signal prompt_changed(text: String)

const WALK := 3.2
const SPRINT := 5.6
const JUMP := 4.2
const REACH := 3.0
var mouse_sens := 0.0025
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var cam: Camera3D
var ray: RayCast3D
var _last_prompt := ""
var controls_enabled := true

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.62
	cam.fov = 75
	add_child(cam)
	cam.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collide_with_areas = true
	ray.add_exception(self)
	cam.add_child(ray)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		cam.rotate_x(-event.relative.y * mouse_sens)
		cam.rotation.x = clamp(cam.rotation.x, -1.45, 1.45)
	elif event.is_action_pressed("interact"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var t := _target()
		if t:
			t.interact(self)

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
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP
	var spd := SPRINT if Input.is_action_pressed("sprint") else WALK
	velocity.x = move_toward(velocity.x, dir.x * spd, 40 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 40 * delta)
	move_and_slide()
	# Head bob, subtle.
	var hs := Vector2(velocity.x, velocity.z).length()
	cam.position.y = 1.62 + (sin(Time.get_ticks_msec() * 0.012 * (spd / WALK)) * 0.03 if hs > 0.5 and is_on_floor() else 0.0)
	# Prompt
	var p := ""
	var t := _target()
	if t and t.has_method("get_prompt"):
		p = t.get_prompt()
	if p != _last_prompt:
		_last_prompt = p
		prompt_changed.emit(p)
