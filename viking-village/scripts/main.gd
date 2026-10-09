class_name Main
extends Node3D
## Hauptspiel: Welt aufbauen, Einheiten selektieren, Befehle geben, Bau-Modus.

const VillagerScene := preload("res://scenes/villager.tscn")
const BuildingScene := preload("res://scenes/building.tscn")

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var entities: Node3D = $Entities
@onready var hud: Hud = $HUD
@onready var world_gen: WorldGen = $WorldGen

var selected: Array[Villager] = []
var build_mode := ""
var _touch_moved := false
var fanfare := Fanfare.new()

func _ready() -> void:
	add_child(fanfare)
	_setup_environment()
	world_gen.generate()
	_place_start_buildings()
	_spawn_start_villagers()
	_spawn_hills()
	Game.recalc_population_cap()
	Game.message.connect(hud.show_message)
	Game.game_won.connect(_on_game_won)
	hud.refresh_all()
	Game.log("Willkommen in Nordheim! Wähle einen Dorfbewohner und klicke auf eine Ressource.")

# ---------------------------------------------------------------- Welt-S visuals

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.75, 0.82, 0.9)
	sky_mat.ground_bottom_color = Color(0.15, 0.2, 0.15)
	sky_mat.ground_horizon_color = Color(0.45, 0.5, 0.45)
	sky.sky_material = sky_mat
	env.sky = sky
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_sky_affect = 0.4
	$WorldEnvironment.environment = env

	var terrain := PlaneMesh.new()
	terrain.size = Vector2(220.0, 220.0)
	$Terrain/Mesh.mesh = terrain
	$Terrain/Mesh.material_override = ProcMaterials.mat(Color(0.24, 0.42, 0.18), 1.0)
	$Terrain/Mesh.position.y = -0.01

	# Sandstreifen am Ufer
	var sand := PlaneMesh.new()
	sand.size = Vector2(8.0, 220.0)
	var sand_mi := MeshInstance3D.new()
	sand_mi.mesh = sand
	sand_mi.material_override = ProcMaterials.mat(Color(0.76, 0.66, 0.45), 1.0)
	sand_mi.position = Vector3(11.0, 0.0, 0.0)
	add_child(sand_mi)

	# Fjord-Wasser mit Wellen-Shader
	var water := PlaneMesh.new()
	water.size = Vector2(95.0, 220.0)
	$Water.mesh = water
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("water_color", Color(0.08, 0.28, 0.5, 0.72))
	water_mat.set_shader_parameter("wave_speed", 1.2)
	water_mat.set_shader_parameter("wave_height", 0.12)
	$Water.material_override = water_mat
	$Water.position = Vector3(62.0, 0.06, 0.0)

	$Sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	$Sun.light_energy = 1.15
	$Sun.shadow_enabled = true

func _spawn_hills() -> void:
	# Hügel für Tiefe – meidet Ressourcen, Gebäude und Dorfbewohner
	var blocked: Array[Vector3] = []
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		blocked.append(n.global_position)
	for b in Game.buildings:
		blocked.append(b.global_position)
	for v in Game.villagers:
		blocked.append(v.global_position)
	for i in 10:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99 + i
		var pos := Vector3(rng.uniform(-85.0, 5.0), 0.0, rng.uniform(-85.0, 85.0))
		var ok := true
		for p in blocked:
			if p.distance_to(pos) < 9.0:
				ok = false
				break
		if not ok:
			continue
		var mound := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 6.0 + rng.randf() * 5.0
		mound.mesh = m
		mound.material_override = ProcMaterials.mat(Color(0.22, 0.4, 0.16), 1.0)
		mound.scale = Vector3(1.6, 0.25, 1.6)
		mound.position = Vector3(pos.x, -0.4, pos.z)
		add_child(mound)

# ---------------------------------------------------------------- Start-Setup

func _place_start_buildings() -> void:
	place_building("langhaus", Vector3(-6.0, 0.0, 3.0), true)
	place_building("lagerhaus", Vector3(6.0, 0.0, 3.0), true)

