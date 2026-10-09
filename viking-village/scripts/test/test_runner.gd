extends Node
## Headless-Test-Harness für Nordheim.
## Aufruf: godot --headless --path viking-village res://scenes/test/test_runner.tscn
## Exit-Code 0 = alle Tests bestanden, 1 = Fehler.

var _failures := 0
var _checks := 0

func _ready() -> void:
	await get_tree().process_frame
	test_economy()
	test_world_gen()
	test_villager_gather()
	test_building()
	test_advisor()
	await test_main_scene_loads()
	print("========================================")
	print("TESTS: %d Prüfungen, %d Fehler" % [_checks, _failures])
	print("ERGEBNIS: %s" % ("FEHLGESCHLAGEN" if _failures > 0 else "BESTANDEN"))
	get_tree().quit(1 if _failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  [OK] %s" % label)
	else:
		_failures += 1
		printerr("  [FEHLER] %s" % label)

func test_economy() -> void:
	print("- Test: Ressourcen-Ökonomie")
	var before := Game.resources[ResourceKind.Type.WOOD]
	Game.add_resource(ResourceKind.Type.WOOD, 25)
	_check(Game.resources[ResourceKind.Type.WOOD] == before + 25, "add_resource erhöht Holz um 25")
	_check(Game.can_afford({ResourceKind.Type.WOOD: 10}), "can_afford mit genug Holz")
	_check(not Game.spend({ResourceKind.Type.WOOD: 999999}), "spend schlägt fehl bei zu wenig Holz")
	_check(Game.spend({ResourceKind.Type.WOOD: 10}), "spend bucht 10 Holz")
	_check(Game.resources[ResourceKind.Type.WOOD] == before + 15, "Holz nach spend korrekt")
	_check(Game.resources[ResourceKind.Type.METAL] == 0, "Metall startet bei 0")

func test_world_gen() -> void:
	print("- Test: Weltgenerator")
	var gen := WorldGen.new()
	add_child(gen)
	gen.generate(42)
	var nodes := get_tree().get_nodes_in_group("resource_nodes")
	_check(nodes.size() >= 60, "mindestens 60 Ressourcen-Nodes erzeugt (%d)" % nodes.size())
	var trees := 0
	var land_ok := true
	for n in nodes:
		if n.resource_type == ResourceKind.Type.WOOD and n.visual_style == "tree":
			trees += 1
		if not n.in_water and n.global_position.x > 13.0:
			land_ok = false
	_check(trees >= 30, "mindestens 30 Bäume generiert (%d)" % trees)
	_check(land_ok, "Land-Ressourcen liegen nicht im Fjord")
	# Determinismus: gleicher Seed -> gleiche Welt
	var gen2 := WorldGen.new()
	add_child(gen2)
	gen2.generate(42)
	var first_a: ResourceNode = null
	var first_b: ResourceNode = null
	for n in gen.get_children():
		if n is ResourceNode and n.visual_style == "tree":
			first_a = n
			break
	for n in gen2.get_children():
		if n is ResourceNode and n.visual_style == "tree":
			first_b = n
			break
	_check(first_a != null and first_b != null and first_a.global_position == first_b.global_position, "Weltgenerator ist deterministisch (Seed 42)")
	gen2.queue_free()

func test_villager_gather() -> void:
	print("- Test: Dorfbewohner sammelt und liefert ab")
	var node: ResourceNode = load("res://scenes/resource_node.tscn").instantiate()
	node.resource_type = ResourceKind.Type.WOOD
	node.visual_style = "tree"
	node.amount = 30
	node.max_amount = 30
	node.gather_rate = 5
	add_child(node)
	node.global_position = Vector3(5.0, 0.0, 5.0)

	var v: Villager = load("res://scenes/villager.tscn").instantiate()
	add_child(v)
	v.global_position = Vector3(0.0, 0.0, 0.0)

	var wood_before := Game.resources[ResourceKind.Type.WOOD]
	v.command_gather(node)
	_check(v.state == Villager.State.GATHERING, "Dorfbewohner wechselt in Sammel-Zustand")
	v.global_position = node.global_position + Vector3(1.5, 0.0, 0.0)
	for i in 12:
		v._on_gather_tick()
		if node.is_depleted():
			break
	_check(node.is_depleted(), "Ressource nach Sammel-Ticks erschöpft")
	_check(v.carried_amount == 30, "Dorfbewohner trägt 30 Holz (%d)" % v.carried_amount)
	_check(v.state == Villager.State.RETURNING, "Dorfbewohner kehrt zur Ablage zurück")

	var wh: Building = load("res://scenes/building.tscn").instantiate()
	wh.building_type = "lagerhaus"
	wh.completed = true
	add_child(wh)
	wh.global_position = Vector3(-5.0, 0.0, -5.0)
	v.global_position = wh.global_position + Vector3(2.0, 0.0, 0.0)
	v._deposit()
	_check(Game.resources[ResourceKind.Type.WOOD] == wood_before + 30, "30 Holz im Lagerhaus angekommen")
	_check(v.carried_amount == 0, "Dorfbewohner hat vollständig abgeliefert")
	_check(v.state == Villager.State.IDLE, "Dorfbewohner ist danach im Leerlauf")
	v.queue_free()
	node.queue_free()
	wh.queue_free()

func test_building() -> void:
	print("- Test: Gebäudebau")
	var b: Building = load("res://scenes/building.tscn").instantiate()
	b.building_type = "langhaus"
	add_child(b)
	b.global_position = Vector3(20.0, 0.0, 20.0)
	_check(not b.completed, "Gebäude startet unfertig")
	_check(not b.accepts(ResourceKind.Type.FOOD), "unfertiges Gebäude nimmt nichts an")
	var cap_before := Game.population_cap
	b.add_build_progress(9999.0)
	_check(b.completed, "Gebäude ist nach genug Baufortschritt fertig")
	_check(Game.population_cap == cap_before + 5, "Langhaus erhöht das Wohnungslimit um 5")
	_check(b.accepts(ResourceKind.Type.FOOD), "fertiges Langhaus nimmt Essen an")
	_check(not b.accepts(ResourceKind.Type.WOOD), "Langhaus nimmt kein Holz an")
	_check(Game.has_building("langhaus"), "Game erkennt fertiges Langhaus")
	_check(Game.can_train_villager(), "Dorfbewohner kann ausgebildet werden (Langhaus + Platz + Essen)")
	b.queue_free()

func test_advisor() -> void:
	print("- Test: KI-Berater (GitHub Responses API)")
	var ctx := Game.get_context()
	_check(ctx.has("ressourcen") and ctx.has("zeitalter"), "Kontext enthält Ressourcen und Zeitalter")
	_check(ctx["ressourcen"].has("Holz") and ctx["ressourcen"].has("Ölstein"), "Kontext enthält deutsche Ressourcennamen")
	var payload := AiAdvisor.build_payload("Was soll ich als Nächstes bauen?")
	_check(payload.has("model") and str(payload["model"]) != "", "Payload enthält Modell-Namen")
	_check(payload.has("input") and payload["input"].size() == 2, "Payload enthält System- + User-Nachricht")
	_check(JSON.stringify(payload).find("Nordheim") != -1, "Payload enthält den Spielstand")
	var sample := {"output": [{"type": "message", "content": [{"type": "output_text", "text": "Hallo Häuptling!"}]}]}
	_check(AiAdvisor.extract_text(sample) == "Hallo Häuptling!", "Responses-API-Antwort wird korrekt geparst")
	var sample_cc := {"choices": [{"message": {"content": "Tipp aus der API"}}]}
	_check(AiAdvisor.extract_text(sample_cc) == "Tipp aus der API", "Chat-Completions-Format wird als Fallback geparst")
	AiAdvisor.token = "" # lokalen Fallback erzwingen
	var text := ""
	AiAdvisor.answer_received.connect(func(t): text = t)
	AiAdvisor.ask("Hallo Seherin")
	_check(text.length() > 20, "Lokaler Fallback-Tipp ohne Token (%d Zeichen)" % text.length())

func test_main_scene_loads() -> void:
	print("- Test: Hauptszene lädt und initialisiert die Welt")
	var main := load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var entities := main.get_node("Entities")
	_check(entities.get_child_count() >= 5, "Start-Entities gespawnt (2 Gebäude + 3 Dorfbewohner = %d)" % entities.get_child_count())
	_check(get_tree().get_nodes_in_group("buildings").size() >= 2, "Startgebäude sind registriert")
	_check(get_tree().get_nodes_in_group("resource_nodes").size() >= 60, "Welt wurde generiert")
	_check(get_tree().get_nodes_in_group("villagers").size() >= 3, "Dorfbewohner sind registriert")
	_check(main.get_node("HUD") != null, "HUD ist vorhanden")
	_check(Game.population_cap >= 10, "Wohnungslimit nach Start korrekt (%d)" % Game.population_cap)
	main.queue_free()
