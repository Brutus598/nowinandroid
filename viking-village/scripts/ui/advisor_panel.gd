class_name AdvisorPanel
extends PanelContainer
## Chat-Panel der KI-Seherin „Sigrid“ (GitHub Models Responses API).
## Funktioniert auch ohne Token im Offline-Modus mit lokalen Tipps.

var _log: RichTextLabel
var _input: LineEdit
var _status: Label
var _token_edit: LineEdit

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -800.0
	offset_top = -400.0
	offset_right = -370.0
	offset_bottom = -70.0
	visible = false
	_build_ui()
	AiAdvisor.answer_received.connect(_on_answer)
	AiAdvisor.request_failed.connect(_on_failed)
	_append("Die Seherin: Sei gegrüßt, Häuptling von Nordheim! Frage mich um Rat.", Color(0.7, 0.85, 1.0))
	if not AiAdvisor.has_token():
		_append("Hinweis: Kein GitHub-Token hinterlegt – die Seherin antwortet im Offline-Modus mit lokalen Tipps. Trage unten ein Token ein, um die KI zu aktivieren.", Color(1.0, 0.8, 0.5))

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Sigrid, die Seherin (KI-Berater)"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(400.0, 170.0)
	_log.bbcode_enabled = true
	_log.scroll_active = true
	vbox.add_child(_log)

	var input_hbox := HBoxContainer.new()
	vbox.add_child(input_hbox)
	_input = LineEdit.new()
	_input.placeholder_text = "Frage die Seherin …"
	_input.custom_minimum_size = Vector2(260.0, 0.0)
	_input.text_submitted.connect(func(_t): _send())
	input_hbox.add_child(_input)
	var send := Button.new()
	send.text = "Senden"
	send.pressed.connect(_send)
	input_hbox.add_child(send)
	var tip := Button.new()
	tip.text = "Tipp"
	tip.pressed.connect(ask_tip)
	input_hbox.add_child(tip)

	_status = Label.new()
	_status.text = "Bereit."
	vbox.add_child(_status)

	var token_hbox := HBoxContainer.new()
	vbox.add_child(token_hbox)
	var tl := Label.new()
	tl.text = "GitHub-Token:"
	token_hbox.add_child(tl)
	_token_edit = LineEdit.new()
	_token_edit.secret = true
	_token_edit.placeholder_text = "ghp_… (wird lokal gespeichert)"
	_token_edit.custom_minimum_size = Vector2(180.0, 0.0)
	token_hbox.add_child(_token_edit)
	var save := Button.new()
	save.text = "Speichern"
	save.pressed.connect(_save_token)
	token_hbox.add_child(save)

# ---------------------------------------------------------------- Öffentliche API

func ask_tip() -> void:
	visible = true
	_send_question("Gib mir einen kurzen, konkreten Tipp für meine aktuelle Situation im Dorf Nordheim.")

# ---------------------------------------------------------------- Interne Helfer

func _send() -> void:
	var q := _input.text.strip_edges()
	if q == "":
		return
	_input.text = ""
	_send_question(q)

func _send_question(q: String) -> void:
	_append("Du: " + q, Color(1.0, 0.9, 0.5))
	_status.text = "Die Seherin denkt nach …"
	AiAdvisor.ask(q)

func _on_answer(text: String) -> void:
	_append("Sigrid: " + text, Color(0.75, 0.9, 1.0))
	_status.text = "Bereit." if AiAdvisor.has_token() else "Offline-Modus (lokale Tipps)"

func _on_failed(err: String) -> void:
	_append("Fehler: " + err, Color(1.0, 0.5, 0.4))
	_status.text = "Fehler – siehe Log."

func _append(text: String, color: Color) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	_log.scroll_to_line(_log.get_line_count() - 1)

func _save_token() -> void:
	AiAdvisor.set_token(_token_edit.text)
	_status.text = "Token gespeichert." if AiAdvisor.has_token() else "Token entfernt."
