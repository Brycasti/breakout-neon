class_name Paddle
extends CharacterBody2D

@export var speed: float = 600.0
@export var base_width: float = 120.0
@export var base_height: float = 24.0

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var current_skin_id: String = "neon"
var frozen: bool = false
var base_scale: Vector2 = Vector2.ONE
var _squash_tween: Tween = null
var current_width: float = 120.0


func _ready() -> void:
	base_scale = scale
	current_width = base_width


func _process(delta: float) -> void:
	# Atracción magnética de cápsulas
	if current_skin_id == "ice":
		_magnetize_powerups(delta)


# Movimiento horizontal con límites en los bordes de la pantalla
func _physics_process(_delta: float) -> void:
	if frozen:
		return

	var move_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = move_dir * speed
	move_and_slide()

	var half_w: float = half_width()
	global_position.x = clampf(global_position.x, 32.0 + half_w, 1280.0 - 32.0 - half_w)


func half_width() -> float:
	return current_width * 0.5


# Atrae los power-ups en caída hacia la posición de la pala
func _magnetize_powerups(delta: float) -> void:
	for child in get_parent().get_children():
		if child is PowerUp and is_instance_valid(child):
			var dist: float = global_position.distance_to(child.global_position)
			if dist < 280.0:
				var pull_dir: Vector2 = (global_position - child.global_position).normalized()
				child.global_position += pull_dir * 350.0 * delta


# Asignación de skin, dimensiones y textura
func apply_skin(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	current_skin_id = str(entry.get("id", "neon"))

	var tex: Texture2D = _resolve_texture(entry)
	if tex != null and sprite != null:
		sprite.texture = tex
		sprite.modulate = Color.WHITE

	# Modificación del ancho físico según la skin
	if current_skin_id == "metal":
		current_width = base_width * 1.25
	else:
		current_width = base_width

	_fit_sprite_and_collision(tex)


# Localización y carga de recursos gráficos
func _resolve_texture(entry: Dictionary) -> Texture2D:
	for key in ["texture", "icon", "image", "file", "path"]:
		if entry.has(key):
			var val = entry[key]
			if val is Texture2D:
				return val
			if val is String and val != "":
				if ResourceLoader.exists(val):
					return load(val) as Texture2D
				var alt_path: String = "res://assets/generated/" + val.get_file()
				if ResourceLoader.exists(alt_path):
					return load(alt_path) as Texture2D
				alt_path = "res://assets/PNG/" + val.get_file()
				if ResourceLoader.exists(alt_path):
					return load(alt_path) as Texture2D
	return null


# Ajuste de escala visual y colisionador
func _fit_sprite_and_collision(tex: Texture2D) -> void:
	if shape != null and shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = shape.shape as RectangleShape2D
		rect.size = Vector2(current_width, base_height)

	if tex != null and sprite != null:
		var tw: float = float(tex.get_width())
		var th: float = float(tex.get_height())
		if tw > 0.0 and th > 0.0:
			sprite.scale = Vector2(current_width / tw, base_height / th)


# Efecto de deformación elástica al impactar la bola
func squash() -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	var squash_x: float = 1.30 if current_skin_id == "wood" else 1.15
	var squash_y: float = 0.70 if current_skin_id == "wood" else 0.85
	_squash_tween.tween_property(self, "scale", Vector2(base_scale.x * squash_x, base_scale.y * squash_y), 0.06)
	_squash_tween.tween_property(self, "scale", base_scale, 0.12)
