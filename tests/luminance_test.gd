extends SceneTree
## Renders the sales floor, stockroom, and lot at Low and High and checks
## average luminance. The floor must be readable on Low, and High must not
## be a different exposure. Run with a display:
## xvfb-run -s "-screen 0 640x360x24" godot --rendering-driver opengl3 --script res://tests/luminance_test.gd

var game: Node
var frames := 0
var plan: Array = []
var luma := {}
var shot_i := 0
var armed := false

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for preset in ["low", "high"]:
		for shot in ["floor", "stock", "lot"]:
			plan.append([preset, shot])
	print("LUMA: loaded")

func _process(_d: float) -> bool:
	frames += 1
	if frames < 4:
		return false
	if not armed:
		var item: Array = plan[shot_i]
		_arm(str(item[0]), str(item[1]))
		armed = true
		return false
	var key := "%s_%s" % [plan[shot_i][0], plan[shot_i][1]]
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("LUMA: no image for %s" % key)
		print("LUMA: done ok=false")
		quit(1)
		return true
	luma[key] = _center_luma(img)
	print("LUMA %s %.3f" % [key, luma[key]])
	shot_i += 1
	armed = false
	if shot_i >= plan.size():
		var ok := _judge()
		print("LUMA: done ok=%s" % ok)
		quit(0 if ok else 1)
		return true
	return false

func _arm(preset: String, shot: String) -> void:
	Settings.gfx_preset = preset
	Settings.gfx_brightness = 1.0
	Settings.gfx_scale = 1.0
	game.apply_graphics()
	game.hud.visible = false
	if game.player.viewmodel:
		game.player.viewmodel.visible = false
	var p: Node3D = game.player
	p.cam.rotation.x = deg_to_rad(-8)
	match shot:
		"floor":
			p.position = Vector3(0, 0.05, 16)
			p.rotation.y = 0
		"stock":
			p.position = Vector3(0, 0.05, -24)
			p.rotation.y = PI
		"lot":
			p.position = Vector3(4, 0.05, 35)
			p.rotation.y = deg_to_rad(70)
			p.cam.rotation.x = deg_to_rad(-16)

func _center_luma(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := int(w * 0.2)
	var x1 := int(w * 0.8)
	var y0 := int(h * 0.25)
	var y1 := int(h * 0.8)
	var sum := 0.0
	var n := 0
	var step := 2
	for y in range(y0, y1, step):
		for x in range(x0, x1, step):
			var c := img.get_pixel(x, y)
			sum += c.get_luminance()
			n += 1
	return sum / maxf(1.0, float(n))

func _judge() -> bool:
	var floor_lo: float = luma.get("low_floor", 0.0)
	var floor_hi: float = luma.get("high_floor", 0.0)
	var stock_lo: float = luma.get("low_stock", 0.0)
	var stock_hi: float = luma.get("high_stock", 0.0)
	var lot_lo: float = luma.get("low_lot", 0.0)
	var lot_hi: float = luma.get("high_lot", 0.0)
	var ok := true
	# Sales floor is the bar. Both presets must clear it, and stay near each other.
	if floor_lo < 0.18 or floor_hi < 0.18:
		push_error("LUMA: sales floor too dark low=%.3f high=%.3f" % [floor_lo, floor_hi])
		ok = false
	var ratio := floor_hi / maxf(floor_lo, 0.001)
	if ratio < 0.6 or ratio > 1.75:
		push_error("LUMA: low/high floor brightness diverged ratio=%.2f" % ratio)
		ok = false
	if stock_lo < 0.08 or stock_hi < 0.08:
		push_error("LUMA: stockroom too dark low=%.3f high=%.3f" % [stock_lo, stock_hi])
		ok = false
	if stock_lo > floor_lo * 1.15:
		push_error("LUMA: stockroom brighter than the sales floor")
		ok = false
	if lot_lo < 0.04 or lot_hi < 0.04:
		push_error("LUMA: lot unreadable low=%.3f high=%.3f" % [lot_lo, lot_hi])
		ok = false
	if lot_lo > floor_lo * 0.95:
		push_error("LUMA: lot is not darker than the sales floor")
		ok = false
	return ok
