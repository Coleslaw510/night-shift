extends SceneTree
## Renders screenshots (needs a display, e.g. xvfb-run). Usage:
## xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --script res://tests/screenshot.gd -- OUTDIR
var frames := 0
var game: Node
var outdir := "user://"
# frame -> [pose, filename]
var plan := {150: ["interior", "interior"], 170: ["outside", "outside"], 190: ["front", "front"], 205: ["stockroom", "stockroom"], 225: ["change", "register_change"]}
var pending := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		outdir = args[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		Engine.time_scale = 10.0
		for i in 6:
			game.spawn_customer()
	if frames == 130:
		Engine.time_scale = 1.0
		game.customers_root.process_mode = Node.PROCESS_MODE_DISABLED
		game.hud.toast("")
	if pending != "" :
		var img := root.get_viewport().get_texture().get_image()
		var p := "%s/%s.png" % [outdir, pending]
		img.save_png(p)
		print("SHOT ", p)
		pending = ""
	for f in plan:
		if frames == f - 6:
			var pose: String = plan[f][0]
			if pose == "change":
				game.debug_pose("interior")
				game.hud.open_change(1377, 2000)
			else:
				game.debug_pose(pose)
		if frames == f:
			pending = plan[f][1]
	return frames >= 230
