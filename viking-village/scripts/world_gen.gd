class_name WorldGen
extends Node3D
## Prozeduraler Weltgenerator: ein Wikinger-Fjord mit Ressourcen,
## Dekorationen (Berge, Kiefern, Zäune, Lagerfeuer, Langschiff).

const ResourceNodeScene := preload("res://scenes/resource_node.tscn")

@export var map_radius := 60.0
@export var water_start_x := 15.0
@export var spawn_clear_radius := 14.0
@export var seed_value := 20261009

var _rng := RandomNumberGenerator.new()
var _placed: Array[Vector3] = []

func generate(rng_seed: int = -1) -> void:
	_rng.seed = seed_value if rng_seed < 0 else rng_seed
	_placed.clear()
	_spawn_resources()
	_spawn_decorations()

# ---------------------------------------------------------------- Helpers

func _is_free(pos: Vector3) -> bool:
	if pos.x > water_start_x - 2.0:
		return false
	if pos.distance_to(Vector3.ZERO) < spawn_clear_radius:
		return false
	if absf(pos.x) > map_radius or absf(pos.z) > map_radius:
		return false
	for p in _placed:
		if p.distance_to(pos) < 3.5:
			return false
	return true

func _scatter(style: String, res: int, count: int, amount: int, rate: int, regrow := 0.0, in_water := false) -> void:
	var placed := 0
	var attempts := 0
	var max_attempts := count * 40
	while placed < count and attempts < max_attempts:
		attempts += 1
		var x := _rng.uniform(water_start_x + 8.0, map_radius - 6.0) if in_water else _rng.uniform(-map_radius + 6.0, water_start_x - 4.0)
		var pos := Vector3(x, 0.0, _rng.uniform(-map_radius + 6.0, map_radius - 6.0))
		if in_water:
			var ok := true
			for p in _placed:
				if p.distance_to(pos) < 8.0:
					ok = false
					break
			if not ok:
				continue
		elif not _is_free(pos):
			continue
		_spawn_node(style, res, amount, rate, regrow, in_water, pos)
		_placed.append(pos)
		placed += 1

func _spawn_node(style: String, res: int, amount: int, rate: int, regrow: float, in_water: bool, pos: Vector3) -> ResourceNode:
	var node: ResourceNode = ResourceNodeScene.instantiate()
	node.resource_type = res
	node.visual_style = style
	node.amount = amount
	node.max_amount = amount
	node.gather_rate = rate
	node.regrow_per_second = regrow
	node.in_water = in_water
	node.consumable = style not in ["farm", "fish"]
	add_child(node)
	node.global_position = pos
	return node

# ---------------------------------------------------------------- Ressourcen

func _spawn_resources() -> void:
	_scatter("tree", ResourceKind.Type.WOOD, 45, 100, 5)
	_scatter("bush", ResourceKind.Type.FOOD, 18, 60, 6)
	_scatter("stone", ResourceKind.Type.STONE, 7, 250, 4)
	_scatter("gold", ResourceKind.Type.GOLD, 5, 200, 3)
	_scatter("metal", ResourceKind.Type.METAL, 6, 200, 4)
	_scatter("oil", ResourceKind.Type.OIL_STONE, 6, 120, 2)
	# Bauernhöfe nahe dem Start
	for i in 2:
		var pos := Vector3(_rng.uniform(-spawn_clear_radius - 8.0, spawn_clear_radius + 8.0), 0.0, _rng.uniform(spawn_clear_radius + 2.0, spawn_clear_radius + 10.0))
		if _is_free(pos):
			_spawn_node("farm", ResourceKind.Type.FOOD, 150, 8, 1.0, false, pos)
			_placed.append(pos)
	# Angelstellen im Fjord
	_scatter("fish", ResourceKind.Type.FOOD, 3, 100000, 4, 6.0, true)

# ---------------------------------------------------------------- Dekorationen

func _spawn_decorations() -> void:
	_spawn_mountains()
	_spawn_pines()
	_spawn_rocks()
	_spawn_fences()
	_spawn_campfire()
	_spawn_longship()

func _spawn_mountains() -> void:
	for i in 10:
		var angle := _rng.uniform(0.0, TAU)
		var dist := _rng.uniform(map_radius + 10.0, map_radius + 30.0)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var radius := _rng.uniform(10.0, 18.0)
		var cone := ConeMesh.new()
		cone.bottom_radius = radius
		cone.height = radius * _rng.uniform(1.8, 2.6)
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = ProcMaterials.mat(Color(0.45, 0.47, 0.52), 0.95)
		mi.position = Vector3(pos.x, cone.height / 2.0 - 2.0, pos.z)
		mi.rotation.y = _rng.uniform(0.0, TAU)
		add_child(mi)

