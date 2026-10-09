class_name ProcMaterials
## Erzeugt Materialien für die prozeduralen 3D-Modelle des Spiels.
## Jeder Aufruf liefert eine NEUE Material-Instanz (niemals teilen!).

static func mat(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

static func wood(dark := false) -> StandardMaterial3D:
	if dark:
		return mat(Color(0.42, 0.26, 0.12))
	return mat(Color(0.6, 0.4, 0.2))

static func thatch() -> StandardMaterial3D:
	return mat(Color(0.62, 0.47, 0.22), 1.0)

static func stone() -> StandardMaterial3D:
	return mat(Color(0.55, 0.55, 0.58), 0.95)

static func dark_stone() -> StandardMaterial3D:
	return mat(Color(0.32, 0.32, 0.36), 0.9)

static func foliage() -> StandardMaterial3D:
	return mat(Color(0.13, 0.35, 0.16), 1.0)

static func steel() -> StandardMaterial3D:
	return mat(Color(0.75, 0.78, 0.82), 0.35, 0.9)

static func gold() -> StandardMaterial3D:
	return mat(Color(0.95, 0.75, 0.2), 0.25, 1.0)

static func iron() -> StandardMaterial3D:
	return mat(Color(0.4, 0.42, 0.45), 0.5, 0.8)

static func cloth(color: Color) -> StandardMaterial3D:
	return mat(color, 0.95)

static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
