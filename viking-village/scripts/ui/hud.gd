class_name Hud
extends CanvasLayer
## HUD: Ressourcen-Leiste, Bau-Menü, Zeitalter, Nachrichten, Sieg-Bildschirm.

var _resource_labels: Dictionary = {}
var _population_label: Label
var _age_label: Label
var _age_button: Button
var _message_label: Label
var _message_tween: Tween
var _build_buttons: Dictionary = {}
var _train_button: Button
var _selection_label: Label
var _advisor_button: Button
var _victory_panel: PanelContainer
var _main: Main
var _sel_accum := 0.0

func _ready() -> void:
	_main = get_parent() as Main
	_build_ui()
	Game.resource_changed.connect(_on_resource_changed)
	Game.population_changed.connect(_on_population_changed)
	Game.age_changed.connect(_on_age_changed)
	refresh_all()

func _process(delta: float) -> void:
	if _main == null or _main.selected.size() == 0:
		return
	_sel_accum += delta
	if _sel_accum > 0.15:
		_sel_accum = 0.0
		show_selection(_main.selected[0])

# ---------------------------------------------------------------- UI-Aufbau

func _label(text: String, size := 16, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_ui() -> void:
	# --- Ressourcen-Leiste oben ---
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 8.0
	top.offset_bottom = 48.0
	top.offset_left = 8.0
	top.offset_right = -8.0
	add_child(top)
	var top_hbox := HBoxContainer.new()
	top.add_child(top_hbox)
	for res in ResourceKind.all():
		var item := HBoxContainer.new()
		top_hbox.add_child(item)
		item.add_child(_label(ResourceKind.name_of(res) + ": ", 16, _resource_color(res)))
		var value_label := _label("0", 18)
		item.add_child(value_label)
		_resource_labels[res] = value_label
		top_hbox.add_child(HSeparator.new())
	var pop_item := HBoxContainer.new()
	top_hbox.add_child(pop_item)
	_population_label = _label("Bevölkerung: -", 16, Color(0.7, 1.0, 0.7))
	pop_item.add_child(_population_label)

	# --- Bau-Menü unten links ---
	var build_panel := PanelContainer.new()
	build_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_panel.offset_left = 8.0
	build_panel.offset_top = -300.0
	build_panel.offset_right = 350.0
	build_panel.offset_bottom = -8.0
	add_child(build_panel)
	var vbox := VBoxContainer.new()
	build_panel.add_child(vbox)
	vbox.add_child(_label("Bauen", 18, Color(1.0, 0.9, 0.6)))
	for type in BuildingDefs.all_types():
		var def := BuildingDefs.get(type)
		var btn := Button.new()
		btn.text = "%s – %s" % [def["name"], BuildingDefs.cost_text(type)]
		btn.tooltip_text = def["desc"]
		btn.pressed.connect(_on_build_button.bind(type))
		vbox.add_child(btn)
		_build_buttons[type] = btn
	_train_button = Button.new()
	_train_button.text = "Dorfbewohner ausbilden – 50 Essen"
	_train_button.pressed.connect(func(): _main.train_villager())
	vbox.add_child(_train_button)
	var age_hbox := HBoxContainer.new()
	vbox.add_child(age_hbox)
	_age_label = _label("Zeitalter: -", 16, Color(0.7, 0.85, 1.0))
	age_hbox.add_child(_age_label)
	_age_button = Button.new()
	_age_button.text = "Aufsteigen"
	_age_button.pressed.connect(func(): Game.advance_age())
	age_hbox.add_child(_age_button)
	var help_button := Button.new()
	help_button.text = "Hilfe"
	help_button.pressed.connect(_show_help)
	vbox.add_child(help_button)

	# --- Selektions-Anzeige unten Mitte ---
	_selection_label = _label("", 16, Color(1.0, 1.0, 0.8))
	_selection_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_selection_label.offset_top = -70.0
	_selection_label.offset_bottom = -40.0
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_selection_label)

	# --- Nachrichten ---
	_message_label = _label("", 18, Color(1.0, 0.95, 0.7))
	_message_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_message_label.offset_top = -115.0
	_message_label.offset_bottom = -85.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)

	# --- Rechte Seite: Seherin + Tipp ---
	var right_vbox := VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_vbox.offset_left = -280.0
	right_vbox.offset_top = -170.0
	right_vbox.offset_right = -8.0
	right_vbox.offset_bottom = -8.0
	right_vbox.alignment = BoxContainer.ALIGNMENT_END
	add_child(right_vbox)
	_advisor_button = Button.new()
	_advisor_button.text = "Seherin (KI)"
	_advisor_button.pressed.connect(_toggle_advisor)
	right_vbox.add_child(_advisor_button)
	var tip_button := Button.new()
	tip_button.text = "Tipp von der Seherin"
	tip_button.pressed.connect(_ask_tip)
	right_vbox.add_child(tip_button)

	# --- Sieg-Overlay ---
	_victory_panel = PanelContainer.new()
	_victory_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_panel.visible = false
	add_child(_victory_panel)
	var vbox2 := VBoxContainer.new()
	_victory_panel.add_child(vbox2)
	vbox2.add_child(_label("SIEG!", 64, Color(1.0, 0.85, 0.2)))
	vbox2.add_child(_label("Nordheim ist gegründet! Die Große Halle erhebt sich über dem Fjord.", 20))
	var cont := Button.new()
	cont.text = "Weiterspielen"
	cont.pressed.connect(func(): _victory_panel.visible = false)
	vbox2.add_child(cont)

