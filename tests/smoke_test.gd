extends SceneTree
## Headless smoke test: loads the main scene, fast-forwards part of a shift,
## exercises customers + checkout, then quits. CI fails on any SCRIPT ERROR in the log
## or a non-zero exit code.
## Run: godot --headless --script res://tests/smoke_test.gd

var frames := 0
var game: Node = null
var failed := false

func _initialize() -> void:
	Engine.time_scale = 10.0
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("SMOKE: main scene failed to load")
		quit(1)
		return
	game = scene.instantiate()
	root.add_child(game)
	print("SMOKE: main scene loaded")

func _process(_delta: float) -> bool:
	frames += 1
	if game and game.has_method("debug_tick"):
		game.debug_tick(frames)
	if frames >= 1800:
		var ok := false
		if game and game.has_method("debug_report"):
			ok = game.debug_report()
		else:
			push_error("SMOKE: game script missing debug_report (script failed to load?)")
		print("SMOKE: done after %d frames, ok=%s" % [frames, ok])
		Engine.time_scale = 1.0
		quit(0 if ok else 1)
		return true
	return false
