class_name Ball
extends CharacterBody2D

signal ball_lost
signal paddle_hit

enum BallType {
	NORMAL,
	FIRE,
	ACID,
	HEAVY,
	LIGHTNING,
	STICKY,
	GHOST,
	SONIC,
	SLOW
}

const VISUAL_SIZE: float = 24.0
const MAX_BOUNCES_PER_FRAME: int = 6
const STICK_OFFSET: Vector2 = Vector2(0.0, -18.0)

# Parámetros de Game Feel: Coyote Time
const COYOTE_MARGIN_Y: float = 16.0
const COYOTE_MARGIN_X: float = 18.0

@export var start_speed: float = 400.0
@export var max_speed: float = 850.0
@export var speed_step: float = 8.0
@export var paddle_curve_degrees: float = 58.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.UP
var speed: float = 400.0
var running: bool = false
var stuck_to: Paddle = null
var current_type: BallType = BallType.NORMAL
var type_timer: float = 0.0
var score_multiplier: int = 1
var base_scale: Vector2 = Vector2.ONE
var trail_line: Line2D = null
var trail_points: Array[Vector2] = []
var dry_timer: float = 0.0

var current_skin_id: String = "plasma"
var _anim_time: float = 0.0
var _sticky_cooldown: float = 0.0
var _bomb_counter: int = 3
var _bomb_label: Label = null
var _laser_cooldown: float = 0.0

var _heat_charge_timer: float = 0.0
var _steel_boost: bool = false


func _ready() -> void:
	base_scale = scale
	z_index = 10
	_build_trail()
	_build_bomb_badge()
	apply_skin(SkinCatalog.by_id(SkinCatalog.BALLS, GameData.ball_skin))


func _build_bomb_badge() -> void:
	if _bomb_label != null:
		return
	_bomb_label = Label.new()
	_bomb_label.name = "BombBadge"
	_bomb_label.text = ""
	_bomb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bomb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bomb_label.position = Vector2(-20.0, -32.0)
	_bomb_label.size = Vector2(40.0, 20.0)
	_bomb_label.add_theme_font_size_override("font_size", 14)
	_bomb_label.modulate = Color(1.0, 0.25, 0.25)
	add_child(_bomb_label)


func _process(delta: float) -> void:
	_anim_time += delta
	if _laser_cooldown > 0.0:
		_laser_cooldown -= delta
	if _heat_charge_timer > 0.0:
		_heat_charge_timer -= delta
		if _heat_charge_timer <= 0.0 and sprite != null:
			sprite.modulate = Color.WHITE
	_animate_skin_proc(delta)


func _animate_skin_proc(_delta: float) -> void:
	match current_skin_id:
		"plasma":
			var pulse: float = 1.0 + sin(_anim_time * 9.0) * 0.12
			scale = base_scale * pulse
		"gem":
			if sprite != null:
				sprite.rotation += 4.5 * _delta
		"star":
			var star_pulse: float = 1.0 + absf(sin(_anim_time * 8.0)) * 0.18
			if sprite != null and sprite.texture != null:
				var tex_w: float = maxf(float(sprite.texture.get_width()), 1.0)
				sprite.scale = Vector2(star_pulse * 1.1, 0.9 / star_pulse) * (VISUAL_SIZE / tex_w)
		"eye":
			if sprite != null and direction.length_squared() > 0.01:
				sprite.rotation = lerp_angle(sprite.rotation, direction.angle() + PI * 0.5, 0.25)
		"meteor":
			if sprite != null:
				sprite.offset = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
		"bomb":
			var speed_factor: float = (4.0 - float(_bomb_counter)) * 4.0
			var b_pulse: float = 1.0 + absf(sin(_anim_time * speed_factor)) * 0.18
			scale = base_scale * b_pulse


