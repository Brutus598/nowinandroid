class_name ResourceNode
extends StaticBody3D
## Eine Ressourcen-Quelle: Baum, Beerenbusch, Steinbruch, Gold-/Erz-Gang,
## Ölstein, Bauernhof oder Angelstelle im Fjord.

signal depleted(node: ResourceNode)
signal gathered(node: ResourceNode, amount: int)

@export var resource_type := ResourceKind.Type.WOOD
@export var visual_style := "tree"
@export var amount := 100
@export var max_amount := 100
@export var gather_rate := 5
@export var regrow_per_second := 0.0
@export var in_water := false
@export var consumable := true
@export var interact_distance := 2.0

@onready var visuals: Node3D = $Visuals
@onready var collision: CollisionShape3D = $CollisionShape3D

var amount_left := 0
var _sway_tween: Tween
var _punch_tween: Tween

func _ready() -> void:
	add_to_group("resource_nodes")
	amount_left = amount
	_build_visuals()
	_build_collision()

func _process(delta: float) -> void:
	if regrow_per_second > 0.0 and amount_left < max_amount:
		amount_left = minf(amount_left + regrow_per_second * delta, float(max_amount))

func is_depleted() -> bool:
	return amount_left <= 0

func gather(take: int) -> int:
	if is_depleted() or take <= 0:
		return 0
	var got := mini(take, amount_left)
	amount_left -= got
	gathered.emit(self, got)
	_punch()
	if is_depleted():
		depleted.emit(self)
		_on_depleted()
	return got

# ---------------------------------------------------------------- Visuals

func _build_visuals() -> void:
	match visual_style:
		"tree":
			_build_tree()
		"bush":
			_build_bush()
		"gold", "stone", "metal":
			_build_rock_vein()
		"oil":
			_build_oil_stone()
		"farm":
			_build_farm()
		"fish":
			_build_fish_spot()

func _build_tree() -> void:
	Proc3D.cylinder(visuals, 0.13, 1.6, ProcMaterials.wood(true), Vector3(0, 0.8, 0), Vector3.ZERO, 0.1)
	Proc3D.cone(visuals, 1.0, 1.3, ProcMaterials.foliage(), Vector3(0, 1.9, 0))
	Proc3D.cone(visuals, 0.75, 1.1, ProcMaterials.foliage(), Vector3(0, 2.5, 0))
	Proc3D.cone(visuals, 0.5, 0.9, ProcMaterials.foliage(), Vector3(0, 3.0, 0))
	interact_distance = 2.2
	_sway()

func _sway() -> void:
	_sway_tween = create_tween().set_loops()
	_sway_tween.tween_property(visuals, "rotation:z", 0.02, 2.2 + randf() * 1.5)
	_sway_tween.tween_property(visuals, "rotation:z", -0.02, 2.2 + randf() * 1.5)

func _build_bush() -> void:
	for i in 3:
		Proc3D.sphere(visuals, 0.4 + randf() * 0.15, ProcMaterials.foliage(), Vector3(randf() - 0.5, 0.35 + randf() * 0.1, randf() - 0.5))
	for i in 6:
		Proc3D.sphere(visuals, 0.07, ProcMaterials.mat(Color(0.8, 0.1, 0.15)), Vector3(randf() - 0.5, 0.55 + randf() * 0.2, randf() - 0.5))
	interact_distance = 1.8

func _build_rock_vein() -> void:
	for i in 3:
		Proc3D.sphere(visuals, 0.45, ProcMaterials.stone(), Vector3(randf() - 0.5, 0.35, randf() - 0.5), Vector3(1.0, 0.7 + randf() * 0.3, 1.0))
	var ore_mat := ProcMaterials.stone()
	if resource_type == ResourceKind.Type.GOLD:
		ore_mat = ProcMaterials.gold()
	elif resource_type == ResourceKind.Type.METAL:
		ore_mat = ProcMaterials.iron()
	for i in 3:
		Proc3D.sphere(visuals, 0.14 + randf() * 0.06, ore_mat, Vector3(randf() - 0.5, 0.75 + randf() * 0.2, randf() - 0.5))
	interact_distance = 2.0

