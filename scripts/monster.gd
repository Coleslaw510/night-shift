class_name Monster
extends Node3D
## Funny-scary low-poly monster for v1.3. It patrols the store/back room and chases
## the player when close. The shotgun can call hit() to remove it.

var game: Node
var target: Node3D
var patrol: Array[Vector3] = []
var patrol_i := 0
var speed := 1.65
var chase_speed := 2.8
var alert_range := 12.0
var attack_range := 1.35
var attack_t := 0.0
var dead := false
var body: Node3D
var face: Node3D
var label: Label3D

func setup(g: Node, p: Node3D) -> void:
	game = g
	target = p
	patrol = [Vector3(-17, 0, -20), Vector3(16, 0, -24), Vector3(17, 0, -40), Vector3(-17, 0, -40), Vector3(0, 0, -30)]
	_build()

func _build() -> void:
	body = Node3D.new()
	add_child(body)
	var flesh := StoreBuilder.mat(Color(0.18, 0.32, 0.25), 0.0, 0.9)
	var dark := StoreBuilder.mat(Color(0.035, 0.045, 0.04), 0.0, 0.8)
	StoreBuilder.box(body, Vector3(0.72, 1.25, 0.48), Vector3(0, 1.0, 0), flesh)
	StoreBuilder.box(body, Vector3(0.92, 0.42, 0.58), Vector3(0, 1.8, 0), flesh)
	StoreBuilder.box(body, Vector3(0.24, 0.8, 0.24), Vector3(-0.23, 0.15, 0), flesh)
	StoreBuilder.box(body, Vector3(0.24, 0.8, 0.24), Vector3(0.23, 0.15, 0), flesh)
	for x in [-0.18, 0.18]:
		StoreBuilder.box(body, Vector3(0.12, 0.12, 0.08), Vector3(x, 1.86, -0.3), StoreBuilder.mat(Color(1.0, 0.18, 0.08), 4.0))
	StoreBuilder.box(body, Vector3(0.48, 0.08, 0.05), Vector3(0, 1.62, -0.31), dark)
	label = Label3D.new()
	label.text = "???"
	label.position = Vector3(0, 2.45, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.004
	label.modulate = Color(1, 0.35, 0.25)
	label.visible = false
	add_child(label)
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 2.0
	cs.shape = shape
	cs.position.y = 1.0
	add_child(cs)

func _physics_process(delta: float) -> void:
	if dead or game == null or target == null or not is_instance_valid(target):
		return
	attack_t = maxf(0.0, attack_t - delta)
	var to_player: Vector3 = target.global_position - global_position
	to_player.y = 0
	var player_in_stockroom := target.global_position.z <= StoreBuilder.ZB + 0.35
	var chasing := player_in_stockroom and to_player.length() <= alert_range
	var dir := to_player.normalized() if chasing and to_player.length() > 0.1 else Vector3.ZERO
	if not chasing:
		if patrol.is_empty():
			return
		var to_way: Vector3 = patrol[patrol_i] - global_position
		to_way.y = 0
		if to_way.length() < 1.0:
			patrol_i = (patrol_i + 1) % patrol.size()
		else:
			dir = to_way.normalized()
	if dir.length() > 0.1:
		global_position += dir * (chase_speed if chasing else speed) * delta
		global_position.x = clampf(global_position.x, -18.0, 18.0)
		global_position.z = clampf(global_position.z, StoreBuilder.ROOM_Z + 1.0, StoreBuilder.ZB - 0.65)
		global_position.y = 0
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 6.0))
	label.visible = chasing
	if chasing and to_player.length() <= attack_range and attack_t <= 0.0:
		attack_t = 2.0
		if game.has_method("monster_attack"):
			game.monster_attack(self)

func hit() -> void:
	if dead:
		return
	dead = true
	label.text = "OW"
	label.visible = true
	if game and game.hud:
		game.hud.toast("The thing drops into a heap.")
	queue_free()
