class_name StoreBuilder
## Builds the whole store from primitive meshes. Returns a Dictionary of useful refs:
##   lights: Array[OmniLight3D] (flicker candidates), lanes: Array[Dictionary]
## Layout constants are documented in HANDOFF.md.

const W := 24.0
const D := 30.0
const H := 4.0
const SHELF_X := [-8.0, -4.0, 0.0, 4.0, 8.0]
const SHELF_Z0 := -9.0
const SHELF_Z1 := 1.0
const LANE_X := [-6.0, -2.0]   # customer side of each checkout lane
const DOOR_X := 7.0

static var _mats := {}

static func mat(c: Color, emission: float = 0.0, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [c, emission, rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		add_collider(parent, size, pos)
	return mi

static func add_collider(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)
	return sb

static func build(root: Node3D) -> Dictionary:
	var store := Node3D.new()
	store.name = "Store"
	root.add_child(store)
	var out := {"lights": [], "lanes": []}
	_environment(root)
	_shell(store, out)
	var mm_xforms: Array = []
	var mm_colors: Array = []
	_shelves(store, mm_xforms, mm_colors)
	_freezer(store, mm_xforms, mm_colors)
	_products_multimesh(store, mm_xforms, mm_colors)
	_checkouts(store, out)
	return out

static func _environment(root: Node3D) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.45)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.08)
	env.fog_density = 0.012
	we.environment = env
	root.add_child(we)

static func _shell(store: Node3D, out: Dictionary) -> void:
	var hw := W * 0.5
	var hd := D * 0.5
	# Floor: checker tiles (split so each mesh gets few lights in Compatibility renderer).
	var tile := 3.0
	var fa := mat(Color(0.62, 0.64, 0.6), 0.0, 0.35)
	var fb := mat(Color(0.48, 0.52, 0.5), 0.0, 0.35)
	var ix := 0
	var x := -hw
	while x < hw:
		var iz := 0
		var z := -hd
		while z < hd:
			box(store, Vector3(tile, 0.1, tile), Vector3(x + tile * 0.5, -0.05, z + tile * 0.5), fa if (ix + iz) % 2 == 0 else fb)
			z += tile
			iz += 1
		x += tile
		ix += 1
	add_collider(store, Vector3(W + 20, 0.2, D + 20), Vector3(0, -0.1, 0))
	# Ceiling
	box(store, Vector3(W, 0.1, D), Vector3(0, H + 0.05, 0), mat(Color(0.18, 0.19, 0.2)))
	# Walls
	var wall := mat(Color(0.55, 0.6, 0.55))
	var stripe := mat(Color(0.1, 0.45, 0.35))
	box(store, Vector3(W, H, 0.2), Vector3(0, H * 0.5, -hd - 0.1), wall, true)
	box(store, Vector3(0.2, H, D), Vector3(-hw - 0.1, H * 0.5, 0), wall, true)
	box(store, Vector3(0.2, H, D), Vector3(hw + 0.1, H * 0.5, 0), wall, true)
	for s in [-1, 1]:
		box(store, Vector3(0.05, 0.3, D), Vector3(s * (hw - 0.02), 2.6, 0), stripe)
	box(store, Vector3(W, 0.3, 0.05), Vector3(0, 2.6, -hd + 0.02), stripe)
	# Front wall: kick wall + header + dark glass, door gap at DOOR_X.
	var frame := mat(Color(0.25, 0.27, 0.28), 0.0, 0.4, 0.6)
	var glass := mat(Color(0.02, 0.04, 0.08, 0.85), 0.0, 0.05, 0.3)
	box(store, Vector3(W, 0.6, 0.25), Vector3(0, 0.3, hd), frame)
	box(store, Vector3(W, 0.9, 0.25), Vector3(0, H - 0.45, hd), frame)
	box(store, Vector3(W, H - 1.5, 0.05), Vector3(0, 0.6 + (H - 1.5) * 0.5, hd), glass)
	var px := -hw
	while px <= hw:
		box(store, Vector3(0.12, H, 0.27), Vector3(px, H * 0.5, hd), frame)
		px += 3.0
	add_collider(store, Vector3(W, H, 0.3), Vector3(0, H * 0.5, hd))
	# Door frame + mat
	box(store, Vector3(2.4, 0.02, 1.4), Vector3(DOOR_X, 0.01, hd - 0.8), mat(Color(0.1, 0.1, 0.12)))
	box(store, Vector3(2.2, 0.35, 0.3), Vector3(DOOR_X, 3.4, hd - 0.05), mat(Color(0.9, 0.15, 0.1), 2.0))
	# Outside: dark parking lot + an orange street lamp.
	box(store, Vector3(60, 0.1, 30), Vector3(0, -0.06, hd + 15.2), mat(Color(0.05, 0.05, 0.06)))
	for lx in [-9.0, 11.0]:
		box(store, Vector3(0.15, 6, 0.15), Vector3(lx, 3, hd + 9), mat(Color(0.2, 0.2, 0.2)))
		box(store, Vector3(0.8, 0.15, 0.4), Vector3(lx, 6, hd + 9), mat(Color(1.0, 0.6, 0.2), 3.0))
		var sl := OmniLight3D.new()
		sl.light_color = Color(1.0, 0.6, 0.25)
		sl.omni_range = 10.0
		sl.light_energy = 1.2
		sl.position = Vector3(lx, 5.5, hd + 9)
		store.add_child(sl)
	# Fluorescent ceiling fixtures
	var tube := mat(Color(0.85, 1.0, 0.9), 3.0)
	for fx in [-7.0, 0.0, 7.0]:
		for fz in [-12.0, -5.0, 2.0, 9.0]:
			var f := box(store, Vector3(0.35, 0.08, 2.4), Vector3(fx, H - 0.06, fz), tube)
			var l := OmniLight3D.new()
			l.light_color = Color(0.85, 1.0, 0.9)
			l.light_energy = 0.9
			l.omni_range = 9.0
			l.omni_attenuation = 1.2
			l.position = Vector3(fx, H - 0.4, fz)
			store.add_child(l)
			l.set_meta("fixture", f)
			out.lights.append(l)

