extends Control
## Main menu, built in code: Start Shift / Quit.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--server"):
		if NetworkSession.host():
			SaveGame.boot_mode = "new"
			get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
		return
	for arg in args:
		if str(arg).begins_with("--join="):
			if NetworkSession.join(str(arg).trim_prefix("--join=")):
				SaveGame.boot_mode = "new"
				get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
			return
	Settings.load_settings()
	if OS.has_feature("mobile"):
		get_tree().root.content_scale_factor = 1.3
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var title := Label.new()
	title.text = "NIGHT SHIFT"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "10 PM - 6 AM. Ring 'em up. Don't think about the noises."
	sub.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var net_title := Label.new()
	net_title.text = "CO-OP TEST LOBBY"
	net_title.add_theme_font_size_override("font_size", 22)
	net_title.add_theme_color_override("font_color", Color(0.95, 0.72, 0.32))
	net_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(net_title)
	var address := LineEdit.new()
	address.name = "ServerAddress"
	address.placeholder_text = "Server IP or hostname"
	address.text = "127.0.0.1"
	address.custom_minimum_size = Vector2(320, 44)
	box.add_child(address)
	var host := Button.new()
	host.text = "Host Co-op"
	host.custom_minimum_size = Vector2(260, 48)
	host.pressed.connect(_on_host)
	box.add_child(host)
	var join := Button.new()
	join.text = "Join Co-op"
	join.custom_minimum_size = Vector2(260, 48)
	join.pressed.connect(func(): _on_join(address.text))
	box.add_child(join)
	var net_status := Label.new()
	net_status.name = "NetworkStatus"
	net_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_status.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
	box.add_child(net_status)
	NetworkSession.status_changed.connect(func(t): net_status.text = t)
	var specs: Array = []
	if SaveGame.has_save():
		specs.append(["Continue", _on_continue])
	specs.append(["New Game", _on_new])
	if not OS.has_feature("mobile"):
		specs.append(["Quit", _on_quit])
	for spec in specs:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(260, 52)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(spec[1])
		box.add_child(b)
	var help := Label.new()
	help.text = ("Left stick move | Drag to look | USE grabs, rings up, stocks or drops | II pause\n\nv" + str(ProjectSettings.get_setting("application/config/version"))) if OS.has_feature("mobile") else "WASD move | Mouse look | Shift sprint | E use (hold to stock, or drop what you hold) | Q drop | Esc pause\n\nv" + str(ProjectSettings.get_setting("application/config/version"))
	help.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	# Re-center after layout.
	await get_tree().process_frame
	box.position = (size - box.size) * 0.5

func _on_continue() -> void:
	SaveGame.boot_mode = "continue"
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _on_new() -> void:
	SaveGame.wipe()
	SaveGame.boot_mode = "new"
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _on_host() -> void:
	if NetworkSession.host():
		SaveGame.boot_mode = "new"
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _on_join(address: String) -> void:
	if NetworkSession.join(address):
		SaveGame.boot_mode = "new"
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