func _spawn_pines() -> void:
	for i in 30:
		var pos := Vector3(_rng.uniform(-map_radius, water_start_x - 6.0), 0.0, _rng.uniform(-map_radius, map_radius))
		if pos.distance_to(Vector3.ZERO) < spawn_clear_radius - 2.0:
			continue
		var g := Node3D.new()
		g.position = pos
		g.rotation.y = _rng.uniform(0.0, TAU)
		Proc3D.cylinder(g, 0.09, 1.4, ProcMaterials.wood(true), Vector3(0, 0.7, 0))
		Proc3D.cone(g, 0.7, 1.2, ProcMaterials.foliage(), Vector3(0, 1.7, 0))
		Proc3D.cone(g, 0.5, 1.0, ProcMaterials.foliage(), Vector3(0, 2.3, 0))
		add_child(g)

func _spawn_rocks() -> void:
	for i in 18:
		var pos := Vector3(_rng.uniform(-map_radius, water_start_x - 6.0), 0.0, _rng.uniform(-map_radius, map_radius))
		if pos.distance_to(Vector3.ZERO) < spawn_clear_radius - 2.0:
			continue
		Proc3D.sphere(self, 0.3 + _rng.randf() * 0.4, ProcMaterials.stone(), Vector3(pos.x, 0.25, pos.z), Vector3(1.0, 0.6 + _rng.randf() * 0.4, 1.0))

func _spawn_fences() -> void:
	for fence_idx in 2:
		var side := 1.0 if fence_idx == 0 else -1.0
		var start := Vector3(_rng.uniform(-10.0, 10.0), 0.0, side * (spawn_clear_radius + _rng.uniform(1.0, 4.0)))
		var g := Node3D.new()
		g.position = start
		g.rotation.y = _rng.uniform(0.0, TAU)
		for i in 4:
			Proc3D.cylinder(g, 0.06, 0.9, ProcMaterials.wood(true), Vector3(i * 1.2, 0.45, 0))
		Proc3D.box(g, Vector3(4.9, 0.08, 0.08), ProcMaterials.wood(true), Vector3(1.8, 0.75, 0))
		Proc3D.box(g, Vector3(4.9, 0.08, 0.08), ProcMaterials.wood(true), Vector3(1.8, 0.35, 0))
		add_child(g)

func _spawn_campfire() -> void:
	var pos := Vector3(_rng.uniform(-6.0, 6.0), 0.0, _rng.uniform(-6.0, -2.0))
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	for i in 3:
		Proc3D.cylinder(g, 0.06, 0.5, ProcMaterials.wood(true), Vector3(0, 0.1, 0), Vector3(_rng.uniform(-0.6, 0.6), _rng.uniform(0.0, TAU), _rng.uniform(-0.6, 0.6)))
	Proc3D.sphere(g, 0.12, ProcMaterials.emissive(Color(1.0, 0.5, 0.1), 3.0), Vector3(0, 0.25, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.omni_range = 6.0
	light.light_energy = 0.9
	light.position = Vector3(0, 0.4, 0)
	g.add_child(light)
	var t := create_tween().set_loops()
	t.tween_property(light, "light_energy", 1.1, 0.4)
	t.tween_property(light, "light_energy", 0.7, 0.4)

func _spawn_longship() -> void:
	var pos := Vector3(_rng.uniform(30.0, 50.0), 0.0, _rng.uniform(-40.0, 40.0))
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = _rng.uniform(0.0, TAU)
	add_child(g)
	# Rumpf
	Proc3D.box(g, Vector3(5.0, 0.5, 1.3), ProcMaterials.wood(true), Vector3(0, 0.35, 0))
	# aufgebogene Steven
	Proc3D.box(g, Vector3(0.5, 0.9, 1.1), ProcMaterials.wood(true), Vector3(2.4, 0.75, 0), Vector3(0, 0, 0.5))
	Proc3D.box(g, Vector3(0.5, 0.9, 1.1), ProcMaterials.wood(true), Vector3(-2.4, 0.75, 0), Vector3(0, 0, -0.5))
	# Drachenkopf
	Proc3D.cone(g, 0.35, 0.8, ProcMaterials.wood(true), Vector3(2.75, 1.0, 0))
	# Mast
	Proc3D.cylinder(g, 0.07, 3.2, ProcMaterials.wood(true), Vector3(0, 1.9, 0))
	# rot-weiß gestreiftes Segel (Textur prozedural erzeugt)
	var sail := PlaneMesh.new()
	sail.size = Vector2(2.6, 2.6)
	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_texture = _striped_texture()
	sail_mat.roughness = 1.0
	sail_mat.cull_mode = StandardMaterial3D.CULL_DISABLED
	Proc3D.mesh(g, sail, sail_mat, Vector3(0, 3.0, 0))
	# Ruderbänke
	for i in 4:
		Proc3D.box(g, Vector3(0.12, 0.55, 1.3), ProcMaterials.wood(), Vector3(-1.5 + i * 1.0, 0.55, 0))

func _striped_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var red := (y / 8) % 2 == 0
		for x in 64:
			img.set_pixel(x, y, Color(0.8, 0.1, 0.1) if red else Color(0.95, 0.95, 0.9))
	return ImageTexture.create_from_image(img)
