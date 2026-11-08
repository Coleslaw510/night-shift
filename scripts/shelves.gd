class_name ShelfSystem
extends Node3D
## Aisle shelving + stock. Each shelf row has 2 faces x 4 levels x 8 slots; every slot holds
## one product type and a count (0..cap). Products are drawn with one MultiMesh (boxes) plus
## one for their labels; empty units are hidden. Customers `take()`, the player `place()`s.

signal stocked(product_idx: int)

const LEVELS := [0.12, 0.56, 1.0, 1.44]
const VIS := Vector3(1.25, 1.25, 1.0)   # products are drawn a bit chunkier on shelves
const SLOTS := 8
const DEPTH := 0.55            # half-depth of a shelf row (x)
var HIDE := Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0))

var slots: Array = []          # Array[Dictionary]
var mm: MultiMesh
var mm_label: MultiMesh
var tag_mm: MultiMesh
var tag_rest: Array = []
var tag_row: Array = []
var row_nodes: Array = []
var slot_ranges: Array = []
var _row_on: Array = []
var slot_len := 0.0

func build() -> void:
	name = "Shelves"
	slot_len = (StoreBuilder.SHELF_Z1 - StoreBuilder.SHELF_Z0 - 0.3) / SLOTS
	var metal := StoreBuilder.mat(Color(0.2, 0.2, 0.22), 0.0, 0.5, 0.6)
	var board := StoreBuilder.mat(Color(0.28, 0.28, 0.3), 0.0, 0.45, 0.5)
	var tag := StoreBuilder.mat(Color(0.92, 0.92, 0.88), 0.2)
	var length: float = StoreBuilder.SHELF_Z1 - StoreBuilder.SHELF_Z0
	var cz: float = (StoreBuilder.SHELF_Z0 + StoreBuilder.SHELF_Z1) * 0.5
	for r in StoreBuilder.SHELF_X.size():
		var sx: float = StoreBuilder.SHELF_X[r]
		var row := Node3D.new()
		row.name = "ShelfRow%d" % r
		add_child(row)
		row_nodes.append(row)
		_row_on.append(true)
		var metal_xf: Array = []
		var board_xf: Array = []
		metal_xf.append(Transform3D(Basis.from_scale(Vector3(DEPTH * 2, 0.1, length)), Vector3(sx, 0.05, cz)))
		StoreBuilder.box(row, Vector3(0.04, 1.85, length), Vector3(sx, 0.95, cz), StoreBuilder.mat(Color(0.14, 0.14, 0.15), 0.0, 0.8))
		var z: float = StoreBuilder.SHELF_Z0
		while z <= StoreBuilder.SHELF_Z1 + 0.01:
			for side in [-1, 1]:
				metal_xf.append(Transform3D(Basis.from_scale(Vector3(0.05, 1.9, 0.05)), Vector3(sx + side * DEPTH, 0.95, z)))
			z += length / 4.0
		for lv in LEVELS:
			board_xf.append(Transform3D(Basis.from_scale(Vector3(DEPTH * 2, 0.03, length)), Vector3(sx, lv, cz)))
			for side in [-1, 1]:
				metal_xf.append(Transform3D(Basis.from_scale(Vector3(0.02, 0.05, length)), Vector3(sx + side * (DEPTH + 0.01), lv - 0.01, cz)))
		StoreBuilder._multibox(row, metal_xf, metal)
		StoreBuilder._multibox(row, board_xf, board)
		# collider = the interact surface for stocking
		Interact.make(row, Vector3(DEPTH * 2, 1.9, length), Vector3(sx, 0.95, cz), self, {"kind": "shelf", "row": r})
		var slot0 := slots.size()
		# slots
		for side in [-1, 1]:
			# each face gets a few product "bands" so it looks merchandised
			for li in LEVELS.size():
				for si in SLOTS:
					var pidx: int = Products.SHELF_ITEMS[(r * 7 + li * 3 + si / 2 + (1 if side > 0 else 0) * 4) % Products.SHELF_ITEMS.size()]
					if randf() < 0.25:
						pidx = Products.SHELF_ITEMS.pick_random()
					var p: Dictionary = Products.CATALOG[pidx]
					var s: Vector3 = p.size * VIS
					var cap := clampi(int((slot_len - 0.04) / (s.x + 0.015)), 2, 12)
					var count := randi_range(cap / 2, cap) if randf() < 0.85 else randi_range(0, 1)
					var z0: float = StoreBuilder.SHELF_Z0 + 0.15 + si * slot_len
					slots.append({"row": r, "side": side, "level": li, "idx": si, "product": pidx, "cap": cap, "count": count, "z0": z0, "inst": 0})
				# price tags along the shelf edge
				for si in SLOTS:
					var tz: float = StoreBuilder.SHELF_Z0 + 0.15 + (si + 0.5) * slot_len
					tag_rest.append(Transform3D(Basis.from_scale(Vector3(0.012, 0.04, 0.09)), Vector3(sx + side * (DEPTH + 0.025), LEVELS[li] - 0.01, tz)))
					tag_row.append(r)
		slot_ranges.append([slot0, slots.size()])
	_build_tags(tag)
	_build_multimesh()
	for i in slots.size():
		_refresh(i)

