class_name Villager
extends CharacterBody3D
## Ein Dorfbewohner mit prozeduraler 3D-Animation:
## Gehen (Bobbing + Werkzeug-Schwung), Sammeln (Axtschwung), Bauen, Abliefern.

enum State { IDLE, MOVING, GATHERING, RETURNING, BUILDING }

const MOVE_LIMIT_X := 52.0 # nicht tiefer in den Fjord hinaus

@export var move_speed := 4.2

var state := State.IDLE
var carried_resource := -1
var carried_amount := 0

var move_target := Vector3.ZERO
var gather_target: ResourceNode = null
var last_gather_node: ResourceNode = null
var dropoff: Building = null
var builder_target: Building = null

var is_selected := false
var _walk_phase := 0.0

@onready var visuals: Node3D = $Visuals
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var gather_timer: Timer = $GatherTimer

var _body: MeshInstance3D
var _head: MeshInstance3D
var _helmet: MeshInstance3D
var _tool_pivot: Node3D
var _tool: MeshInstance3D
var _carry_mesh: MeshInstance3D
var _idle_tween: Tween
var _ring_tween: Tween

func _ready() -> void:
	add_to_group("villagers")
	_build_visuals()
	gather_timer.timeout.connect(_on_gather_tick)
	Game.register_villager(self)
	_play_idle()

func _exit_tree() -> void:
	Game.unregister_villager(self)

# ---------------------------------------------------------------- Visuals

func _build_visuals() -> void:
	_body = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.26
	body_mesh.height = 0.95
	_body.mesh = body_mesh
	_body.material_override = ProcMaterials.cloth(Color(0.5, 0.32, 0.18))
	_body.position.y = 0.78
	visuals.add_child(_body)

	_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	_head.mesh = head_mesh
	_head.material_override = ProcMaterials.mat(Color(0.9, 0.7, 0.55))
	_head.position.y = 1.42
	visuals.add_child(_head)

	_helmet = MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.19
	_helmet.mesh = helmet_mesh
	_helmet.material_override = ProcMaterials.steel()
	_helmet.scale.y = 0.55
	_helmet.position.y = 1.5
	visuals.add_child(_helmet)

	# Werkzeug (Axt) an einem Pivot vor dem Körper (+Z ist vorne)
	_tool_pivot = Node3D.new()
	_tool_pivot.position = Vector3(0.3, 0.85, 0.42)
	visuals.add_child(_tool_pivot)
	_tool = MeshInstance3D.new()
	var tool_mesh := BoxMesh.new()
	tool_mesh.size = Vector3(0.07, 0.55, 0.07)
	_tool.mesh = tool_mesh
	_tool.material_override = ProcMaterials.steel()
	_tool.position.y = 0.28
	_tool_pivot.add_child(_tool)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.09, 0.3, 0.09)
	handle.mesh = handle_mesh
	handle.material_override = ProcMaterials.wood(true)
	handle.position.y = -0.12
	_tool_pivot.add_child(handle)

	# Selektionsring
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.55
	ring_mesh.bottom_radius = 0.55
	ring_mesh.height = 0.06
	selection_ring.mesh = ring_mesh
	var ring_mat := ProcMaterials.emissive(Color(1.0, 0.9, 0.2), 1.5)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_ring.material_override = ring_mat
	selection_ring.position.y = 0.06
	selection_ring.visible = false

func _play_idle() -> void:
	_kill_idle()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(visuals, "rotation:z", 0.02, 0.9)
	_idle_tween.tween_property(visuals, "rotation:z", -0.02, 0.9)

func _kill_idle() -> void:
	if _idle_tween:
		_idle_tween.kill()
		_idle_tween = null

func _play_chop() -> void:
	var t := create_tween()
	t.tween_property(_tool_pivot, "rotation:x", -0.9, 0.12)
	t.tween_property(_tool_pivot, "rotation:x", 0.15, 0.25)

func _animate(delta: float) -> void:
	match state:
		State.MOVING, State.GATHERING, State.RETURNING, State.BUILDING:
			_walk_phase += delta * 11.0
			visuals.position.y = sin(_walk_phase) * 0.07
			_tool_pivot.rotation.x = sin(_walk_phase) * 0.45
		State.IDLE:
			visuals.position.y = lerp(visuals.position.y, 0.0, minf(delta * 12.0, 1.0))
			_tool_pivot.rotation.x = lerp(_tool_pivot.rotation.x, 0.15, minf(delta * 8.0, 1.0))

# ---------------------------------------------------------------- Selection

func select() -> void:
	is_selected = true
	selection_ring.visible = true
	if _ring_tween:
		_ring_tween.kill()
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_property(selection_ring, "scale", Vector3(1.25, 1.25, 1.25), 0.5)
	_ring_tween.tween_property(selection_ring, "scale", Vector3.ONE, 0.5)

func deselect() -> void:
	is_selected = false
	selection_ring.visible = false
	if _ring_tween:
		_ring_tween.kill()
		_ring_tween = null
	selection_ring.scale = Vector3.ONE

# ---------------------------------------------------------------- Commands

func command_move(target: Vector3) -> void:
	move_target = Vector3(clampf(target.x, -95.0, MOVE_LIMIT_X), 0.0, target.z)
	gather_target = null
	builder_target = null
	dropoff = null
	state = State.MOVING
	_kill_idle()

func command_gather(node: ResourceNode) -> void:
	if node == null or node.is_depleted():
		return
	gather_target = node
	last_gather_node = node
	carried_resource = node.resource_type
	builder_target = null
	dropoff = null
	gather_timer.stop()
	state = State.GATHERING
	_kill_idle()

