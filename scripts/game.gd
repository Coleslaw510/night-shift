extends Node3D
## Main game controller. Builds the store, HUD, and (later steps) player/customers/clock.

var store := {}
var hud: CanvasLayer

func _ready() -> void:
	store = StoreBuilder.build(self)
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	var cam := Camera3D.new()
	cam.position = Vector3(9, 1.7, 12)
	add_child(cam)
	cam.look_at(Vector3(-2, 1.2, -8))
	cam.current = true

func _process(_delta: float) -> void:
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
