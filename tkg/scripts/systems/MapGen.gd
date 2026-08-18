class_name MapGen
extends RefCounted

## Procedural galaxy. Layers run edge -> core; danger and loot quality both
## climb coreward. Layers are fully connected laterally so you can farm a
## danger band before choosing to descend. That lateral freedom is what makes
## the greed clock work: every death is self-authored.

enum Region { FRONTIER, TERRITORY, COSMOPOLITAN, LAWLESS, FAUNA, CORE }
enum NodeType { START, FIGHT, STATION, EVENT, DERELICT, GOAL }

const LAYERS := 8

class MapNode extends RefCounted:
	var index: int = 0
	var layer: int = 0
	var row: int = 0
	var rows_in_layer: int = 1
	var region: Region = Region.FRONTIER
	var manufacturer: StringName = &""
	var danger: int = 1
	var type: NodeType = NodeType.FIGHT
	var visited: bool = false
	var cleared: bool = false
	var pos: Vector2 = Vector2.ZERO
	var links: PackedInt32Array = []
	## Populated lazily by StationScreen
	var shop: Array = []
	var shop_hull: HullData = null
	var inspected: bool = false

static func region_name(r: Region) -> String:
	return ["Frontier", "Territory", "Cosmopolitan", "Lawless", "Migration Route", "Precursor Ruins"][r]

static func region_blurb(r: Region) -> String:
	match r:
		Region.TERRITORY: return "One maker dominates local salvage."
		Region.COSMOPOLITAN: return "Trade crossroads. Broad stock, higher prices, strict inspections."
		Region.LAWLESS: return "Contraband common. Fences carry good stock."
		Region.FAUNA: return "Megafauna. Exotic materials, no module salvage."
		Region.CORE: return "Artifact tech. Nothing here was manufactured."
		_: return "Nobody's space. Thin, random salvage."

static func region_colour(n: MapNode) -> Color:
	match n.region:
		Region.CORE: return Color("#d4614f")
		Region.TERRITORY: return DB.manufacturer_colour(n.manufacturer)
		Region.COSMOPOLITAN: return Color("#8fa3ba")
		Region.LAWLESS: return Color("#7a5a3a")
		Region.FAUNA: return Color("#4a7a8a")
		_: return Color("#3a4a5c")

static func type_label(t: NodeType) -> String:
	return ["START", "FIGHT", "STATION", "EVENT", "DERELICT", "FARLIGHT"][t]

static func generate(canvas: Rect2) -> Array:
	var nodes: Array = []
	var idx := 0
	for layer in LAYERS:
		var count := 1 if layer == 0 or layer == LAYERS - 1 else randi_range(4, 6)
		var danger := mini(5, 1 + int(layer * 4.0 / (LAYERS - 1)))
		for row in count:
			var n := MapNode.new()
			n.index = idx
			idx += 1
			n.layer = layer
			n.row = row
			n.rows_in_layer = count
			n.danger = danger
			if layer == 0:
				n.region = Region.FRONTIER
				n.type = NodeType.START
			elif layer == LAYERS - 1:
				n.region = Region.CORE
				n.type = NodeType.GOAL
			else:
				n.region = _pick_region()
				n.type = _pick_type()
			if n.region == Region.TERRITORY:
				n.manufacturer = DB.manufacturers.keys().pick_random()
			nodes.append(n)

	_layout(nodes, canvas)
	_link(nodes)
	nodes[0].visited = true
	nodes[0].cleared = true
	return nodes

static func _pick_region() -> Region:
	var weights := [
		Region.TERRITORY, Region.TERRITORY, Region.TERRITORY,
		Region.COSMOPOLITAN, Region.COSMOPOLITAN,
		Region.FRONTIER, Region.LAWLESS, Region.FAUNA,
	]
	return weights.pick_random()

static func _pick_type() -> NodeType:
	var weights := [
		NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT,
		NodeType.STATION, NodeType.STATION,
		NodeType.EVENT, NodeType.EVENT,
		NodeType.DERELICT,
	]
	return weights.pick_random()

static func _layout(nodes: Array, canvas: Rect2) -> void:
	for n in nodes:
		var nn: MapNode = n
		var fx := float(nn.layer) / float(LAYERS - 1)
		nn.pos.x = canvas.position.x + fx * canvas.size.x
		if nn.rows_in_layer == 1:
			nn.pos.y = canvas.position.y + canvas.size.y * 0.5
		else:
			var fy := (float(nn.row) + 0.5) / float(nn.rows_in_layer)
			nn.pos.y = canvas.position.y + fy * canvas.size.y

static func _link(nodes: Array) -> void:
	for layer in LAYERS - 1:
		var here: Array = nodes.filter(func(n): return n.layer == layer)
		var next: Array = nodes.filter(func(n): return n.layer == layer + 1)
		for i in here.size():
			var n: MapNode = here[i]
			var base := int(float(i) * next.size() / here.size())
			_connect(n, next[mini(next.size() - 1, base)])
			if base + 1 < next.size() and randf() < 0.7:
				_connect(n, next[base + 1])
			if base - 1 >= 0 and randf() < 0.35:
				_connect(n, next[base - 1])
		# Guarantee every forward node is reachable.
		for t in next:
			var reachable := false
			for n in here:
				if (n as MapNode).links.has((t as MapNode).index):
					reachable = true
					break
			if not reachable:
				_connect(here[here.size() - 1], t)
		# Full lateral connectivity within the layer: farm before you descend.
		for a in here:
			for b in here:
				if a != b and absi((a as MapNode).row - (b as MapNode).row) == 1:
					_connect(a, b)

static func _connect(a: MapNode, b: MapNode) -> void:
	if not a.links.has(b.index):
		a.links.append(b.index)
	if not b.links.has(a.index):
		b.links.append(a.index)