# ---------------------------------------------------------------- Refresh

func refresh_all() -> void:
	for res in _resource_labels:
		_on_resource_changed(res, Game.resources.get(res, 0))
	_on_population_changed(Game.villagers.size(), Game.population_cap)
	_refresh_age()
	_refresh_buttons()

func _on_resource_changed(res: int, amount: int) -> void:
	if _resource_labels.has(res):
		_resource_labels[res].text = str(amount)
	_refresh_buttons()

func _on_population_changed(current: int, cap: int) -> void:
	if _population_label:
		_population_label.text = "Bevölkerung: %d/%d" % [current, cap]
		_population_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7) if current < cap else Color(1.0, 0.6, 0.5))
	_refresh_buttons()

func _on_age_changed(_age: int) -> void:
	_refresh_age()

func _refresh_age() -> void:
	if _age_label == null:
		return
	_age_label.text = "Zeitalter %d: %s" % [Game.age, Game.age_name()]
	if Game.age >= 3:
		_age_button.text = "Letztes Zeitalter"
		_age_button.disabled = true
	else:
		var info := Game.age_progress_info()
		var cost_txt := ""
		for res in info["cost"]:
			cost_txt += "%d %s, " % [info["cost"][res], ResourceKind.name_of(res)]
		cost_txt = cost_txt.trim_suffix(", ")
		_age_button.text = "→ %s (%s)" % [Game.age_name_for(info["target"]), cost_txt]
		_age_button.disabled = not info["available"]
		_age_button.tooltip_text = "Voraussetzungen: %s" % (
			"Gebäude: %s" % BuildingDefs.get(info["requires"])["name"] if info["requires"] != "" else "keine"
		)

func _refresh_buttons() -> void:
	if _build_buttons.is_empty():
		return
	for type in _build_buttons:
		var def := BuildingDefs.get(type)
		var btn: Button = _build_buttons[type]
		var affordable := Game.can_afford(def["cost"])
		var unlocked := true
		if type == "halle" and Game.age < 3:
			unlocked = false
		btn.disabled = not (affordable and unlocked)
		btn.modulate = Color(1.0, 1.0, 0.6) if (_main != null and _main.build_mode == type) else Color.WHITE
	if _train_button:
		_train_button.disabled = not Game.can_train_villager()

func set_build_mode_active(_type: String) -> void:
	_refresh_buttons()

# ---------------------------------------------------------------- Öffentliche API

func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(3.0)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 1.0)

func show_selection(v) -> void:
	if v == null:
		_selection_label.text = ""
	else:
		var carry := ""
		if v.carried_resource >= 0 and v.carried_amount > 0:
			carry = " – trägt %d %s" % [v.carried_amount, ResourceKind.name_of(v.carried_resource)]
		_selection_label.text = "Dorfbewohner: %s%s" % [v.status_text(), carry]

func show_victory() -> void:
	_victory_panel.visible = true

# ---------------------------------------------------------------- Interne Helfer

func _on_build_button(type: String) -> void:
	if _main != null:
		_main.set_build_mode(type)

func _toggle_advisor() -> void:
	var panel := get_node("AdvisorPanel") as AdvisorPanel
	panel.visible = not panel.visible

func _ask_tip() -> void:
	var panel := get_node("AdvisorPanel") as AdvisorPanel
	panel.ask_tip()

func _show_help() -> void:
	Game.log("Hilfe: Linksklick = wählen/befehlen · Rechte Maustaste = Kamera drehen · Mausrad = Zoom · WASD = scrollen · ESC = abbrechen")

func _resource_color(res: int) -> Color:
	match res:
		ResourceKind.Type.WOOD:
			return Color(0.72, 0.5, 0.25)
		ResourceKind.Type.FOOD:
			return Color(0.85, 0.3, 0.3)
		ResourceKind.Type.GOLD:
			return Color(1.0, 0.85, 0.2)
		ResourceKind.Type.STONE:
			return Color(0.65, 0.65, 0.7)
		ResourceKind.Type.METAL:
			return Color(0.6, 0.7, 0.85)
		ResourceKind.Type.OIL_STONE:
			return Color(0.4, 1.0, 0.5)
	return Color.WHITE
