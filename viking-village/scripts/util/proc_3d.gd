class_name Proc3D
## Hilfsfunktionen zum prozeduralen Bauen von 3D-Szenen (Meshes + Materialien).

static func mesh(parent: Node, m: ArrayMesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return mesh(parent, m, mat, pos, rot)

static func cylinder(parent: Node, radius: float, height: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.bottom_radius = radius
	m.height = height
	return mesh(parent, m, mat, pos, rot)

static func cone(parent: Node, radius: float, height: float, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := ConeMesh.new()
	m.bottom_radius = radius
	m.height = height
	return mesh(parent, m, mat, pos, rot)

static func sphere(parent: Node, radius: float, mat: Material, pos: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	return mesh(parent, m, mat, pos, Vector3.ZERO, scale)

static func prism(parent: Node, size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return mesh(parent, m, mat, pos)
