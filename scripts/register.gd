extends Node3D
## One checkout lane: customer queue, belt items, scanning, total, payment.

signal paid(amount: float)

var lane_x := 0.0
var counter_x := 0.0
var index := 0
var label: Label3D
var screen: MeshInstance3D
var queue: Array = []
var belt: Array = []
var total := 0.0
var _flash := 0.0

func setup(lane: Dictionary) -> void:
	lane_x = lane.lane_x
	counter_x = lane.counter_x
	index = lane.index
	label = lane.label
	screen = lane.screen
	_update_label()

func queue_size() -> int:
	return queue.size()

func spot(i: int) -> Vector3:
	return Vector3(lane_x, 0, 6.0 - 1.15 * i)

func join(c: Node) -> Vector3:
	queue.append(c)
	return spot(queue.size() - 1)

func is_front(c: Node) -> bool:
	return not queue.is_empty() and queue[0] == c

func customer_at_front(c: Node) -> void:
	# Unload the basket onto the belt.
	_clear_belt()
	total = 0.0
	var z := 5.3
	for p in c.items:
		var it = preload("res://scripts/belt_item.gd").new()
		add_child(it)
		it.setup(p, self)
		it.global_position = Vector3(counter_x, 0.95 + p.size.y * 0.45, z)
		it.rotation.y = randf_range(-0.3, 0.3)
		belt.append(it)
		z += maxf(p.size.x, 0.12) * 0.9 + 0.12
		if z > 7.4:
			z = 5.45
	c.clear_basket()
	_update_label()

func scan(it: Node) -> void:
	if not belt.has(it):
		return
	belt.erase(it)
	total += it.product.price
	it.queue_free()
	_flash = 0.15
	_beep()
	_update_label()
	if belt.is_empty() and not queue.is_empty():
		var c: Node = queue.pop_front()
		paid.emit(total)
		label.text = "LANE %d\nPAID $%.2f" % [index + 1, total]
		total = 0.0
		c.pay_and_leave()
		_advance()

func leave(c: Node) -> void:
	var was_front := is_front(c)
	queue.erase(c)
	if was_front:
		_clear_belt()
		total = 0.0
		_update_label()
	_advance()

func _advance() -> void:
	for i in queue.size():
		queue[i].set_queue_spot(spot(i))

func _clear_belt() -> void:
	for it in belt:
		if is_instance_valid(it):
			it.queue_free()
	belt.clear()

func _update_label() -> void:
	label.text = "LANE %d\n%d items  $%.2f" % [index + 1, belt.size(), total]

func _beep() -> void:
	var p := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.15
	p.stream = gen
	p.position = Vector3(counter_x, 1.0, 7.8)
	add_child(p)
	p.play()
	var pb = p.get_stream_playback()
	if pb:
		var frames := int(22050 * 0.09)
		for i in frames:
			var v := 0.25 * sin(TAU * 1800.0 * i / 22050.0)
			pb.push_frame(Vector2(v, v))
	get_tree().create_timer(0.3).timeout.connect(p.queue_free)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		screen.material_override = StoreBuilder.mat(Color(0.3, 1.0, 0.5), 3.0) if _flash > 0.0 else StoreBuilder.mat(Color(0.05, 0.25, 0.12), 1.5)
