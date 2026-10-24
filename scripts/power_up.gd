class_name PowerUp
extends Area2D

enum Type {
	MULTI_BALL,
	FIRE,
	ACID,
	HEAVY,
	LIGHTNING,
	STICKY,
	GHOST,
	SONIC,
	SLOW,
	EXTRA_LIFE,
	SHIELD
}

@export var fall_speed: float = 180.0
@onready var sprite: Sprite2D = $Sprite2D

var power_type: Type = Type.MULTI_BALL
var base_color: Color = Color.WHITE
var source_brick: String = ""


# Configuración del tipo y color representativo de la cápsula
func setup(t: Type) -> void:
	power_type = t
	match power_type:
		Type.MULTI_BALL:
			sprite.modulate = Color(0.2, 0.9, 1.0)
		Type.FIRE:
			sprite.modulate = Color(1.0, 0.2, 0.0)
		Type.ACID:
			sprite.modulate = Color(0.3, 1.0, 0.1)
		Type.HEAVY:
			sprite.modulate = Color(0.7, 0.7, 0.8)
		Type.LIGHTNING:
			sprite.modulate = Color(1.0, 0.95, 0.2)
		Type.STICKY:
			sprite.modulate = Color(0.9, 0.3, 0.9)
		Type.GHOST:
			sprite.modulate = Color(0.6, 0.8, 1.0)
		Type.SONIC:
			sprite.modulate = Color(0.1, 0.5, 1.0)
		Type.SLOW:
			sprite.modulate = Color(0.4, 0.9, 0.9)
		Type.EXTRA_LIFE:
			sprite.modulate = Color(1.0, 0.2, 0.5)
		Type.SHIELD:
			sprite.modulate = Color(0.0, 0.8, 0.9)
		_:
			sprite.modulate = Color.WHITE


func _ready() -> void:
	body_entered.connect(_on_body_entered)


# Caída vertical y liberación de memoria fuera de pantalla
func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > 750.0:
		queue_free()


# Detección de contacto con la pala y activación del beneficio
func _on_body_entered(body: Node2D) -> void:
	if body is Paddle or body.name == "Paddle":
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("activate_power_up"):
			main_node.activate_power_up(power_type)
		queue_free()