static func _shelves(store: Node3D, xf: Array, cols: Array) -> void:
	var metal := mat(Color(0.55, 0.57, 0.6), 0.0, 0.45, 0.6)
	var dark := mat(Color(0.2, 0.22, 0.25), 0.0, 0.6, 0.3)
	var length := SHELF_Z1 - SHELF_Z0
	var cz := (SHELF_Z0 + SHELF_Z1) * 0.5
	var levels := [0.15, 0.6, 1.05, 1.5]
	for sx in SHELF_X:
		box(store, Vector3(1.1, 0.15, length), Vector3(sx, 0.075, cz), dark)
		box(store, Vector3(0.06, 1.95, length), Vector3(sx, 0.975, cz), metal)
		for e in [SHELF_Z0, SHELF_Z1]:
			box(store, Vector3(1.1, 1.95, 0.05), Vector3(sx, 0.975, e), metal)
		add_collider(store, Vector3(1.1, 2.0, length), Vector3(sx, 1.0, cz))
		for lv in levels:
			box(store, Vector3(1.05, 0.03, length), Vector3(sx, lv, cz), metal)
			for side in [-1, 1]:
				var z := SHELF_Z0 + 0.15
				while z < SHELF_Z1 - 0.2:
					var p: Dictionary = Products.random()
					var s: Vector3 = p.size
					var n := randi_range(1, 3)
					for k in n:
						if z > SHELF_Z1 - 0.2:
							break
						var t := Transform3D(Basis.IDENTITY.scaled(Vector3(s.z * 1.6, s.y, s.x)), Vector3(sx + side * 0.28, lv + 0.015 + s.y * 0.5, z + s.x * 0.5))
						xf.append(t)
						cols.append(p.color)
						z += s.x + 0.02
					z += 0.06
	# Aisle signs hanging from ceiling
	var sign_m := mat(Color(0.1, 0.5, 0.4), 0.6)
	for i in range(SHELF_X.size() + 1):
		var ax: float = -10.0 + i * 4.0
		box(store, Vector3(1.2, 0.4, 0.05), Vector3(ax, 3.2, 2.0), sign_m)
		var lab := Label3D.new()
		lab.text = "AISLE %d" % (i + 1)
		lab.font_size = 48
		lab.pixel_size = 0.004
		lab.position = Vector3(ax, 3.2, 2.04)
		store.add_child(lab)

