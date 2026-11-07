extends SceneTree
## Renders screenshots (needs a display, e.g. xvfb-run). Usage:
## xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --script res://tests/screenshot.gd -- OUTDIR
var frames := 0
var game: Node
var outdir := "user://"
var shots := []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		outdir = args[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)

func _process(_d: float) -> bool:
	frames += 1
	if game.has_method("debug_screenshot_setup"):
		game.debug_screenshot_setup(frames)
	if frames in [139, 200]:
		var img := root.get_viewport().get_texture().get_image()
		var p := "%s/shot_%d.png" % [outdir, frames]
		img.save_png(p)
		print("SHOT ", p)
	return frames >= 201