func _build_oil_stone() -> void:
	Proc3D.sphere(visuals, 0.55, ProcMaterials.mat(Color(0.08, 0.08, 0.1), 0.6, 0.3), Vector3(0, 0.5, 0), Vector3(1.2, 0.9, 1.2))
	Proc3D.sphere(visuals, 0.18, ProcMaterials.emissive(Color(0.3, 1.0, 0.5), 3.0), Vector3(0, 0.85, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.5)
	light.omni_range = 2.5
	light.light_energy = 0.5
	light.position.y = 0.9
	add_child(light)
	interact_distance = 2.0

func _build_farm() -> void:
	Proc3D.box(visuals, Vector3(2.0, 0.15, 2.0), ProcMaterials.mat(Color(0.35, 0.22, 0.1)), Vector3(0, 0.08, 0))
	for x in 3:
		for z in 3:
			Proc3D.cylinder(visuals, 0.04, 0.4, ProcMaterials.foliage(), Vector3(-0.6 + x * 0.6, 0.3, -0.6 + z * 0.6), Vector3.ZERO, 0.03)
	# Vogelscheuche
	Proc3D.cylinder(visuals, 0.03, 1.2, ProcMaterials.wood(true), Vector3(1.2, 0.6, 1.2))
	Proc3D.cone(visuals, 0.25, 0.3, ProcMaterials.mat(Color(0.8, 0.6, 0.2)), Vector3(1.2, 1.25, 1.2))
	interact_distance = 2.8

func _build_fish_spot() -> void:
	var ring_mat := ProcMaterials.mat(Color(0.2, 0.5, 0.8), 0.3)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring_color := ring_mat.albedo_color
	ring_color.a = 0.5
	ring_mat.albedo_color = ring_color
	Proc3D.cylinder(visuals, 1.3, 0.08, ring_mat, Vector3(0, 0.1, 0))
	var fish_mi := Proc3D.sphere(visuals, 0.12, ProcMaterials.mat(Color(0.7, 0.75, 0.8)), Vector3(0, 0.2, 0), Vector3(2.2, 1.0, 1.0))
	_animate_fish(fish_mi)
	interact_distance = 3.0

func _animate_fish(mi: MeshInstance3D) -> void:
	var t := create_tween().set_loops()
	t.tween_property(mi, "position:y", 0.55, 0.7).set_ease(Tween.EASE_OUT)
	t.tween_property(mi, "position:y", 0.15, 0.7).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(mi, "rotation:y", TAU, 1.4)

# ---------------------------------------------------------------- Effects

func _punch() -> void:
	if _punch_tween:
		_punch_tween.kill()
	_punch_tween = create_tween()
	_punch_tween.tween_property(visuals, "scale", Vector3(1.08, 1.08, 1.08), 0.08)
	_punch_tween.tween_property(visuals, "scale", Vector3.ONE, 0.12)

func _on_depleted() -> void:
	collision.disabled = true
	if _punch_tween:
		_punch_tween.kill()
	if _sway_tween:
		_sway_tween.kill()
	if consumable:
		if visual_style == "tree":
			var t := create_tween()
			t.tween_property(visuals, "rotation:z", 1.35, 0.9).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(self, "position:y", -1.4, 0.9).set_ease(Tween.EASE_IN)
			t.chain().tween_callback(queue_free)
		else:
			var t := create_tween()
			t.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
			t.parallel().tween_property(self, "position:y", -0.6, 0.5)
			t.chain().tween_callback(queue_free)

func _build_collision() -> void:
	var shape: Shape3D
	match visual_style:
		"tree":
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.5
			cyl.height = 2.6
			shape = cyl
		"bush":
			var sph := SphereShape3D.new()
			sph.radius = 0.8
			shape = sph
		"farm":
			var box := BoxShape3D.new()
			box.size = Vector3(2.4, 1.0, 2.4)
			shape = box
		"fish":
			var cyl := CylinderShape3D.new()
			cyl.radius = 1.4
			cyl.height = 0.6
			shape = cyl
		_:
			var box := BoxShape3D.new()
			box.size = Vector3(1.4, 1.2, 1.4)
			shape = box
	collision.shape = shape
