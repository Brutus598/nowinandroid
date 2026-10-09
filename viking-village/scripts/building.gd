class_name Building
extends StaticBody3D
## Gebäude mit Bau-Fortschritt, Ablage-Funktion und prozeduralen 3D-Visuals.

signal construction_finished(b: Building)

@export var building_type := "lagerhaus"
@export var completed := false

var def: Dictionary = {}
var build_progress := 0.0
var interact_distance := 2.6

@onready var visuals: Node3D = $Visuals
@onready var progress_label: Label3D = $ProgressLabel

var _flicker_light: OmniLight3D

func _ready() -> void:
	def = BuildingDefs.get(building_type)
	add_to_group("buildings")
	_build_visuals()
	_build_collision()
	Game.register_building(self)
	if completed:
		_on_completed()
	else:
		_apply_ghost_style(true)
		progress_label.visible = true

func _process(delta: float) -> void:
	if not completed:
		add_build_progress(delta * 0.15) # langsamer Fortschritt auch ohne Bauarbeiter
	if _flicker_light != null:
		_flicker_light.light_energy = 1.2 + sin(Time.get_ticks_msec() / 100.0) * 0.25 + randf() * 0.15

func start_construction() -> void:
	completed = false
	build_progress = 0.0
	_apply_ghost_style(true)
	progress_label.visible = true

func add_build_progress(amount: float) -> void:
	if completed:
		return
	build_progress += amount
	var pct := int(build_progress / def["build_time"] * 100.0)
	progress_label.text = "Bau: %d%%" % pct
	if build_progress >= def["build_time"]:
		_on_completed()

func _on_completed() -> void:
	completed = true
	progress_label.visible = false
	_apply_ghost_style(false)
	Game.recalc_population_cap()
	if def["dropoff"].size() > 0:
		Game.register_dropoff(self)
	Game.log("%s fertiggestellt!" % def["name"])
	construction_finished.emit(self)
	if def.get("win", false) and Game.age >= 3:
		Game.win()
	_pop()

