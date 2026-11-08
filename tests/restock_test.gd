extends SceneTree
## v1.5 acceptance test: the first order must be understandable and completable.
## Run: godot --headless --script res://tests/restock_test.gd

var game: Node
var failed := false

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("main scene failed to load")
		return
	game = scene.instantiate()
	root.add_child(game)
	call_deferred("_run")

func _body(kind: String) -> Interact:
	var b := Interact.new()
	b.tag = {"kind": kind}
	return b

func _fail(message: String) -> void:
	failed = true
	push_error("RESTOCK: " + message)

func _run() -> void:
	await process_frame
	await process_frame
	if game == null or game.player == null:
		_fail("game or player did not initialize")
		quit(1)
		return
	if Products.CATALOG.size() <= 12 or Products.CATALOG[12].name != "Milk":
		_fail("milk product is missing from the catalog")
	if not game.store.has("milk_pallet") or not game.store.has("order_board"):
		_fail("dedicated milk pallet or order board is missing")
	if game.milk_order_progress != 0:
		_fail("order did not start at zero")

	var pallet := _body("supply_pallet")
	var boxes_before: int = game.milk_supply_boxes
	game.on_interact(pallet, game.player)
	if game.milk_supply_boxes != boxes_before - 1:
		_fail("taking the milk box did not reduce pallet quantity")
	if game.player.carrying.get("product", -1) != game.MILK_PRODUCT:
		_fail("milk pallet did not give the player a milk box")
	if int(game.player.carrying.get("count", 0)) != game.MILK_ORDER_TOTAL:
		_fail("milk box did not contain eight units")

	var freezer := _body("freezer")
	for i in game.MILK_ORDER_TOTAL:
		game.freezer_open = true
		game.on_interact(freezer, game.player)
	if game.milk_order_progress != game.MILK_ORDER_TOTAL:
		_fail("freezer stocking did not reach eight milk units")
	if not game.player.carrying.is_empty():
		_fail("milk box still had units after stocking the order")
	if not game.milk_customer_claimed and not game.claim_milk_customer(null):
		_fail("completed order did not unlock the milk customer")
	if game.store.order_board.text.find("SERVE MILK CUSTOMER") < 0:
		_fail("physical order board did not update to the customer step")

	print("RESTOCK: milk box taken, eight units stocked, customer unlocked")
	print("RESTOCK: done ok=%s" % str(not failed))
	quit(1 if failed else 0)
