class_name Interact
extends StaticBody3D
## Generic interactable collider. Forwards player interaction to `target`:
##   target.on_interact(body, player), target.get_prompt_for(body, player) -> String,
##   target.on_hold(body, player, delta) (optional, while E/click is held).
## `tag` carries whatever the target needs (e.g. {"kind": "crate", "product": 3}).

var target: Object
var tag: Variant = null

static func make(parent: Node, size: Vector3, pos: Vector3, tgt: Object, t: Variant = null) -> Interact:
	var sb := Interact.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.target = tgt
	sb.tag = t
	parent.add_child(sb)
	return sb

func interact(p: Node) -> void:
	if target and target.has_method("on_interact"):
		target.on_interact(self, p)

func get_prompt(p: Node) -> String:
	if target and target.has_method("get_prompt_for"):
		return target.get_prompt_for(self, p)
	return ""

func hold_interact(p: Node, delta: float) -> void:
	if target and target.has_method("on_hold"):
		target.on_hold(self, p, delta)
