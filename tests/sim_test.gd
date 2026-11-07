extends SceneTree
## Proves the 1.2 loops headless: customers get served, cars leave, a fuel
## job pays, a cart can be returned, and a save round-trips (including a v1 file).
## Run: godot --headless --script res://tests/sim_test.gd

var game: Node
var acc := 0.0
var fuel_done := false
var cart_done := false
var save_done := false
var started := false

func _initialize() -> void:
	Engine.time_scale = 12.0
	Engine.max_fps = 30
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	print("SIM: started")

func _process(delta: float) -> bool:
	if not started:
		started = true
		game.sim_mode = true
		for i in 8:
			var c: Node = game._spawn_walker()
			if c:
				c.wants_cart = true
	acc += delta
	_serve()
	if not cart_done and acc > 1.0:
		cart_done = _return_cart()
	if not fuel_done:
		_fuel()
	if acc > 180.0:
		game.allow_spawn = false
	var alive: int = game.customers_root.get_child_count()
	var ready: bool = acc > 200.0 and alive == 0 and int(game.stats.served) >= 8 and int(game.stats.walked) == 0 and game.cars_departed >= 1 and int(game.stats.fuel) >= 1 and int(game.stats.carts) >= 1
	if ready or acc > 480.0:
		if not save_done:
			save_done = _save_roundtrip()
		var ok: bool = ready and save_done
		print("SIM: t=%.0f served=%s walked=%s alive=%d cars=%d fuel=%s carts=%s save=%s" % [acc, game.stats.served, game.stats.walked, alive, game.cars_departed, game.stats.fuel, game.stats.carts, save_done])
		print("SIM: done ok=%s" % ok)
		quit(0 if ok else 1)
		return true
	return false

func _serve() -> void:
	for r in game.registers:
		if not r.belt.is_empty():
			r.scan(r.belt[0])
		elif r.state == 2 and not r.payment.is_empty():
			if r.payment.method == "card":
				r.finish_card()
			else:
				var given := 0
				for coin in r.make_change(r.change_due()):
					given += int(coin)
				r.finish_cash(given)

func _return_cart() -> bool:
	var cart: Node = game.nearest_free_cart(game.store.corral.pos)
	if cart == null:
		return false
	cart.release()
	cart.touched_by_player = true
	cart.paid = false
	cart.global_position = game.store.corral.pos
	game._collect_stray_carts()
	return int(game.stats.carts) >= 1

func _fuel() -> void:
	if int(game.stats.fuel) >= 1:
		fuel_done = true
		return
	var pumps: Array = []
	for car in game.cars_root.get_children():
		if car.is_fuel and car.vstate == 3:
			pumps.append(car)
	if pumps.is_empty():
		if game._free_pump() != null and acc > 2.0 and acc < 30.0:
			game.spawn_fuel_car()
		return
	var car: Node = pumps[0]
	if game.fuel_for(car) == null:
		game.fuel_interact(car)
		return
	if not game.fuel_is_running():
		game.fuel_interact(car)
		return
	game.fuel_job.value = float(game.fuel_job.target)
	game.fuel_stop()

func _save_roundtrip() -> bool:
	game.stats.earnings = 4321
	game.owned["flashlight"] = true
	game.ammo = 11
	game.shifts_done = 4
	var was: bool = game.sim_mode
	game.sim_mode = false
	if not game.save_progress():
		return false
	game.sim_mode = was
	game.stats.earnings = 5
	game.owned.erase("flashlight")
	var loaded: Dictionary = SaveGame.read()
	var legacy: Dictionary = SaveGame.migrate({"version": 1, "earnings": 654})
	var ok: bool = int(loaded.get("money", -1)) == 4321 and loaded.get("owned", {}).has("flashlight") and int(loaded.get("ammo", 0)) == 11 and int(loaded.get("shifts_done", 0)) == 4 and int(legacy.get("money", -1)) == 654 and int(legacy.get("version", 0)) == 2 and legacy.has("owned")
	print("SIM: save ok=%s legacy_money=%s" % [ok, legacy.get("money", -1)])
	return ok
