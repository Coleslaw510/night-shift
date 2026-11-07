extends Node3D
## One checkout lane: customer queue, belt items, scanning, payment (cash change / card).
## Money is handled in integer cents.
## States: IDLE -> SCANNING (items on belt) -> PAYMENT (customer hands cash or card).

signal paid(result: Dictionary)   # {"total","cash","change_given","change_due","earned","tip","correct","method"}

enum R { IDLE, SCANNING, PAYMENT }
const DENOMS := [2000, 1000, 500, 100, 25, 10, 5, 1]

var lane_x := 0.0
var counter_x := 0.0
var cash_x := 0.0
var face := 1.0
var index := 0
var label: Label3D
var screen: MeshInstance3D
var queue: Array = []
var belt: Array = []
var total := 0                    # cents
var state := R.IDLE
var payment := {}                 # {"method", "cash"}
var game: Node
var _flash := 0.0
var head_z := 6.2
var queue_min_z := 3.5

func setup(lane: Dictionary, g: Node) -> void:
	game = g
	lane_x = lane.lane_x
	counter_x = lane.counter_x
	cash_x = lane.cash_x
	face = lane.face
	index = lane.index
	label = lane.label
	screen = lane.screen
	lane.terminal.target = self
	_update_label()

func queue_size() -> int:
	return queue.size()

func spot(i: int) -> Vector3:
	# One spot per person. The line runs back toward the aisles, then folds
	# sideways so nobody is ever assigned the same point (that froze the queue).
	var spacing := 1.35
	var straight := maxi(int((head_z - queue_min_z) / spacing), 1)
	if i <= straight:
		return Vector3(lane_x, 0, head_z - spacing * float(i))
	var k := i - straight
	var side := -1.0 if lane_x < counter_x else 1.0
	return Vector3(lane_x + side * spacing * float(k), 0, queue_min_z)

func join(c: Node) -> Vector3:
	queue.append(c)
	return spot(queue.size() - 1)

func is_front(c: Node) -> bool:
	return not queue.is_empty() and queue[0] == c

func front() -> Node:
	return null if queue.is_empty() else queue[0]

func customer_at_front(c: Node) -> void:
	_clear_belt()
	total = 0
	payment = {}
	state = R.SCANNING
	var z := 4.95
	for p in c.items:
		var it = preload("res://scripts/belt_item.gd").new()
		add_child(it)
		it.setup(p, self)
		it.global_position = Vector3(counter_x + randf_range(-0.15, 0.15), 0.95 + p.size.y * 0.45, z)
		it.rotation.y = randf_range(-0.3, 0.3)
		belt.append(it)
		z += maxf(p.size.x, 0.14) * 0.9 + 0.12
		if z > 7.3:
			z = 5.1
	c.clear_basket()
	_update_label()

func scan(it: Node) -> void:
	if not belt.has(it):
		return
	belt.erase(it)
	total += Products.cents(it.product)
	it.queue_free()
	_flash = 0.15
	if game:
		game.play_sfx("beep")
		if game.player:
			game.player.scan_flash()
	if belt.is_empty() and front():
		state = R.PAYMENT
		payment = front().choose_payment(total)
		front().emote("Card" if payment.method == "card" else "Cash: $%.2f" % (payment.cash / 100.0), Color(0.8, 1, 0.8), 4.0)
	_update_label()

func change_due() -> int:
	return int(payment.get("cash", 0)) - total

## Card: one tap.
func finish_card() -> Dictionary:
	if state != R.PAYMENT or payment.method != "card":
		return {}
	return _complete({"method": "card", "total": total, "cash": 0, "change_due": 0, "change_given": 0, "earned": total, "tip": 0, "correct": true})

## Cash: the player counted out `given` cents of change.
## Earned = cash taken - change handed back (so over-paying change costs you).
## Short change annoys the customer and costs a $2 complaint penalty.
func finish_cash(given: int) -> Dictionary:
	if state != R.PAYMENT or payment.method != "cash":
		return {}
	var due := change_due()
	var res := {"method": "cash", "total": total, "cash": payment.cash, "change_due": due, "change_given": given, "tip": 0, "correct": given == due}
	res.earned = int(payment.cash) - given
	if given == due:
		if randf() < 0.4:
			res.tip = [100, 100, 200, 300].pick_random()
	elif given < due:
		res.earned -= 200
	return _complete(res)

func _complete(res: Dictionary) -> Dictionary:
	var c: Node = queue.pop_front()
	state = R.IDLE
	payment = {}
	total = 0
	var mood := "Thanks!"
	if not res.correct:
		mood = "Hey, you shorted me!" if res.change_given < res.change_due else "Uh... thanks?"
	elif res.tip > 0:
		mood = "Thanks! Keep the change."
	label.text = "LANE %d\nPAID $%.2f\nCHANGE $%.2f" % [index + 1, res.total / 100.0, res.change_given / 100.0]
	if game:
		game.play_sfx("chaching" if res.correct else "error")
	paid.emit(res)
	if c:
		c.pay_and_leave(mood)
	_advance()
	return res

func leave(c: Node) -> void:
	var was_front := is_front(c)
	queue.erase(c)
	if was_front:
		_clear_belt()
		total = 0
		state = R.IDLE
		payment = {}
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
	match state:
		R.PAYMENT:
			if payment.method == "card":
				label.text = "TOTAL $%.2f\nCARD - TAP E" % (total / 100.0)
			else:
				label.text = "TOTAL  $%.2f\nCASH   $%.2f\nCHANGE $%.2f" % [total / 100.0, payment.cash / 100.0, change_due() / 100.0]
		_:
			label.text = "LANE %d\n%d ITEMS\n$%.2f" % [index + 1, belt.size(), total / 100.0]

## Greedy change in DENOMS (used by tests and the "hint").
static func make_change(cents: int) -> Array:
	var out: Array = []
	var left := cents
	for d in DENOMS:
		while left >= d:
			out.append(d)
			left -= d
	return out

# ---- Interact target (register terminal) ----
func get_prompt_for(_body: Node, _player: Node) -> String:
	match state:
		R.PAYMENT:
			if payment.method == "card":
				return "[E] Run card  $%.2f" % (total / 100.0)
			return "[E] Open cash drawer  - Total $%.2f, Cash $%.2f" % [total / 100.0, payment.cash / 100.0]
		R.SCANNING:
			return "Scan the items on the belt (%d left)" % belt.size()
	return "Lane %d register" % (index + 1)

func on_interact(_body: Node, _player: Node) -> void:
	if state != R.PAYMENT:
		return
	if payment.method == "card":
		finish_card()
	elif game:
		game.open_change(self)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		screen.material_override = StoreBuilder.mat(Color(0.3, 1.0, 0.5), 3.0) if _flash > 0.0 else StoreBuilder.mat(Color(0.05, 0.2, 0.08), 1.4)
