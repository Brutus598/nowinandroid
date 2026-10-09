extends Node
## Definiert alle Input-Aktionen (Tastatur + Maus) zur Laufzeit,
## damit das Spiel ohne manuell gepflegte InputMap sofort steuerbar ist.

func _ready() -> void:
	_define_key("cam_forward", [KEY_W, KEY_UP])
	_define_key("cam_back", [KEY_S, KEY_DOWN])
	_define_key("cam_left", [KEY_A, KEY_LEFT])
	_define_key("cam_right", [KEY_D, KEY_RIGHT])
	_define_mouse("cam_rotate", MOUSE_BUTTON_RIGHT)

func _define_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.keycode = key
		InputMap.action_add_event(action, ev)

func _define_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
