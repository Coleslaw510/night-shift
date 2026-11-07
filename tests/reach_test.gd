extends SceneTree
## Headless reachability: the stockroom curtain, back office, gun locker,
## back door, dumpster, front door and fuel bay must all be walkable.
## Run: godot --headless --script res://tests/reach_test.gd

var frames := 0
var game: Node
var opened := false

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	print("REACH: loaded")

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		game.debug_open_routes()
		opened = true
	if frames < 8:
		return false
	var blocked: String = game.debug_route_block()
	var ok := blocked == ""
	if ok:
		print("REACH: clear")
	else:
		push_error("REACH: %s" % blocked)
		print("REACH: %s" % blocked)
	print("REACH: done ok=%s" % ok)
	quit(0 if ok else 1)
	return true
