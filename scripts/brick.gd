class_name Brick
extends StaticBody2D

signal destroyed(points: int, at: Vector2, kind: String)
signal damaged(at: Vector2, kind: String)

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var hp: int = 1
var max_hp: int = 1
var points: int = 10
var kind: String = "1"
var special: String = ""

# Control de daño continuo por quemadura
var is_burning: bool = false
var _burn_tween: Tween = null
var _burn_timer: float = 0.0
const BURN_TICK_RATE: float = 1.40


# Inicialización de atributos y asignación de aspectos especiales
func setup(p_hp: int, p_color: Color, p_points: int, p_kind: String, p_special: String = "") -> void:
	hp = p_hp
	max_hp = p_hp
	points = p_points
	kind = p_kind
	special = p_special

	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D

	match special:
		"explosive":
			_apply_special_visual(["bomb", "tnt", "explosive", "red_hit", "danger"], Color(1.0, 0.15, 0.15), "💣")
		"gift":
			_apply_special_visual(["gift", "star", "lucky", "power", "yellow"], Color(1.0, 0.90, 0.15), "★")
		"steel":
			_apply_special_visual(["metal", "iron", "steel", "grey", "silver", "block_solid"], Color(0.75, 0.80, 0.85), "⚙")
		_:
			modulate = p_color


# Configuración de textura para bloques especiales con fallback visual
func _apply_special_visual(keywords: Array, fallback_color: Color, fallback_symbol: String) -> void:
	var found_tex: Texture2D = _find_texture_by_keywords(keywords)

	if found_tex != null and sprite != null:
		sprite.texture = found_tex
		modulate = Color.WHITE
		var tw: float = float(found_tex.get_width())
		var th: float = float(found_tex.get_height())
		if tw > 0.0 and th > 0.0:
			sprite.scale = Vector2(64.0 / tw, 32.0 / th)
	else:
		modulate = fallback_color
		_create_visual_badge(fallback_symbol)


# Búsqueda de recursos por coincidencia de nombre
func _find_texture_by_keywords(keywords: Array) -> Texture2D:
	var folders: Array[String] = ["res://assets/generated/", "res://assets/PNG/"]
	for folder in folders:
		var dir := DirAccess.open(folder)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".png"):
					var lower_name: String = file_name.to_lower()
					for kw: String in keywords:
						if lower_name.contains(kw):
							dir.list_dir_end()
							return load(folder + file_name) as Texture2D
				file_name = dir.get_next()
			dir.list_dir_end()
	return null


# Indicador sobre el bloque si no existe sprite específico
func _create_visual_badge(symbol: String) -> void:
	var existing = get_node_or_null("BadgeLabel")
	if existing != null:
		return
	var label: Label = Label.new()
	label.name = "BadgeLabel"
	label.text = symbol
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(64.0, 32.0)
	label.position = Vector2(-32.0, -16.0)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(1.0, 1.0, 1.0, 0.9)
	add_child(label)


func is_alive() -> bool:
	return hp > 0


func _process(delta: float) -> void:
	if not is_burning or not is_alive():
		return

	_burn_timer -= delta
	if _burn_timer <= 0.0:
		_burn_timer = BURN_TICK_RATE
		_apply_burn_tick()


# Inicia el estado de fuego y la animación de parpadeo térmico
func ignite() -> void:
	if not is_alive() or is_burning:
		return
	is_burning = true
	_burn_timer = BURN_TICK_RATE

	if _burn_tween and _burn_tween.is_valid():
		_burn_tween.kill()
	_burn_tween = create_tween().set_loops()
	_burn_tween.tween_property(self, "modulate", Color(1.0, 0.25, 0.05), 0.35)
	_burn_tween.tween_property(self, "modulate", Color(1.0, 0.75, 0.15), 0.35)


# Aplica el daño por pulso de quemadura
func _apply_burn_tick() -> void:
	if not is_alive():
		return
	damaged.emit(global_position, kind)
	hp -= 1

	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2(1.12, 0.88), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.08)

	if hp <= 0:
		_turn_to_ash()


# Desaparición gradual por combustión
func _turn_to_ash() -> void:
	if _burn_tween and _burn_tween.is_valid():
		_burn_tween.kill()
	shape.set_deferred("disabled", true)
	destroyed.emit(points, global_position, kind)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate", Color(0.15, 0.15, 0.15, 0.0), 0.35)
	tween.chain().tween_callback(queue_free)


# Procesa el impacto de la pelota y resta vida
func hit() -> void:
	if not is_alive():
		return

	if special == "steel":
		damaged.emit(global_position, kind)
		hp -= 1
		if hp <= 0:
			_destroy()
		else:
			_punch_effect()
		return

	hp -= 1
	if hp <= 0:
		_destroy()
	else:
		damaged.emit(global_position, kind)
		_punch_effect()


# Animación de impacto elástico
func _punch_effect() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)


# Destrucción del ladrillo y notificación de puntos
func _destroy() -> void:
	if _burn_tween and _burn_tween.is_valid():
		_burn_tween.kill()
	shape.set_deferred("disabled", true)
	destroyed.emit(points, global_position, kind)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.14)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(queue_free)