func command_build(b: Building) -> void:
	if b == null or b.completed:
		return
	builder_target = b
	gather_target = null
	state = State.BUILDING
	_kill_idle()

func command_deposit(b: Building) -> void:
	if b == null:
		return
	dropoff = b
	state = State.RETURNING
	_kill_idle()

# ---------------------------------------------------------------- Physics

func _physics_process(delta: float) -> void:
	match state:
		State.MOVING:
			if _move_towards(move_target, 0.3):
				state = State.IDLE
				_play_idle()
		State.GATHERING:
			if not is_instance_valid(gather_target) or gather_target.is_depleted():
				_finish_gathering()
			elif _move_towards(gather_target.global_position, gather_target.interact_distance):
				_face(gather_target.global_position)
				if gather_timer.is_stopped():
					gather_timer.start()
		State.RETURNING:
			if dropoff == null or not is_instance_valid(dropoff) or not dropoff.accepts(carried_resource):
				dropoff = Game.find_dropoff(carried_resource, global_position)
				if dropoff == null:
					state = State.IDLE
					_play_idle()
			if is_instance_valid(dropoff) and _move_towards(dropoff.global_position, dropoff.interact_distance):
				_deposit()
		State.BUILDING:
			if not is_instance_valid(builder_target) or builder_target.completed:
				state = State.IDLE
				_play_idle()
			elif _move_towards(builder_target.global_position, builder_target.interact_distance + 0.5):
				builder_target.add_build_progress(delta)
		State.IDLE:
			if carried_amount > 0 and carried_resource >= 0 and dropoff == null:
				dropoff = Game.find_dropoff(carried_resource, global_position)
				if dropoff != null:
					state = State.RETURNING
	_animate(delta)

func _move_towards(target: Vector3, arrive_dist: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= arrive_dist:
		velocity = Vector3.ZERO
		return true
	var dir := to / dist
	velocity = dir * move_speed
	move_and_slide()
	_face_dir(dir)
	return false

func _face(target: Vector3) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		_face_dir(dir)

func _face_dir(dir: Vector3) -> void:
	visuals.rotation.y = atan2(dir.x, dir.z)

# ---------------------------------------------------------------- Gathering

func _on_gather_tick() -> void:
	if not is_instance_valid(gather_target) or gather_target.is_depleted():
		_finish_gathering()
		return
	_face(gather_target.global_position)
	_play_chop()
	var rate := maxi(int(gather_target.gather_rate * Game.gather_multiplier()), 1)
	var got := gather_target.gather(rate)
	carried_amount += got
	_update_carry_visual()
	if gather_target.is_depleted():
		_finish_gathering()

func _finish_gathering() -> void:
	gather_timer.stop()
	if carried_amount > 0:
		state = State.RETURNING
		dropoff = Game.find_dropoff(carried_resource, global_position)
		if dropoff == null:
			Game.log("Kein Lagerhaus für %s! Baue eines." % ResourceKind.name_of(carried_resource))
			state = State.IDLE
			_play_idle()
	else:
		state = State.IDLE
		_play_idle()
	gather_target = null

func _deposit() -> void:
	if carried_amount > 0 and carried_resource >= 0:
		Game.add_resource(carried_resource, carried_amount)
		Game.log("%d %s abgeliefert." % [carried_amount, ResourceKind.name_of(carried_resource)])
	carried_amount = 0
	_update_carry_visual()
	dropoff = null
	if is_instance_valid(last_gather_node) and not last_gather_node.is_depleted():
		command_gather(last_gather_node) # automatisch weiter sammeln
	else:
		state = State.IDLE
		_play_idle()

func _update_carry_visual() -> void:
	if _carry_mesh == null:
		_carry_mesh = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.12
		_carry_mesh.mesh = m
		_carry_mesh.position = Vector3(-0.2, 0.9, -0.25)
		visuals.add_child(_carry_mesh)
	_carry_mesh.visible = carried_amount > 0
	if carried_amount > 0:
		var s := 0.6 + minf(carried_amount, 40) / 40.0 * 0.8
		_carry_mesh.scale = Vector3(s, s, s)
		_carry_mesh.material_override = ProcMaterials.mat(_resource_color(carried_resource))

func _resource_color(res: int) -> Color:
	match res:
		ResourceKind.Type.WOOD:
			return Color(0.6, 0.4, 0.2)
		ResourceKind.Type.FOOD:
			return Color(0.8, 0.2, 0.2)
		ResourceKind.Type.GOLD:
			return Color(1.0, 0.8, 0.2)
		ResourceKind.Type.STONE:
			return Color(0.6, 0.6, 0.65)
		ResourceKind.Type.METAL:
			return Color(0.65, 0.7, 0.8)
		ResourceKind.Type.OIL_STONE:
			return Color(0.3, 0.9, 0.4)
	return Color.WHITE

# ---------------------------------------------------------------- Status

func status_text() -> String:
	match state:
		State.IDLE:
			if carried_amount > 0:
				return "Ruht (trägt %d %s)" % [carried_amount, ResourceKind.name_of(carried_resource)]
			return "Ruht"
		State.MOVING:
			return "Unterwegs"
		State.GATHERING:
			if is_instance_valid(gather_target):
				return "Sammelt %s" % ResourceKind.name_of(gather_target.resource_type)
			return "Sammelt"
		State.RETURNING:
			return "Liefert %s ab" % ResourceKind.name_of(carried_resource)
		State.BUILDING:
			return "Baut ein Gebäude"
	return ""