func place_building(type: String, pos: Vector3, instantly_completed := false) -> Building:
	var b: Building = BuildingScene.instantiate()
	b.building_type = type
	b.completed = instantly_completed
	entities.add_child(b)
	b.global_position = Vector3(pos.x, 0.0, pos.z)
	return b

func _spawn_start_villagers() -> void:
	for i in 3:
		spawn_villager(Vector3(-2.0 + i * 2.0, 0.0, 8.0))

func spawn_villager(pos: Vector3) -> Villager:
	var v: Villager = VillagerScene.instantiate()
	entities.add_child(v)
	v.global_position = Vector3(pos.x, 0.0, pos.z)
	return v

func train_villager() -> void:
	if not Game.train_villager():
		return
	var spawn_pos := Vector3(0.0, 0.0, 6.0)
	for b in Game.buildings:
		if b.building_type == "langhaus" and b.completed:
			spawn_pos = b.global_position + Vector3(0.0, 0.0, 3.5)
			break
	spawn_villager(spawn_pos)
	Game.log("Ein neuer Dorfbewohner schließt sich Nordheim an!")

# ---------------------------------------------------------------- Input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_moved = false
		elif not _touch_moved:
			_handle_click(event.position)
	elif event is InputEventScreenDrag:
		_touch_moved = true
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if build_mode != "":
				set_build_mode("")
			elif selected.size() > 0:
				_deselect_all()

func _handle_click(screen_pos: Vector2) -> void:
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return
	if build_mode != "":
		_try_place_building(hit["position"])
		return
	var collider: Object = hit["collider"]
	if collider is Villager:
		_select(collider as Villager)
	elif collider is ResourceNode:
		var node := collider as ResourceNode
		if selected.size() > 0:
			for v in selected:
				v.command_gather(node)
			Game.log("%d Dorfbewohner sammeln %s." % [selected.size(), ResourceKind.name_of(node.resource_type)])
	elif collider is Building:
		var b := collider as Building
		for v in selected:
			if not b.completed:
				v.command_build(b)
			elif v.carried_amount > 0 and b.accepts(v.carried_resource):
				v.command_deposit(b)
			else:
				v.command_move(b.global_position + Vector3(0.0, 0.0, 3.0))
	else:
		if selected.size() > 0:
			for v in selected:
				v.command_move(hit["position"])

func _raycast(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0, 0b11)
	query.collide_with_areas = false
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	return space.intersect_ray(query)

# ---------------------------------------------------------------- Selektion

func _select(v: Villager) -> void:
	_deselect_all()
	selected = [v]
	v.select()
	hud.show_selection(v)

func _deselect_all() -> void:
	for v in selected:
		if is_instance_valid(v):
			v.deselect()
	selected.clear()
	hud.show_selection(null)

# ---------------------------------------------------------------- Bau-Modus

func set_build_mode(type: String) -> void:
	build_mode = type if build_mode != type else ""
	hud.set_build_mode_active(build_mode)
	if build_mode != "":
		Game.log("Wähle eine Position für: %s (ESC zum Abbrechen)" % BuildingDefs.get(build_mode)["name"])

func _try_place_building(pos: Vector3) -> void:
	var def := BuildingDefs.get(build_mode)
	if def.is_empty():
		return
	if not Game.can_afford(def["cost"]):
		Game.log("Nicht genug Ressourcen für: %s" % def["name"])
		return
	Game.spend(def["cost"])
	var b := place_building(build_mode, pos)
	var builder := _nearest_idle_villager(b.global_position)
	if builder != null:
		builder.command_build(b)
	Game.log("%s wird gebaut." % def["name"])
	set_build_mode("")

func _nearest_idle_villager(pos: Vector3) -> Villager:
	var best: Villager = null
	var best_dist := INF
	for v in Game.villagers:
		if not is_instance_valid(v):
			continue
		if v.state != Villager.State.IDLE:
			continue
		var d := v.global_position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = v
	return best

# ---------------------------------------------------------------- Sieg

func _on_game_won() -> void:
	hud.show_victory()
	fanfare.play_victory()
	Game.log("SIEG! Nordheim ist gegründet!")
