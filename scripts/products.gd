class_name Products
## Product catalog: name, price, box color, box size (m).

const CATALOG := [
	{"name": "Krunch-O's Cereal", "price": 4.99, "color": Color(0.95, 0.75, 0.1), "size": Vector3(0.22, 0.32, 0.08)},
	{"name": "Fizzy Cola 6-pack", "price": 6.49, "color": Color(0.85, 0.12, 0.12), "size": Vector3(0.26, 0.2, 0.18)},
	{"name": "Mac & Cheez", "price": 1.29, "color": Color(0.15, 0.35, 0.9), "size": Vector3(0.18, 0.12, 0.06)},
	{"name": "Spicy Chips", "price": 3.79, "color": Color(0.95, 0.4, 0.05), "size": Vector3(0.24, 0.3, 0.1)},
	{"name": "Lime Soda", "price": 1.99, "color": Color(0.3, 0.85, 0.25), "size": Vector3(0.1, 0.24, 0.1)},
	{"name": "Paper Towels", "price": 8.99, "color": Color(0.92, 0.92, 0.95), "size": Vector3(0.28, 0.3, 0.2)},
	{"name": "Grape Snacks", "price": 2.49, "color": Color(0.55, 0.2, 0.75), "size": Vector3(0.2, 0.22, 0.08)},
	{"name": "Instant Noodles", "price": 0.99, "color": Color(0.95, 0.85, 0.3), "size": Vector3(0.16, 0.1, 0.16)},
	{"name": "Frozen Pizza", "price": 7.49, "color": Color(0.8, 0.2, 0.3), "size": Vector3(0.3, 0.05, 0.3)},
	{"name": "Energy Drink", "price": 3.29, "color": Color(0.1, 0.9, 0.85), "size": Vector3(0.08, 0.2, 0.08)},
	{"name": "Cookies", "price": 4.29, "color": Color(0.45, 0.25, 0.1), "size": Vector3(0.24, 0.08, 0.14)},
	{"name": "Ice Cream", "price": 5.99, "color": Color(0.95, 0.6, 0.75), "size": Vector3(0.16, 0.14, 0.16)},
]

const SHELF_ITEMS := [0, 1, 2, 3, 4, 5, 6, 7, 10]   # stocked on aisle shelves
const FROZEN_ITEMS := [8, 9, 11, 1]                 # sold from the freezer (never runs out)

static func random() -> Dictionary:
	return CATALOG[randi() % CATALOG.size()]

static func index_of(p: Dictionary) -> int:
	return CATALOG.find(p)

static func cents(p: Dictionary) -> int:
	return int(round(float(p.price) * 100.0))

static func label_color(p: Dictionary) -> Color:
	var c: Color = p.color
	return Color(0.08, 0.08, 0.1) if c.get_luminance() > 0.6 else Color(0.97, 0.95, 0.85)
