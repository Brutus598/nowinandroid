extends Node
## Globaler Spielzustand: Ressourcen, Bevölkerung, Zeitalter, Ablagen, Sieg.

signal resource_changed(res: int, new_amount: int)
signal population_changed(current: int, cap: int)
signal age_changed(new_age: int)
signal message(text: String)
signal game_won()

const START_RESOURCES := {
	ResourceKind.Type.WOOD: 200,
	ResourceKind.Type.FOOD: 100,
	ResourceKind.Type.GOLD: 50,
	ResourceKind.Type.STONE: 100,
	ResourceKind.Type.METAL: 0,
	ResourceKind.Type.OIL_STONE: 0,
}

const BASE_POPULATION_CAP := 5
const AGE_NAMES := ["Wikingerzeit", "Handelszeit", "Siedlungszeit"]
const TRAIN_COST := {ResourceKind.Type.FOOD: 50}

var resources: Dictionary = {}
var age := 1
var population_cap := BASE_POPULATION_CAP
var villagers: Array = []
var buildings: Array = []
var _dropoffs: Array = []
var _won := false

func _ready() -> void:
	for res in ResourceKind.all():
		resources[res] = START_RESOURCES.get(res, 0)
	recalc_population_cap()

# ---------------------------------------------------------------- Ressourcen

func add_resource(res: int, amount: int) -> void:
	if amount <= 0:
		return
	resources[res] = resources.get(res, 0) + amount
	resource_changed.emit(res, resources[res])

func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		if resources.get(res, 0) < cost[res]:
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for res in cost:
		resources[res] -= cost[res]
		resource_changed.emit(res, resources[res])
	return true

func log(text: String) -> void:
	message.emit(text)

# ---------------------------------------------------------------- Bevölkerung

func register_villager(v) -> void:
	if not villagers.has(v):
		villagers.append(v)
	_refresh_population()

func unregister_villager(v) -> void:
	villagers.erase(v)
	_refresh_population()

func _refresh_population() -> void:
	population_changed.emit(villagers.size(), population_cap)

func recalc_population_cap() -> void:
	var cap := BASE_POPULATION_CAP
	for b in buildings:
		if b.completed:
			cap += BuildingDefs.get(b.building_type).get("housing", 0)
	population_cap = cap
	_refresh_population()

func can_train_villager() -> bool:
	return villagers.size() < population_cap and has_building("langhaus") and can_afford(TRAIN_COST)

func train_villager() -> bool:
	if not can_train_villager():
		return false
	return spend(TRAIN_COST)

# ---------------------------------------------------------------- Gebäude

func register_building(b) -> void:
	if not buildings.has(b):
		buildings.append(b)

func has_building(type: String, only_completed := true) -> bool:
	for b in buildings:
		if b.building_type == type and (not only_completed or b.completed):
			return true
	return false

func count_buildings(type: String) -> int:
	var n := 0
	for b in buildings:
		if b.building_type == type:
			n += 1
	return n

func register_dropoff(b) -> void:
	if not _dropoffs.has(b):
		_droffs.append(b)

func unregister_dropoff(b) -> void:
	_droffs.erase(b)

func find_dropoff(res: int, from: Vector3):
	var best = null
	var best_dist := INF
	for b in _dropoffs:
		if not is_instance_valid(b) or not b.accepts(res):
			continue
		var d := b.global_position.distance_to(from)
		if d < best_dist:
			best_dist = d
			best = b
	return best

# ---------------------------------------------------------------- Zeitalter

func gather_multiplier() -> float:
	return 1.0 + (age - 1) * 0.15

func age_name() -> String:
	return age_name_for(age)

func age_name_for(age_number: int) -> String:
	if age_number < 1 or age_number > AGE_NAMES.size():
		return ""
	return AGE_NAMES[age_number - 1]

func age_progress_info() -> Dictionary:
	if age >= AGE_NAMES.size():
		return {"target": age, "cost": {}, "requires": "", "available": false}
	var target := age + 1
	var cost := {}
	var requires := ""
	if target == 2:
		cost = {ResourceKind.Type.FOOD: 300}
		requires = "schmiede"
	elif target == 3:
		cost = {ResourceKind.Type.GOLD: 300, ResourceKind.Type.WOOD: 200}
	return {
		"target": target,
		"cost": cost,
		"requires": requires,
		"available": can_afford(cost) and (requires == "" or has_building(requires)),
	}

func can_advance_age() -> bool:
	return age_progress_info()["available"]

func advance_age() -> bool:
	var info := age_progress_info()
	if not info["available"]:
		return false
	spend(info["cost"])
	age = info["target"]
	age_changed.emit(age)
	log("Ein neues Zeitalter beginnt: %s!" % age_name())
	return true

# ---------------------------------------------------------------- Sieg

func win() -> void:
	if _won:
		return
	_won = true
	game_won.emit()

func is_won() -> bool:
	return _won

# ---------------------------------------------------------------- KI-Kontext

func get_context() -> Dictionary:
	var res := {}
	for r in ResourceKind.all():
		res[ResourceKind.name_of(r)] = resources.get(r, 0)
	var b_counts := {}
	for t in BuildingDefs.all_types():
		b_counts[BuildingDefs.get(t)["name"]] = count_buildings(t)
	return {
		"dorf": "Nordheim",
		"zeitalter": age_name(),
		"zeitalter_nummer": age,
		"ressourcen": res,
		"bevölkerung": villagers.size(),
		"bevölkerungslimit": population_cap,
		"gebaeude": b_counts,
		"dorfbewohner": villagers.size(),
		"spiel_gewonnen": _won,
	}
