extends Node3D
## Main game controller. Builds the store, HUD, and (later steps) player/customers/clock.

var store := {}
var hud: CanvasLayer
var player: CharacterBody3D
var shift_over := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	store = StoreBuilder.build(self)
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.menu_pressed.connect(_to_menu)
	player = preload("res://scripts/player.gd").new()
	player.name = "Player"
	player.position = Vector3(-4.0, 0.05, 11.0)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.prompt_changed.connect(hud.set_prompt)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.toast("Click to grab the mouse. Customers check out at lanes 1 and 2.", 5.0)

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	_flicker()

func _flicker() -> void:
	# Two fixtures misbehave, like any good night-shift store.
	for i in [3, 8]:
		if i >= store.lights.size():
			continue
		var l: OmniLight3D = store.lights[i]
		var on := randf() > 0.08 if Engine.get_process_frames() % 240 < 60 else true
		l.visible = on
		var f: MeshInstance3D = l.get_meta("fixture")
		f.visible = on

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not shift_over:
		set_paused(not get_tree().paused)

func set_paused(on: bool) -> void:
	get_tree().paused = on
	hud.show_pause(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