func _pop() -> void:
	visuals.scale = Vector3(0.7, 0.7, 0.7)
	var t := create_tween()
	t.tween_property(visuals, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func accepts(res: int) -> bool:
	return completed and def["dropoff"].has(res)

func _apply_ghost_style(ghost: bool) -> void:
	for child in visuals.get_children():
		if child is MeshInstance3D:
			var mat := child.material_override
			if mat is StandardMaterial3D:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if ghost else BaseMaterial3D.TRANSPARENCY_DISABLED
				var c := mat.albedo_color
				c.a = 0.55 if ghost else 1.0
				mat.albedo_color = c

func _build_collision() -> void:
	var box := BoxShape3D.new()
	box.size = def["collision_size"]
	$CollisionShape3D.shape = box

# ---------------------------------------------------------------- Visuals

func _build_visuals() -> void:
	match building_type:
		"langhaus":
			_build_langhaus()
		"lagerhaus":
			_build_lagerhaus()
		"schmiede":
			_build_schmiede()
		"halle":
			_build_halle()

func _build_langhaus() -> void:
	Proc3D.box(visuals, Vector3(4.4, 0.4, 2.8), ProcMaterials.stone(), Vector3(0, 0.2, 0))
	Proc3D.box(visuals, Vector3(4.0, 1.8, 2.4), ProcMaterials.wood(), Vector3(0, 1.3, 0))
	Proc3D.prism(visuals, Vector3(4.3, 1.3, 2.7), ProcMaterials.thatch(), Vector3(0, 2.85, 0))
	Proc3D.box(visuals, Vector3(0.8, 1.3, 0.12), ProcMaterials.mat(Color(0.2, 0.12, 0.06)), Vector3(0, 1.2, 1.2))
	for x in [-1.2, 1.2]:
		Proc3D.box(visuals, Vector3(0.5, 0.4, 0.1), ProcMaterials.emissive(Color(1.0, 0.8, 0.3), 1.5), Vector3(x, 1.5, 1.2))
	interact_distance = 3.0

func _build_lagerhaus() -> void:
	Proc3D.box(visuals, Vector3(3.2, 0.4, 2.6), ProcMaterials.stone(), Vector3(0, 0.2, 0))
	Proc3D.box(visuals, Vector3(3.0, 1.6, 2.4), ProcMaterials.wood(), Vector3(0, 1.2, 0))
	Proc3D.prism(visuals, Vector3(3.3, 1.1, 2.7), ProcMaterials.thatch(), Vector3(0, 2.35, 0))
	Proc3D.box(visuals, Vector3(0.7, 1.2, 0.12), ProcMaterials.mat(Color(0.2, 0.12, 0.06)), Vector3(0, 1.1, 1.2))
	Proc3D.cylinder(visuals, 0.28, 0.6, ProcMaterials.wood(true), Vector3(2.0, 0.3, 0.8))
	Proc3D.cylinder(visuals, 0.28, 0.6, ProcMaterials.wood(true), Vector3(2.2, 0.3, -0.9))
	interact_distance = 3.0

func _build_schmiede() -> void:
	Proc3D.box(visuals, Vector3(3.6, 1.8, 2.8), ProcMaterials.dark_stone(), Vector3(0, 0.9, 0))
	Proc3D.prism(visuals, Vector3(3.9, 1.2, 3.1), ProcMaterials.mat(Color(0.25, 0.2, 0.18)), Vector3(0, 2.4, 0))
	Proc3D.cylinder(visuals, 0.16, 1.0, ProcMaterials.dark_stone(), Vector3(-1.2, 2.6, -0.8))
	Proc3D.box(visuals, Vector3(0.9, 0.7, 0.12), ProcMaterials.emissive(Color(1.0, 0.45, 0.1), 2.5), Vector3(0.6, 1.0, 1.35))
	_flicker_light = OmniLight3D.new()
	_flicker_light.light_color = Color(1.0, 0.5, 0.15)
	_flicker_light.omni_range = 5.0
	_flicker_light.light_energy = 1.2
	_flicker_light.position = Vector3(0.6, 1.2, 1.0)
	add_child(_flicker_light)
	interact_distance = 3.0

func _build_halle() -> void:
	Proc3D.box(visuals, Vector3(6.4, 0.4, 4.0), ProcMaterials.stone(), Vector3(0, 0.2, 0))
	Proc3D.box(visuals, Vector3(6.0, 2.6, 3.6), ProcMaterials.wood(), Vector3(0, 1.7, 0))
	Proc3D.prism(visuals, Vector3(6.4, 2.0, 4.0), ProcMaterials.thatch(), Vector3(0, 3.6, 0))
	# goldene Dachkanten
	Proc3D.box(visuals, Vector3(6.4, 0.08, 0.08), ProcMaterials.gold(), Vector3(0, 4.6, 1.98))
	Proc3D.box(visuals, Vector3(6.4, 0.08, 0.08), ProcMaterials.gold(), Vector3(0, 4.6, -1.98))
	Proc3D.box(visuals, Vector3(1.2, 2.0, 0.14), ProcMaterials.mat(Color(0.2, 0.12, 0.06)), Vector3(0, 1.9, 1.8))
	# Herdfeuer in der Mitte
	Proc3D.cylinder(visuals, 0.6, 0.15, ProcMaterials.dark_stone(), Vector3(0, 0.35, 0))
	Proc3D.sphere(visuals, 0.18, ProcMaterials.emissive(Color(1.0, 0.5, 0.1), 3.0), Vector3(0, 0.55, 0))
	_flicker_light = OmniLight3D.new()
	_flicker_light.light_color = Color(1.0, 0.6, 0.2)
	_flicker_light.omni_range = 7.0
	_flicker_light.light_energy = 1.5
	_flicker_light.position = Vector3(0, 0.8, 0)
	add_child(_flicker_light)
	# Bänke
	for z in [-1.2, 1.2]:
		Proc3D.box(visuals, Vector3(1.6, 0.35, 0.5), ProcMaterials.wood(true), Vector3(-1.8, 0.45, z))
		Proc3D.box(visuals, Vector3(1.6, 0.35, 0.5), ProcMaterials.wood(true), Vector3(1.8, 0.45, z))
	# Banner an der Front
	for x in [-2.4, 2.4]:
		Proc3D.cylinder(visuals, 0.04, 2.2, ProcMaterials.wood(true), Vector3(x, 1.9, 1.95))
		Proc3D.box(visuals, Vector3(0.5, 0.7, 0.06), ProcMaterials.cloth(Color(0.7, 0.1, 0.1)), Vector3(x, 2.2, 2.05))
	interact_distance = 3.6