func _build_tags(mat: Material) -> void:
	tag_mm = MultiMesh.new()
	tag_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	tag_mm.mesh = bm
	tag_mm.instance_count = tag_rest.size()
	for i in tag_rest.size():
		tag_mm.set_instance_transform(i, tag_rest[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = tag_mm
	mmi.material_override = mat
	add_child(mmi)

func _hide_slot(i: int) -> void:
	var s: Dictionary = slots[i]
	for u in s.cap:
		var id: int = s.inst + u
		mm.set_instance_transform(id, HIDE)
		mm_label.set_instance_transform(id, HIDE)

## max_dist <= 0 shows every row. Otherwise rows far from the player on X are hidden.
func update_cull(player_x: float, max_dist: float) -> void:
	for r in row_nodes.size():
		var show := max_dist <= 0.0 or absf(StoreBuilder.SHELF_X[r] - player_x) <= max_dist
		if _row_on[r] == show:
			continue
		_row_on[r] = show
		row_nodes[r].visible = show
		var span: Array = slot_ranges[r]
		if show:
			for i in range(int(span[0]), int(span[1])):
				_refresh(i)
		else:
			for i in range(int(span[0]), int(span[1])):
				_hide_slot(i)
		for t in tag_row.size():
			if int(tag_row[t]) != r:
				continue
			tag_mm.set_instance_transform(t, tag_rest[t] if show else HIDE)

func _build_multimesh() -> void:
	var total := 0
	for s in slots:
		s.inst = total
		total += s.cap
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = total
	mm_label = MultiMesh.new()
	mm_label.transform_format = MultiMesh.TRANSFORM_3D
	mm_label.use_colors = true
	mm_label.mesh = bm
	mm_label.instance_count = total
	for m in [mm, mm_label]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = m
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.75
		mmi.material_override = mat
		add_child(mmi)

func _refresh(i: int) -> void:
	var s: Dictionary = slots[i]
	var p: Dictionary = Products.CATALOG[s.product]
	var sz: Vector3 = p.size * VIS
	var sz_y := minf(sz.y, 0.4)
	sz.y = sz_y
	var sx: float = StoreBuilder.SHELF_X[s.row]
	var depth := minf(sz.z * 2.2, 0.42)
	var x: float = sx + s.side * (DEPTH - 0.03 - depth * 0.5)
	var y: float = LEVELS[s.level] + 0.015 + sz.y * 0.5
	var lc := Products.label_color(p)
	for u in s.cap:
		var id: int = s.inst + u
		if u < s.count:
			var z: float = s.z0 + 0.03 + (u + 0.5) * (sz.x + 0.015)
			mm.set_instance_transform(id, Transform3D(Basis.from_scale(Vector3(depth, sz.y, sz.x)), Vector3(x, y, z)))
			mm.set_instance_color(id, p.color)
			var lx: float = x + s.side * (depth * 0.5 + 0.002)
			mm_label.set_instance_transform(id, Transform3D(Basis.from_scale(Vector3(0.004, sz.y * 0.3, sz.x * 0.75)), Vector3(lx, y + sz.y * 0.08, z)))
			mm_label.set_instance_color(id, lc)
		else:
			mm.set_instance_transform(id, HIDE)
			mm_label.set_instance_transform(id, HIDE)

## Customer takes one item from the face of `row` on `side` near z. Returns the product
## dictionary, or {"missing": product} if that spot is out of stock.
func take(row: int, side: int, z: float) -> Dictionary:
	var si := clampi(int((z - StoreBuilder.SHELF_Z0 - 0.15) / slot_len), 0, SLOTS - 1)
	var order := [0, 1, 2, 3]
	order.shuffle()
	var first_missing := -1
	for li in order:
		var i := slot_index(row, side, li, si)
		if slots[i].count > 0:
			slots[i].count -= 1
			_refresh(i)
			return Products.CATALOG[slots[i].product]
		if first_missing < 0:
			first_missing = i
	return {"missing": Products.CATALOG[slots[first_missing].product]}

func slot_index(row: int, side: int, level: int, si: int) -> int:
	return ((row * 2 + (0 if side < 0 else 1)) * LEVELS.size() + level) * SLOTS + si

func slot_at(row: int, hit: Vector3) -> int:
	var sx: float = StoreBuilder.SHELF_X[row]
	var side := -1 if hit.x < sx else 1
	var li := 0
	for k in LEVELS.size():
		if hit.y >= LEVELS[k] - 0.02:
			li = k
	var si := clampi(int((hit.z - StoreBuilder.SHELF_Z0 - 0.15) / slot_len), 0, SLOTS - 1)
	return slot_index(row, side, li, si)

## Player places one unit from the carried box into slot i. Returns "" on success or a reason.
func place(i: int, product_idx: int) -> String:
	var s: Dictionary = slots[i]
	if s.product != product_idx:
		return "This spot is for %s" % Products.CATALOG[s.product].name
	if s.count >= s.cap:
		return "Full"
	s.count += 1
	_refresh(i)
	stocked.emit(product_idx)
	return ""

func fill_ratio(product_idx: int) -> float:
	var have := 0
	var cap := 0
	for s in slots:
		if s.product == product_idx:
			have += s.count
			cap += s.cap
	return float(have) / maxf(1.0, cap)

func low_products(threshold := 0.3) -> Array:
	var outl: Array = []
	for pidx in Products.SHELF_ITEMS:
		if fill_ratio(pidx) < threshold:
			outl.append(Products.CATALOG[pidx].name)
	return outl

func total_fill() -> float:
	var have := 0
	var cap := 0
	for s in slots:
		have += s.count
		cap += s.cap
	return float(have) / maxf(1.0, cap)

func damage_row_near(x: float) -> void:
	var best := -1
	var dist := INF
	for r in StoreBuilder.SHELF_X.size():
		var d := absf(StoreBuilder.SHELF_X[r] - x)
		if d < dist:
			dist = d
			best = r
	if best >= 0 and best < row_nodes.size():
		row_nodes[best].visible = false
		_row_on[best] = false

# ---- Interact target (shelf colliders) ----
var _hold_t := 0.0

func _player_slot(body: Node, player: Node) -> int:
	if not player.ray.is_colliding():
		return -1
	return slot_at(body.tag.row, player.ray.get_collision_point())

func get_prompt_for(body: Node, player: Node) -> String:
	var i := _player_slot(body, player)
	if i < 0:
		return ""
	var s: Dictionary = slots[i]
	var p: Dictionary = Products.CATALOG[s.product]
	if player.carrying.get("kind", "") == "stock":
		if player.carrying.product != s.product:
			return "Spot is for %s  (%d/%d)" % [p.name, s.count, s.cap]
		if s.count >= s.cap:
			return "%s spot is full" % p.name
		return "[Hold E] Stock %s  (%d/%d)  - box: %d left" % [p.name, s.count, s.cap, player.carrying.count]
	return "%s  $%.2f  (%d/%d)%s" % [p.name, p.price, s.count, s.cap, "  - LOW" if s.count == 0 else ""]

func on_interact(body: Node, player: Node) -> void:
	_hold_t = 0.0
	_try_place(body, player)

func on_hold(body: Node, player: Node, delta: float) -> void:
	_hold_t += delta
	if _hold_t >= 0.22:
		_hold_t = 0.0
		_try_place(body, player)

func _try_place(body: Node, player: Node) -> void:
	if player.carrying.get("kind", "") != "stock":
		return
	var i := _player_slot(body, player)
	if i < 0:
		return
	var why := place(i, player.carrying.product)
	if why == "":
		player.use_stock_unit()