func apply_skin(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	current_skin_id = str(entry.get("id", "plasma"))

	var tex: Texture2D = _resolve_texture(entry)
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D

	if tex != null and sprite != null:
		sprite.texture = tex
		sprite.modulate = Color.WHITE
		sprite.self_modulate = Color.WHITE
		sprite.visible = true
		_apply_skin_size(tex)

	if trail_line != null:
		var trail_col: Color = entry.get("trail_color", Color(0.3, 0.8, 1.0, 0.6))
		trail_line.default_color = trail_col
		trail_line.width = 16.0 if current_skin_id == "star" else 10.0

	_bomb_counter = 3
	_update_bomb_badge()

	match current_skin_id:
		"star":
			speed = start_speed * 1.15
		"gem":
			score_multiplier = 2
		_:
			speed = start_speed
			score_multiplier = 1


func _update_bomb_badge() -> void:
	if _bomb_label == null:
		return
	if current_skin_id == "bomb" and running and visible:
		_bomb_label.text = str(_bomb_counter)
		_bomb_label.visible = true
	else:
		_bomb_label.text = ""
		_bomb_label.visible = false


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


func _apply_skin_size(tex: Texture2D) -> void:
	var w: float = float(tex.get_width())
	var h: float = float(tex.get_height())
	if w <= 0.0 or h <= 0.0 or sprite == null:
		return
	var factor: float = VISUAL_SIZE / maxf(w, h)
	sprite.scale = Vector2(factor, factor)


func _physics_process(delta: float) -> void:
	if _sticky_cooldown > 0.0:
		_sticky_cooldown -= delta

	_tick_type_timer(delta)
	_update_trail()

	if stuck_to != null and is_instance_valid(stuck_to):
		global_position = stuck_to.global_position + STICK_OFFSET
		return

	if not running:
		return

	_tick_dry(delta)
	_move(delta)

	# Coyote Time: rescate en el rango vertical exacto de la pala
	if direction.y > 0.0 and global_position.y >= 640.0 and global_position.y <= 668.0:
		_check_coyote_rescue()

	# Salida total de la pantalla con ocultación inmediata
	if global_position.y > 745.0:
		running = false
		visible = false
		if _bomb_label != null:
			_bomb_label.visible = false
		if trail_line != null:
			trail_line.clear_points()
			trail_line.visible = false
		ball_lost.emit()


func _check_coyote_rescue() -> void:
	var paddle_node: Paddle = get_tree().current_scene.get_node_or_null("Paddle") as Paddle
	if paddle_node == null or not is_instance_valid(paddle_node) or paddle_node.frozen:
		return

	var half_w: float = paddle_node.half_width() + COYOTE_MARGIN_X
	var dx: float = absf(global_position.x - paddle_node.global_position.x)
	var dy: float = global_position.y - paddle_node.global_position.y

	if dx <= half_w and dy >= -16.0 and dy <= 8.0:
		global_position.y = paddle_node.global_position.y - 16.0
		_handle_paddle_collision(paddle_node, Vector2.UP)
		_spawn_screen_text("¡RESCATE LÍMITE!", paddle_node.global_position + Vector2(0, -45), Color(0.3, 1.0, 0.6))


func _tick_type_timer(delta: float) -> void:
	if type_timer <= 0.0:
		return
	type_timer -= delta
	if type_timer <= 0.0:
		set_ball_type(BallType.NORMAL)


func _tick_dry(delta: float) -> void:
	dry_timer += delta
	if dry_timer > 7.0:
		dry_timer = 0.0
		direction = direction.rotated(randf_range(-0.35, 0.35)).normalized()
		_avoid_flat()


func _move(delta: float) -> void:
	var motion: Vector2 = direction * speed * delta
	var bounces: int = 0

	while motion.length() > 0.001 and bounces < MAX_BOUNCES_PER_FRAME:
		bounces += 1
		var col: KinematicCollision2D = move_and_collide(motion)
		if col == null:
			break

		var collider: Object = col.get_collider()
		var normal: Vector2 = col.get_normal()
		dry_timer = 0.0

		if (current_type == BallType.FIRE or current_type == BallType.GHOST) and collider is Brick:
			var pierced: Brick = collider
			_apply_piercing_damage(pierced)
			if pierced.is_alive():
				add_collision_exception_with(pierced)
			motion = col.get_remainder()
			continue

		if collider is Paddle:
			if current_type == BallType.STICKY and _sticky_cooldown <= 0.0:
				attach_to(collider)
				paddle_hit.emit()
				return
			_handle_paddle_collision(collider, normal)
			motion = direction * col.get_remainder().length()
			continue

		if collider is Brick:
			_handle_brick_collision(collider)

		direction = direction.bounce(normal).normalized()
		_avoid_flat()
		motion = col.get_remainder().bounce(normal)


func _apply_piercing_damage(brick: Brick) -> void:
	if not brick.is_alive():
		return
	if current_type == BallType.FIRE:
		while brick.is_alive():
			brick.hit()
	else:
		brick.hit()


func _handle_paddle_collision(paddle_ref: Paddle, _normal: Vector2) -> void:
	if paddle_ref.current_skin_id == "wood":
		if speed > 500.0:
			speed = maxf(start_speed, speed * 0.85)
			_spawn_screen_text("¡AMORTIGUACIÓN!", paddle_ref.global_position + Vector2(0, -35), Color(0.8, 0.6, 0.3))
	elif paddle_ref.current_skin_id == "metal":
		_steel_boost = true
		speed = minf(speed + 35.0, max_speed)
		_spawn_screen_text("¡GOLPE DE ACERO!", paddle_ref.global_position + Vector2(0, -35), Color(0.7, 0.85, 1.0))
		Sfx.play("steel", -4.0)
	elif paddle_ref.current_skin_id in ["lava", "magma"]:
		_heat_charge_timer = 4.0
		if sprite != null:
			sprite.modulate = Color(1.0, 0.45, 0.15)
		_spawn_screen_text("¡CARGA ÍGNEA!", paddle_ref.global_position + Vector2(0, -35), Color(1.0, 0.5, 0.1))
	elif paddle_ref.current_skin_id == "neon":
		_spawn_screen_text("¡SOBRECARGA NEÓN!", paddle_ref.global_position + Vector2(0, -35), Color(0.2, 0.9, 1.0))
		speed = minf(speed + speed_step, max_speed)
	else:
		speed = minf(speed + speed_step, max_speed)

	direction = _paddle_bounce(paddle_ref)
	_avoid_flat()
	paddle_hit.emit()
	Sfx.play("paddle_hit", -4.0)


func _handle_brick_collision(brick: Brick) -> void:
	if _heat_charge_timer > 0.0:
		brick.ignite()

	if _steel_boost:
		_steel_boost = false
		brick.hit()

	if current_skin_id == "star":
		_trigger_star_barrage(brick.global_position)
	elif current_skin_id == "eye":
		_trigger_eye_vertical_laser(brick.global_position)
	elif current_skin_id == "meteor":
		_apply_lava_burn_area(brick.global_position)
	elif current_skin_id == "bomb":
		_bomb_counter -= 1
		if _bomb_counter <= 0:
			_bomb_counter = 3
			_trigger_mega_bomb_explosion(brick.global_position)
		else:
			Sfx.play("click", -6.0, 1.8)
		_update_bomb_badge()
	elif current_skin_id == "gem":
		_trigger_gem_shatter()
	elif current_skin_id == "plasma":
		_trigger_plasma_chain(brick.global_position)

	match current_type:
		BallType.ACID:
			brick.hit()
			if brick.is_alive():
				brick.hit()
		BallType.HEAVY:
			while brick.is_alive():
				brick.hit()
		BallType.LIGHTNING:
			brick.hit()
			_chain_lightning()
		_:
			brick.hit()


func _trigger_star_barrage(hit_pos: Vector2) -> void:
	Sfx.play("power", -6.0, 1.5)
	_spawn_screen_text("¡LLUVIA ESTELAR!", hit_pos + Vector2(0, -20), Color(1.0, 0.95, 0.2))

	var vfx_node = get_tree().current_scene.get_node_or_null("Vfx")
	if vfx_node != null and vfx_node.has_method("burst"):
		vfx_node.burst(hit_pos, Color(1.0, 0.9, 0.2), 16, 250.0)

	var bricks_node: Node = get_tree().get_first_node_in_group("bricks")
	if bricks_node == null:
		return

	var hit_count: int = 0
	for child in bricks_node.get_children():
		if child is Brick and child.is_alive():
			var dy: float = hit_pos.y - child.global_position.y
			var dx: float = absf(hit_pos.x - child.global_position.x)
			if dy > 10.0 and dy < 160.0 and dx < 110.0:
				child.hit()
				hit_count += 1
				if hit_count >= 3:
					break


func _trigger_eye_vertical_laser(hit_pos: Vector2) -> void:
	if _laser_cooldown > 0.0:
		return
	_laser_cooldown = 0.2

	Sfx.play("laser", -3.0, 1.2)
	_spawn_screen_text("¡MIRADA LÁSER!", hit_pos + Vector2(0, -25), Color(0.3, 1.0, 0.7))

	var line: Line2D = Line2D.new()
	line.top_level = true
	line.z_index = 12
	line.width = 12.0
	line.default_color = Color(0.2, 1.0, 0.6, 0.9)
	line.add_point(Vector2(hit_pos.x, 720.0))
	line.add_point(Vector2(hit_pos.x, 60.0))
	get_tree().current_scene.add_child(line)

	var tw: Tween = create_tween()
	tw.tween_property(line, "width", 0.0, 0.22)
	tw.chain().tween_callback(line.queue_free)

	var bricks_node: Node = get_tree().get_first_node_in_group("bricks")
	if bricks_node == null:
		return

	for child in bricks_node.get_children():
		if child is Brick and child.is_alive():
			if absf(child.global_position.x - hit_pos.x) <= 34.0:
				child.hit()


func _trigger_gem_shatter() -> void:
	score_multiplier = 2
	var bricks_node: Node = get_tree().get_first_node_in_group("bricks")
	if bricks_node == null:
		return
	var targets: Array[Brick] = []
	for child in bricks_node.get_children():
		if child is Brick and child.is_alive():
			targets.append(child)
	if not targets.is_empty():
		var extra: Brick = targets.pick_random()
		extra.hit()
		Sfx.play("laser", -7.0, 1.4)
		_spawn_screen_text("¡CRISTAL!", extra.global_position, Color(0.4, 0.9, 1.0))


func _trigger_plasma_chain(epicenter: Vector2) -> void:
	var bricks_node: Node = get_tree().get_first_node_in_group("bricks")
	if bricks_node == null:
		return
	var hit_count: int = 0
	for child in bricks_node.get_children():
		if child is Brick and child.is_alive():
			if child.global_position.distance_to(epicenter) <= 90.0:
				child.hit()
				hit_count += 1
				if hit_count >= 2:
					break
	if hit_count > 0:
		Sfx.play("laser", -10.0, 1.6)


func _trigger_mega_bomb_explosion(epicenter: Vector2) -> void:
	Sfx.play("explosion", -2.0)
	_spawn_screen_text("¡BOOM!", epicenter, Color(1.0, 0.2, 0.1))

	var vfx_node = get_tree().current_scene.get_node_or_null("Vfx")
	if vfx_node != null and vfx_node.has_method("shake"):
		vfx_node.shake(14.0, 0.45)

	var radius: float = 130.0
	var bricks_node: Node = get_tree().get_first_node_in_group("bricks")
	if bricks_node == null:
		return
	for child in bricks_node.get_children():
		if child is Brick and child.is_alive():
			if child.global_position.distance_to(epicenter) <= radius:
				child.hit()


func _apply_lava_burn_area(epicenter: Vector2) -> void:
	var radius: float = 72.0
	var bricks_node: Node = get_tree().get_first_node_in_group("bricks")
	if bricks_node == null:
		return
	for child in bricks_node.get_children():
		if child is Brick and child.is_alive():
			if child.global_position.distance_to(epicenter) <= radius:
				child.ignite()


func _chain_lightning() -> void:
	var bricks_node: Node = get_tree().get_first_node_in_group("bricks")
	if bricks_node == null:
		return
	var alive_bricks: Array[Brick] = []
	for child in bricks_node.get_children():
		if child is Brick and child.is_alive():
			alive_bricks.append(child)
	if alive_bricks.is_empty():
		return
	var target: Brick = alive_bricks.pick_random()
	target.hit()
	Sfx.play("laser", -6.0)


func _paddle_bounce(paddle_ref: Paddle) -> Vector2:
	var half_w: float = paddle_ref.half_width()
	var offset: float = (global_position.x - paddle_ref.global_position.x) / maxf(half_w, 1.0)
	offset = clampf(offset, -1.0, 1.0)
	var max_rad: float = deg_to_rad(paddle_curve_degrees)
	var angle: float = offset * max_rad
	return Vector2(sin(angle), -cos(angle)).normalized()


func _avoid_flat() -> void:
	if absf(direction.y) < 0.28:
		direction.y = -0.28 if direction.y <= 0.0 else 0.28
		direction = direction.normalized()
	if absf(direction.x) < 0.22:
		direction.x = 0.22 if direction.x >= 0.0 else -0.22
		direction = direction.normalized()


func reset() -> void:
	running = false
	stuck_to = null
	visible = true
	_sticky_cooldown = 0.0
	_heat_charge_timer = 0.0
	_steel_boost = false
	_bomb_counter = 3
	_update_bomb_badge()
	speed = start_speed * (1.15 if current_skin_id == "star" else 1.0)
	direction = Vector2(0.0, -1.0)
	set_ball_type(BallType.NORMAL)
	trail_points.clear()
	if trail_line != null:
		trail_line.clear_points()
		trail_line.visible = true
	if sprite != null:
		sprite.modulate = Color.WHITE


func attach_to(paddle_ref: Paddle) -> void:
	stuck_to = paddle_ref
	running = false
	visible = true
	global_position = paddle_ref.global_position + STICK_OFFSET
	_update_bomb_badge()


func detach_and_launch() -> void:
	stuck_to = null
	running = true
	visible = true
	_sticky_cooldown = 0.35
	direction = Vector2(randf_range(-0.4, 0.4), -1.0).normalized()
	global_position.y -= 10.0
	_update_bomb_badge()


func set_ball_type(type: BallType, duration: float = 8.5) -> void:
	current_type = type
	type_timer = duration if type != BallType.NORMAL else 0.0
	scale = base_scale
	score_multiplier = 2 if current_skin_id == "gem" else 1

	for body: PhysicsBody2D in get_collision_exceptions():
		if not is_instance_valid(body):
			continue
		remove_collision_exception_with(body)

	match current_type:
		BallType.HEAVY:
			speed = start_speed * 0.8
			scale = base_scale * 1.5
		BallType.SLOW:
			speed = start_speed * 0.62
		BallType.SONIC:
			speed = start_speed * 1.55
			score_multiplier = 3
		BallType.NORMAL:
			speed = start_speed * (1.15 if current_skin_id == "star" else 1.0)


func _build_trail() -> void:
	trail_line = Line2D.new()
	trail_line.top_level = true
	trail_line.z_index = 8
	trail_line.width = 10.0
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.6)])
	trail_line.gradient = grad
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(1.0, 1.0))
	trail_line.width_curve = curve
	add_child(trail_line)


func _update_trail() -> void:
	if trail_line == null:
		return
	trail_points.push_front(global_position)
	if trail_points.size() > 18:
		trail_points.pop_back()
	trail_line.clear_points()
	for pt in trail_points:
		trail_line.add_point(pt)


func _spawn_screen_text(text: String, at: Vector2, color: Color) -> void:
	var vfx_node = get_tree().current_scene.get_node_or_null("Vfx")
	if vfx_node != null and vfx_node.has_method("popup"):
		vfx_node.popup(text, at, color, 20)
