class_name ResourceKind
## Ressourcentypen des Wikinger-Dorfs Nordheim.

enum Type { WOOD, FOOD, GOLD, STONE, METAL, OIL_STONE }

const NAMES := {
	Type.WOOD: "Holz",
	Type.FOOD: "Essen",
	Type.GOLD: "Gold",
	Type.STONE: "Stein",
	Type.METAL: "Metall",
	Type.OIL_STONE: "Ölstein",
}

const ALL: Array = [Type.WOOD, Type.FOOD, Type.GOLD, Type.STONE, Type.METAL, Type.OIL_STONE]

static func name_of(t: int) -> String:
	return NAMES.get(t, "Unbekannt")

static func all() -> Array:
	return ALL