static func _freezer(store: Node3D, xf: Array, cols: Array) -> void:
	var z := -D * 0.5 + 0.7
	var body := mat(Color(0.85, 0.88, 0.9), 0.0, 0.4, 0.2)
	var glow := mat(Color(0.55, 0.85, 1.0), 2.2)
	var glass := mat(Color(0.6, 0.85, 1.0, 0.25), 0.4, 0.05)
	box(store, Vector3(18, 2.4, 1.3), Vector3(0, 1.2, z - 0.05), body)
	add_collider(store, Vector3(18, 2.4, 1.4), Vector3(0, 1.2, z))
	box(store, Vector3(17.6, 1.9, 0.05), Vector3(0, 1.2, z + 0.55), glow)
	box(store, Vector3(17.6, 1.9, 0.05), Vector3(0, 1.2, z + 0.67), glass)
	var dx := -8.5
	while dx <= 8.6:
		box(store, Vector3(0.08, 2.0, 0.1), Vector3(dx, 1.2, z + 0.68), mat(Color(0.3, 0.32, 0.35), 0.0, 0.3, 0.7))
		dx += 1.5
	for lv in [0.45, 1.0, 1.55]:
		var x := -8.5
		while x < 8.5:
			var p: Dictionary = Products.CATALOG[[8, 11, 9, 1][randi() % 4]]
			var s: Vector3 = p.size
			xf.append(Transform3D(Basis.IDENTITY.scaled(s * 1.2), Vector3(x, lv + s.y * 0.6, z + 0.5)))
			cols.append(p.color)
			x += s.x * 1.2 + 0.08
	var fl := OmniLight3D.new()
	fl.light_color = Color(0.5, 0.8, 1.0)
	fl.light_energy = 1.5
	fl.omni_range = 7.0
	fl.position = Vector3(0, 1.4, z + 2.0)
	store.add_child(fl)
	var sign_l := Label3D.new()
	sign_l.text = "FROZEN"
	sign_l.font_size = 96
	sign_l.pixel_size = 0.006
	sign_l.modulate = Color(0.6, 0.9, 1.0)
	sign_l.position = Vector3(0, 2.9, z + 0.2)
	store.add_child(sign_l)

static func _products_multimesh(store: Node3D, xf: Array, cols: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.6
	mmi.material_override = m
	store.add_child(mmi)

static func _checkouts(store: Node3D, out: Dictionary) -> void:
	var counter_m := mat(Color(0.2, 0.32, 0.3), 0.0, 0.5)
	var top_m := mat(Color(0.7, 0.72, 0.7), 0.0, 0.3, 0.4)
	var belt_m := mat(Color(0.05, 0.05, 0.06), 0.0, 0.9)
	var reg_m := mat(Color(0.12, 0.12, 0.14), 0.0, 0.4, 0.3)
	for i in LANE_X.size():
		var lx: float = LANE_X[i]
		var cx := lx - 1.0
		var lane_root := Node3D.new()
		lane_root.name = "Lane%d" % (i + 1)
		store.add_child(lane_root)
		box(lane_root, Vector3(0.75, 0.88, 4.0), Vector3(cx, 0.44, 7.0), counter_m, true)
		box(lane_root, Vector3(0.8, 0.04, 4.05), Vector3(cx, 0.9, 7.0), top_m)
		box(lane_root, Vector3(0.6, 0.03, 2.4), Vector3(cx, 0.93, 6.3), belt_m)
		for bz in [5.1, 7.5]:
			box(lane_root, Vector3(0.62, 0.06, 0.06), Vector3(cx, 0.94, bz), top_m)
		# scanner
		box(lane_root, Vector3(0.4, 0.02, 0.3), Vector3(cx, 0.93, 7.8), mat(Color(1.0, 0.1, 0.1), 2.0))
		# register + screen (screen faces cashier at -X)
		box(lane_root, Vector3(0.45, 0.25, 0.4), Vector3(cx - 0.05, 1.05, 8.4), reg_m)
		box(lane_root, Vector3(0.06, 0.32, 0.45), Vector3(cx - 0.1, 1.38, 8.4), reg_m)
		var scr := box(lane_root, Vector3(0.02, 0.26, 0.4), Vector3(cx - 0.14, 1.38, 8.4), mat(Color(0.05, 0.25, 0.12), 1.5))
		var lab := Label3D.new()
		lab.text = "LANE %d\n$0.00" % (i + 1)
		lab.font_size = 40
		lab.pixel_size = 0.0022
		lab.modulate = Color(0.6, 1.0, 0.7)
		lab.position = Vector3(cx - 0.16, 1.38, 8.4)
		lab.rotation.y = -PI * 0.5
		lane_root.add_child(lab)
		# lane light pole + number
		box(lane_root, Vector3(0.06, 1.4, 0.06), Vector3(cx, 1.6, 8.9), reg_m)
		box(lane_root, Vector3(0.3, 0.3, 0.3), Vector3(cx, 2.4, 8.9), mat(Color(0.2, 0.9, 0.4), 2.5))
		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 64
		num.pixel_size = 0.005
		num.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		num.position = Vector3(cx, 2.8, 8.9)
		lane_root.add_child(num)
		out.lanes.append({"index": i, "lane_x": lx, "counter_x": cx, "root": lane_root, "label": lab, "screen": scr})
