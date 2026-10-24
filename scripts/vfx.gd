class_name Vfx
extends Node2D

var camera: Camera2D = null
var _shake_time: float = 0.0
var _shake_duration: float = 0.25
var _shake_amount: float = 0.0


func set_camera(cam: Camera2D) -> void:
	camera = cam


# Actualización y amortiguación del temblor de cámara
func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time -= delta
	if camera == null:
		return
	if _shake_time <= 0.0:
		camera.offset = Vector2.ZERO
		return
	var falloff: float = _shake_time / maxf(_shake_duration, 0.001)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amount * falloff


# Activa la sacudida de pantalla priorizando la de mayor intensidad
func shake(amount: float, duration: float = 0.25) -> void:
	if amount >= _shake_amount or _shake_time <= 0.0:
		_shake_amount = amount
		_shake_duration = duration
	_shake_time = maxf(_shake_time, duration)


# Generación procedural de partículas al romper o golpear bloques
func burst(at: Vector2, color: Color, amount: int = 12, power: float = 240.0) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = at
	particles.z_index = 6
	particles.amount = amount
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 520.0)
	particles.initial_velocity_min = power * 0.3
	particles.initial_velocity_max = power
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	particles.color = color
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	particles.color_ramp = gradient
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


# Creación de etiquetas flotantes animadas con desvanecimiento
func popup(text: String, at: Vector2, color: Color = Color(1, 1, 1), font_size: int = 18) -> void:
	var label: Label = Label.new()
	label.text = text
	label.z_index = 8
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	label.global_position = at + Vector2(-20.0, -14.0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", at + Vector2(-20.0, -60.0), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
