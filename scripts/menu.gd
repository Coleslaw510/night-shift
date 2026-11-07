extends Control
## Main menu, built in code: Start Shift / Quit.

func _ready() -> void:
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
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_new() -> void:
	SaveGame.wipe()
	SaveGame.boot_mode = "new"
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit() -> void:
	get_tree().quit()
