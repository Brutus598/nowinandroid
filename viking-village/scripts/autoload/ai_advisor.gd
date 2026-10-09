extends Node
## KI-Berater „Sigrid die Seherin“.
## Nutzt die GitHub Models Responses API (https://models.github.ai/inference/responses).
## Ohne Token (oder bei Fehlern) fällt die Seherin auf lokale, kontextbezogene Tipps zurück.

signal answer_received(text: String)
signal request_failed(error: String)

const API_URL := "https://models.github.ai/inference/responses"
const DEFAULT_MODEL := "gpt-4.1-mini"
const CONFIG_PATH := "user://nordheim_advisor.cfg"

const SYSTEM_PROMPT := (
	"Du bist Sigrid, die weise Seherin des Wikinger-Dorfs Nordheim. "
	+ "Du berätst den Häuptling beim Aufbau seines Dorfes. "
	+ "Ressourcen: Holz, Essen, Gold, Stein, Metall und Ölstein. "
	+ "Antworte immer auf Deutsch, höchstens 4 kurze Sätze, hilfreich und im würdevollen Wikinger-Ton. "
	+ "Schlage immer einen konkreten nächsten Schritt vor."
)

var token := ""
var model := DEFAULT_MODEL
var http: HTTPRequest
var _pending_question := ""

func _ready() -> void:
	_load_token()
	var env_token := OS.get_environment("GITHUB_TOKEN")
	if env_token != "":
		token = env_token
	http = HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	http.request_completed.connect(_on_request_completed)

func set_token(new_token: String) -> void:
	token = new_token.strip_edges()
	_save_token()

func has_token() -> bool:
	return token != ""

func ask(question: String) -> void:
	question = question.strip_edges()
	if question == "":
		return
	_pending_question = question
	if not has_token():
		answer_received.emit(local_tip(question))
		return
	var payload := build_payload(question)
	var headers := [
		"Authorization: Bearer " + token,
		"Content-Type: application/json",
	]
	var err := http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		request_failed.emit("HTTP-Fehler: %s" % error_string(err))
		answer_received.emit(local_tip(question))

func build_payload(question: String) -> Dictionary:
	return {
		"model": model,
		"input": [
			{"role": "system", "content": SYSTEM_PROMPT},
			{"role": "user", "content": "Spielstand:\n%s\n\nFrage des Häuptlings: %s" % [JSON.stringify(Game.get_context()), question]},
		],
		"temperature": 0.7,
		"max_output_tokens": 400,
	}

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		request_failed.emit("Antwort der Seherin fehlgeschlagen (HTTP %d)" % response_code)
		answer_received.emit(local_tip(_pending_question))
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var text := extract_text(parsed)
	if text == "":
		request_failed.emit("Konnte die Antwort der Seherin nicht lesen.")
		answer_received.emit(local_tip(_pending_question))
	else:
		answer_received.emit(text)

func extract_text(parsed) -> String:
	# Responses-API-Format: output[] -> content[] -> output_text
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var chunks: Array = []
	for item in parsed.get("output", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if item.get("type", "") != "message":
			continue
		for content in item.get("content", []):
			if typeof(content) == TYPE_DICTIONARY and content.get("type", "") == "output_text":
				chunks.append(str(content.get("text", "")))
	if chunks.size() > 0:
		return "\n".join(chunks)
	# Fallback: Chat-Completions-Format
	var choices = parsed.get("choices", [])
	if choices.size() > 0 and typeof(choices[0]) == TYPE_DICTIONARY:
		var msg = choices[0].get("message", {})
		if typeof(msg) == TYPE_DICTIONARY:
			return str(msg.get("content", ""))
	return ""

func local_tip(_question: String = "") -> String:
	var tips := _build_tips()
	var tip: String = tips[randi() % tips.size()]
	var prefix := "Die Seherin spricht: "
	if not has_token():
		prefix = "Die Seherin spricht (Offline-Modus, kein GitHub-Token): "
	return prefix + tip

func _build_tips() -> Array:
	var ctx := Game.get_context()
	var res: Dictionary = ctx["ressourcen"]
	var tips: Array = []
	if res.get("Essen", 0) < 120:
		tips.append("Sammle mehr Essen: schicke Dorfbewohner zu den Beerenbüschen am Waldrand oder errichte ein Langhaus als Essens-Ablage.")
	if res.get("Holz", 0) < 150:
		tips.append("Holz ist das Rückgrat deines Dorfs. Fälle die Kiefern im Westen, bevor du große Bauten planst.")
	if res.get("Metall", 0) < 50:
		tips.append("Schicke einen Dorfbewohner zu den Eisenerzen. In der Schmiede schmiedest du später bessere Werkzeuge.")
	if res.get("Ölstein", 0) < 30:
		tips.append("Die geheimnisvollen Ölsteine glühen grünlich in den Bergen. Sie werden in der Siedlungszeit wichtig sein.")
	if ctx["bevölkerung"] >= ctx["bevölkerungslimit"]:
		tips.append("Dein Dorf ist voll! Baue ein Langhaus, um mehr Dorfbewohner auszubilden.")
	if not Game.has_building("schmiede"):
		tips.append("Errichte eine Schmiede, um in die Handelszeit aufzusteigen.")
	if Game.age == 1:
		tips.append("Sammle 300 Essen und baue eine Schmiede, dann kann das Zeitalter der Händler beginnen.")
	elif Game.age == 2:
		tips.append("Sammle 300 Gold und 200 Holz, um in die Siedlungszeit aufzusteigen.")
	else:
		tips.append("Baue die Große Halle, um Nordheim zu einem wahren Wikinger-Sitz zu machen!")
	tips.append("Tipp: Rechte Maustaste dreht die Kamera, das Mausrad zoomt, WASD verschiebt das Bild.")
	return tips

func _save_token() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("advisor", "token", token)
	cfg.save(CONFIG_PATH)

func _load_token() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		var saved = cfg.get_value("advisor", "token", "")
		if typeof(saved) == TYPE_STRING and saved != "":
			token = saved
