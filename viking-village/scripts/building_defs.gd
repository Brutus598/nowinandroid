class_name BuildingDefs
## Definitionen aller Gebäude: Kosten, Bauzeit, Wohnraum, Ablage-Ressourcen.

const DEFS: Dictionary = {
	"langhaus": {
		"name": "Langhaus",
		"desc": "Wohnhaus. +5 Bevölkerung und Annahme von Essen.",
		"cost": {ResourceKind.Type.WOOD: 150, ResourceKind.Type.STONE: 50},
		"housing": 5,
		"build_time": 20.0,
		"dropoff": [ResourceKind.Type.FOOD],
		"collision_size": Vector3(4.4, 2.6, 2.8),
	},
	"lagerhaus": {
		"name": "Lagerhaus",
		"desc": "Lager für Holz, Stein, Metall, Gold und Ölstein.",
		"cost": {ResourceKind.Type.WOOD: 100},
		"housing": 0,
		"build_time": 15.0,
		"dropoff": [ResourceKind.Type.WOOD, ResourceKind.Type.STONE, ResourceKind.Type.METAL, ResourceKind.Type.GOLD, ResourceKind.Type.OIL_STONE],
		"collision_size": Vector3(3.2, 2.2, 2.6),
	},
	"schmiede": {
		"name": "Schmiede",
		"desc": "Wird für den Aufstieg in die Handelszeit benötigt.",
		"cost": {ResourceKind.Type.WOOD: 100, ResourceKind.Type.STONE: 100},
		"housing": 0,
		"build_time": 25.0,
		"dropoff": [],
		"collision_size": Vector3(3.6, 2.4, 2.8),
	},
	"halle": {
		"name": "Große Halle",
		"desc": "Prunkbau des Dorfes. Wer sie in der Siedlungszeit vollendet, gewinnt.",
		"cost": {ResourceKind.Type.WOOD: 300, ResourceKind.Type.STONE: 200, ResourceKind.Type.GOLD: 100},
		"housing": 10,
		"build_time": 40.0,
		"dropoff": [],
		"collision_size": Vector3(6.4, 4.2, 4.0),
		"win": true,
	},
}

const ORDER: Array = ["langhaus", "lagerhaus", "schmiede", "halle"]

static func get(type: String) -> Dictionary:
	return DEFS.get(type, {})

static func all_types() -> Array:
	return ORDER

static func cost_text(type: String) -> String:
	var parts: Array = []
	for res in DEFS[type]["cost"]:
		parts.append("%d %s" % [DEFS[type]["cost"][res], ResourceKind.name_of(res)])
	return ", ".join(parts)
