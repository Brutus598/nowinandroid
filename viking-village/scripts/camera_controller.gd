class_name CameraController
extends Node3D
## RTS-Kamera: WASD/Pfeiltasten scrollen, rechte Maustaste dreht, Mausrad zoomt.
## Touch: 1 Finger = Kamera verschieben, 2 Finger = zoomen + drehen.

@export var target := Vector3.ZERO
@export var distance := 28.0
@export var min_distance := 10.0
@export var max_distance := 70.0
@export var pan_speed := 18.0
@export var map_limit := 70.0

var yaw := 0.7
var pitch := 0.85
var _rotating := false
var _touches: Dictionary = {}
var _pinch_start_distance := 0.0
var _pinch_angle := 0.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	camera.make_current()
	_update_camera()

func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_action_pressed("cam_forward"):
		pan.y -= 1.0
	if Input.is_action_pressed("cam_back"):
		pan.y += 1.0
	if Input.is_action_pressed("cam_left"):
		pan.x -= 1.0
	if Input.is_action_pressed("cam_right"):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var speed := pan_speed * (0.5 + distance / 40.0)
		target += (fwd * pan.y + right * pan.x) * speed * delta
		_clamp_target()
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					distance = clampf(distance * 0.88, min_distance, max_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					distance = clampf(distance * 1.13, min_distance, max_distance)
			MOUSE_BUTTON_RIGHT:
				_rotating = event.pressed
	elif event is InputEventMouseMotion:
		if _rotating and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch - event.relative.y * 0.006, 0.35, 1.35)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			if _touches.size() < 2:
				_pinch_start_distance = 0.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			var drag := event as InputEventScreenDrag
			var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var right := Vector3(cos(yaw), 0.0, -sin(yaw))
			var k := 0.03 * (distance / 28.0)
			target -= (right * drag.relative.x + fwd * drag.relative.y) * k
			_clamp_target()
		elif _touches.size() == 2:
			var points: Array = _touches.values()
			var delta_v := points[0] - points[1]
			var d := (delta_v as Vector2).length()
			if _pinch_start_distance > 0.0 and d > 0.0:
				distance = clampf(distance * (_pinch_start_distance / d), min_distance, max_distance)
				yaw += ((delta_v as Vector2).angle() - _pinch_angle) * 0.5
			_pinch_start_distance = d
			_pinch_angle = (delta_v as Vector2).angle()

func _clamp_target() -> void:
	target.x = clampf(target.x, -map_limit, 55.0)
	target.z = clampf(target.z, -map_limit, map_limit)

func _update_camera() -> void:
	rotation.y = yaw
	camera.rotation.x = -pitch
	camera.position = Vector3(0.0, distance * sin(pitch), distance * cos(pitch))
