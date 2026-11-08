extends Node3D
var target_position := Vector3.ZERO
var target_yaw := 0.0
var body: Node3D

func setup(player_name: String) -> void:
	body = Node3D.new()
	add_child(body)
	var shirt := StoreBuilder.mat(Color(0.2, 0.55, 0.85), 0.0, 0.8)
	var skin := StoreBuilder.mat(Color(0.86, 0.64, 0.47), 0.0, 0.8)
	StoreBuilder.box(body, Vector3(0.55, 0.8, 0.35), Vector3(0, 1.05, 0), shirt)
	StoreBuilder.box(body, Vector3(0.42, 0.42, 0.42), Vector3(0, 1.68, 0), skin)
	StoreBuilder.box(body, Vector3(0.46, 0.12, 0.46), Vector3(0, 1.91, 0), StoreBuilder.mat(Color(0.08, 0.08, 0.1), 0.0, 0.8))
	var label := Label3D.new()
	label.text = player_name
	label.position = Vector3(0, 2.25, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.004
	label.modulate = Color(0.7, 0.95, 1.0)
	add_child(label)

func apply_pose(pos: Vector3, yaw: float) -> void:
	target_position = pos
	target_yaw = yaw

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 12.0))
