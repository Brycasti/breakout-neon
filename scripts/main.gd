class_name Main
extends Node2D

enum State { READY, PLAYING, PAUSED, LEVEL_CLEAR, GAME_OVER, WON }

const BRICK_SCENE: PackedScene = preload("res://scenes/brick.tscn")
const POWERUP_SCENE: PackedScene = preload("res://scenes/power_up.tscn")
const BALL_SCENE: PackedScene = preload("res://scenes/ball.tscn")

const COLUMNS: int = 16
const BRICK_W: float = 64.0
const BRICK_H: float = 32.0
const GRID_LEFT: float = (1280.0 - COLUMNS * BRICK_W) * 0.5
const GRID_TOP: float = 96.0
const START_LIVES: int = 3
const COMBO_WINDOW: float = 2.6
const DROP_CHANCE: float = 0.14
const SHIELD_TIME: float = 12.0

# Parámetro de Game Feel: Input Buffering
const INPUT_BUFFER_TIME: float = 0.15
var _launch_buffer_timer: float = 0.0

const BRICK_TYPES: Dictionary = {
	"1": {"hp": 1, "points": 10, "color": Color(0.31, 0.84, 1.0)},
	"2": {"hp": 1, "points": 20, "color": Color(0.42, 0.95, 0.47)},
	"3": {"hp": 2, "points": 30, "color": Color(1.0, 0.88, 0.40)},
	"4": {"hp": 2, "points": 40, "color": Color(1.0, 0.62, 0.26)},
	"5": {"hp": 3, "points": 50, "color": Color(1.0, 0.37, 0.77)},
	"X": {"hp": 1, "points": 60, "color": Color(1.0, 0.10, 0.10)},
	"G": {"hp": 1, "points": 25, "color": Color(1.0, 0.95, 0.10)},
	"M": {"hp": 5, "points": 120, "color": Color(0.70, 0.75, 0.80)},
}

const SPECIAL_BY_KIND: Dictionary = {
	"X": "explosive",
	"G": "gift",
	"M": "steel",
}

@onready var bricks: Node2D = $Bricks
@onready var paddle: Paddle = $Paddle
@onready var ball: Ball = $Ball
@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var pause_label: Label = $HUD/PauseLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var power_label: Label = $HUD/PowerLabel
@onready var shield_label: Label = $HUD/ShieldLabel
@onready var pause_panel: Control = $HUD/PausePanel
@onready var name_panel: Control = $HUD/NamePanel
@onready var name_title: Label = $HUD/NamePanel/Box/Title
@onready var name_points: Label = $HUD/NamePanel/Box/PointsLabel
@onready var name_edit: LineEdit = $HUD/NamePanel/Box/NameEdit
@onready var name_send: Button = $HUD/NamePanel/Box/SendButton
@onready var name_skip: Button = $HUD/NamePanel/Box/SkipButton
@onready var camera: Camera2D = $Camera2D
@onready var vfx: Vfx = $Vfx
@onready var arena: Sprite2D = $Arena

var state: State = State.READY
var score: int = 0
var lives: int = START_LIVES
var level_index: int = 0
var bricks_remaining: int = 0
var level_token: int = 0
var state_before_pause: State = State.READY

var combo: int = 0
var combo_timer: float = 0.0
var combo_best: int = 0
var power_time_left: float = 0.0
var power_name: String = ""
var endless: bool = false
var shield_time_left: float = 0.0
var bricks_broken: int = 0
var run_seed: int = 0

var active_balls: Array[Ball] = []
var shield_active: bool = false
var shield_node: StaticBody2D = null

var _wood_save_available: bool = true
var _run_banked: bool = false

var _mapa_tiempo: float = 0.0
var _mapa_muestra: float = 0.0
var _mapa_abierto: bool = false
var _mapa_prueba: bool = false

var _inicio_partida: int = 0
var _powerups_recogidos: int = 0
var _partida_terminada: bool = false
var _partida_enviada: bool = false
var _mensaje_final: String = ""


func _ready() -> void:
	randomize()
	Leaderboard.iniciar_sesion()
	bricks.add_to_group("bricks")
	endless = GameData.endless
	run_seed = randi() if endless else 0
	GameData.selected_level = clampi(GameData.selected_level, 1, GameData.TOTAL_LEVELS)
	vfx.set_camera(camera)
	active_balls.append(ball)
	ball.ball_lost.connect(_on_ball_lost.bind(ball))
	ball.paddle_hit.connect(_on_paddle_hit)

	paddle.apply_skin(SkinCatalog.by_id(SkinCatalog.PADDLES, GameData.paddle_skin))
	ball.apply_skin(SkinCatalog.by_id(SkinCatalog.BALLS, GameData.ball_skin))

	_style_pause_panel()
	_style_name_panel()
	Leaderboard.partida_guardada.connect(_on_partida_guardada)
	Leaderboard.registrar_evento("skin_equipada",
		"bola: %s · pala: %s" % [GameData.ball_skin, GameData.paddle_skin])
	_inicio_partida = Time.get_ticks_msec()
	_start_level(GameData.selected_level - 1)


func _on_paddle_hit() -> void:
	paddle.squash()
	if combo >= 4:
		Sfx.play("power", -12.0)
	combo = 0
	combo_timer = 0.0
	_update_combo_label()


func _process(delta: float) -> void:
	if state == State.PLAYING and _mapa_abierto:
		_mapa_tiempo += delta
		_mapa_muestra += delta
		if _mapa_muestra >= 0.5:
			_mapa_muestra = 0.0
			var posiciones: Array = []
			for b in active_balls:
				if is_instance_valid(b):
					posiciones.append([snappedf(b.position.x, 0.1), snappedf(b.position.y, 0.1)])
			Leaderboard.registrar_mapa({"clase": "muestra", "nivel": level_index + 1,
				"intento": level_token, "t": snappedf(_mapa_tiempo, 0.01),
				"pala": paddle.position.x, "pala_y": paddle.position.y, "ancho": paddle.current_width,
				"bolas": posiciones.slice(0, 8), "prueba": _mapa_prueba})
	if _launch_buffer_timer > 0.0:
		_launch_buffer_timer -= delta
		if state == State.READY:
			_launch_buffer_timer = 0.0
			_launch_ball()

	if power_time_left > 0.0:
		power_time_left -= delta
		if power_time_left <= 0.0:
			power_name = ""
		_update_power_label()
	if shield_time_left > 0.0:
		shield_time_left -= delta
		if shield_time_left <= 0.0:
			shield_time_left = 0.0
			_remove_shield()
		_update_shield_label()
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0 and combo > 0:
			combo = 0
			_update_combo_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("restart"):
		_restart_game()
	elif event.is_action_pressed("launch"):
		if name_panel.visible:
			return
		if state == State.READY:
			_launch_ball()
		elif state == State.PLAYING:
			_release_stuck_balls()
		elif state == State.GAME_OVER or state == State.WON:
			_go_to_menu()
		elif state == State.LEVEL_CLEAR:
			_launch_buffer_timer = INPUT_BUFFER_TIME

	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			_mapa_prueba = true
			Leaderboard.registrar_evento("habilidad_debug", "teclado", 1, level_index + 1)
		match event.keycode:
			KEY_1: activate_power_up(PowerUp.Type.MULTI_BALL)
			KEY_2: activate_power_up(PowerUp.Type.FIRE)
			KEY_3: activate_power_up(PowerUp.Type.ACID)
			KEY_4: activate_power_up(PowerUp.Type.HEAVY)
			KEY_5: activate_power_up(PowerUp.Type.LIGHTNING)
			KEY_6: activate_power_up(PowerUp.Type.STICKY)
			KEY_7: activate_power_up(PowerUp.Type.GHOST)
			KEY_8: activate_power_up(PowerUp.Type.SONIC)
			KEY_9: activate_power_up(PowerUp.Type.SLOW)
			KEY_0: activate_power_up(PowerUp.Type.SHIELD)


func _release_stuck_balls() -> void:
	var released_any: bool = false
	for b in active_balls:
		if is_instance_valid(b) and b.stuck_to != null:
			b.detach_and_launch()
			released_any = true
	if released_any:
		Sfx.play("launch", -6.0)


func _start_level(index: int) -> void:
	level_index = index
	level_token += 1
	if index == 0:
		_inicio_partida = Time.get_ticks_msec()
		_powerups_recogidos = 0
		_partida_terminada = false
		_partida_enviada = false
	name_panel.visible = false
	name_edit.release_focus()
	_clear_bricks()
	_clear_extra_balls()
	_clear_power_ups()
	_remove_shield()
	combo = 0
	combo_timer = 0.0
	_wood_save_available = true

	if endless:
		power_name = ""
		power_time_left = 0.0

	var level_num: int = index + 1
	var seed_value: int = GameData.seed_for(level_num)
	if endless:
		seed_value = GameData.seed_for(level_num, run_seed + level_num * 977)
	var layout: Array = LevelGen.layout_for(level_num, seed_value)
	_mapa_tiempo = 0.0
	_mapa_muestra = 0.0
	_mapa_abierto = true
	Leaderboard.registrar_evento("nivel_iniciado", LevelGen.theme_name(level_num), 0, level_num)
	Leaderboard.registrar_mapa({"clase": "inicio", "nivel": level_num, "intento": level_token,
		"modo": "infinito" if endless else "normal", "layout": layout,
		"tema": LevelGen.theme_name(level_num), "semilla": seed_value, "prueba": _mapa_prueba})
	arena.self_modulate = LevelGen.theme_color(level_num, seed_value).lerp(Color.WHITE, 0.35)

	for row: int in range(layout.size()):
		var line: String = layout[row]
		for col: int in range(COLUMNS):
			if col >= line.length():
				continue
			var kind: String = line[col]
			if kind == ".":
				continue
			_spawn_brick(kind, col, row)

	state = State.READY
	_reset_ball()
	_show_message("NIVEL %d · %s\n\n¡PULSA ESPACIO PARA LANZAR!" % [level_num, LevelGen.theme_name(level_num)])
	_update_hud()
	_update_combo_label()

	if _launch_buffer_timer > 0.0:
		_launch_buffer_timer = 0.0
		_launch_ball()


func _spawn_brick(kind: String, col: int, row: int) -> void:
	var data: Dictionary = BRICK_TYPES.get(kind, BRICK_TYPES["1"])
	var brick: Brick = BRICK_SCENE.instantiate()
	bricks.add_child(brick)
	brick.global_position = Vector2(
		GRID_LEFT + col * BRICK_W + BRICK_W * 0.5,
		GRID_TOP + row * BRICK_H + BRICK_H * 0.5
	)
	brick.setup(int(data["hp"]), data["color"], int(data["points"]), kind,
		str(SPECIAL_BY_KIND.get(kind, "")))
	brick.destroyed.connect(_on_brick_destroyed)
	brick.damaged.connect(_on_brick_damaged)
	bricks_remaining += 1


func _clear_bricks() -> void:
	for child: Node in bricks.get_children():
		bricks.remove_child(child)
		child.queue_free()
	bricks_remaining = 0


func _advance_level() -> void:
	if state == State.GAME_OVER or state == State.WON:
		return
	for b in active_balls:
		if is_instance_valid(b):
			b.running = false
	var level_num: int = level_index + 1
	_cerrar_mapa("victoria")
	GameData.mark_level_cleared(level_num)
	Leaderboard.registrar_evento("nivel_superado", LevelGen.theme_name(level_num), level_num, level_num)
	if not endless and level_num >= GameData.TOTAL_LEVELS:
		state = State.WON
		Sfx.play("level_clear", -2.0)
		_mensaje_final = "¡HAS COMPLETADO LOS %d NIVELES!\nPUNTUACIÓN FINAL: %d\nMEJOR RACHA: %d" % [GameData.TOTAL_LEVELS, score, combo_best]
		_mostrar_mensaje_final()
		_terminar_partida("¡JUEGO COMPLETADO!", "juego_completado")
		return
	state = State.LEVEL_CLEAR
	Sfx.play("level_clear", -6.0)
	var bonus: int = 100 * level_num
	score += bonus
	_update_hud()
	_show_message("¡NIVEL %d SUPERADO!\n\nBONUS: +%d PUNTOS" % [level_num, bonus])
	var token: int = level_token
	await get_tree().create_timer(1.7).timeout
	if token != level_token or state != State.LEVEL_CLEAR:
		return
	_start_level(level_index + 1)


func _reset_ball() -> void:
	_clear_extra_balls()
	if not is_instance_valid(ball):
		ball = BALL_SCENE.instantiate()
		add_child(ball)
		ball.ball_lost.connect(_on_ball_lost.bind(ball))
		ball.paddle_hit.connect(_on_paddle_hit)

	ball.apply_skin(SkinCatalog.by_id(SkinCatalog.BALLS, GameData.ball_skin))
	ball.reset()
	ball.attach_to(paddle)
	if not active_balls.has(ball):
		active_balls.append(ball)


func _launch_ball() -> void:
	if state != State.READY:
		return
	state = State.PLAYING
	ball.detach_and_launch()
	Sfx.play("launch", -6.0)
	_hide_message()


func _on_ball_lost(lost_ball: Ball) -> void:
	if state != State.PLAYING:
		return

	# Si hay varias bolas (multibola activa), elimina la bola perdida sin dejar rastros
	if active_balls.size() > 1:
		active_balls.erase(lost_ball)
		if is_instance_valid(lost_ball):
			if lost_ball == ball and not active_balls.is_empty():
				ball = active_balls[0]
			lost_ball.queue_free()
		return

	# Pasiva de la pala de madera (solo aplica cuando queda la última bola)
	if paddle.current_skin_id == "wood" and _wood_save_available:
		_wood_save_available = false
		vfx.popup("¡RESCATE DE MADERA!", paddle.global_position + Vector2(0, -60), Color(0.85, 0.65, 0.3), 24)
		Sfx.play("power", -2.0)
		_activate_shield(6.0)
		lost_ball.global_position.y = 690.0
		lost_ball.direction.y = -absf(lost_ball.direction.y)
		lost_ball.running = true
		return

	combo = 0
	combo_timer = 0.0
	_update_combo_label()
	lives -= 1
	Leaderboard.registrar_evento("bola_perdida", "", maxi(lives, 0), level_index + 1)
	Sfx.play("lose", -4.0)

	vfx.shake(9.0, 0.35)

	_update_hud()
	if lives <= 0:
		state = State.GAME_OVER
		paddle.frozen = true
		Sfx.play("game_over", -2.0)
		_bank_run()
		_mensaje_final = "¡JUEGO TERMINADO!\n\nPUNTOS: %d\nMEJOR RACHA: %d\nLADRILLOS ROTOS: %d" % [score, combo_best, bricks_broken]
		_mostrar_mensaje_final()
		_terminar_partida("¡JUEGO TERMINADO!", "juego_terminado")
		return
	state = State.READY
	_reset_ball()
	_show_message("¡PULSA ESPACIO PARA LANZAR!")


func _on_brick_destroyed(points: int, at: Vector2, kind: String) -> void:
	bricks_broken += 1
	bricks_remaining -= 1
	combo += 1

	combo_timer = COMBO_WINDOW * (2.0 if paddle.current_skin_id == "neon" else 1.0)
	combo_best = maxi(combo_best, combo)

	var multiplier: int = _final_multiplier()
	var neon_bonus: float = 1.25 if (paddle.current_skin_id == "neon" and combo >= 3) else 1.0
	var final_points: int = int(points * multiplier * neon_bonus)
	score += final_points

	Sfx.play("brick_break", -12.0)
	vfx.burst(at, brick_color(kind), 10, 210.0)
	vfx.popup("+%d%s" % [final_points, "" if multiplier <= 1 else "   x%d" % multiplier], at,
		Color(1.0, 1.0, 0.95, 0.95))

	if combo >= 3:
		_update_combo_label()
		if combo % 5 == 0:
			vfx.popup("¡COMBO x%d!" % combo, at + Vector2(0.0, -30.0), Color(1.0, 0.9, 0.3), 22)
			Sfx.play("power", -9.0)
			vfx.shake(3.5, 0.15)

	if kind == "X":
		_explode(at)
	elif kind == "G":
		_spawn_power_up(at)
	elif randf() < DROP_CHANCE:
		_spawn_power_up(at)

	if kind in ["X", "G", "M"]:
		Leaderboard.registrar_evento("brick_especial", kind, final_points, level_index + 1)

	_update_hud()
	if bricks_remaining <= 0:
		_advance_level()


func _on_brick_damaged(at: Vector2, kind: String) -> void:
	vfx.burst(at, brick_color(kind), 4, 120.0)


func brick_color(kind: String) -> Color:
	var data: Dictionary = BRICK_TYPES.get(kind, {})
	return data.get("color", Color.WHITE)


func _final_multiplier() -> int:
	var mult: int = 1
	if combo >= 8:
		mult = 4
	elif combo >= 5:
		mult = 3
	elif combo >= 3:
		mult = 2
	if is_instance_valid(ball):
		mult *= maxi(ball.score_multiplier, 1)
	return mult


func _explode(at: Vector2) -> void:
	Sfx.play("explosion", -5.0)
	vfx.burst(at, Color(1.0, 0.55, 0.15), 26, 430.0)
	vfx.shake(12.0, 0.40)

	var radius: float = BRICK_W * 1.9
	for child: Node in bricks.get_children():
		if child is Brick and child.is_alive():
			if child.global_position.distance_to(at) <= radius:
				child.hit()


func _spawn_power_up(at: Vector2) -> void:
	var power_up: PowerUp = POWERUP_SCENE.instantiate()
	add_child(power_up)
	power_up.global_position = at
	power_up.setup(_roll_power_type())


func _roll_power_type() -> PowerUp.Type:
	var roll: float = randf()
	if roll < 0.15:
		return PowerUp.Type.MULTI_BALL
	if roll < 0.24:
		return PowerUp.Type.SHIELD
	if roll < 0.30:
		return PowerUp.Type.EXTRA_LIFE
	var pool: Array[PowerUp.Type] = [
		PowerUp.Type.FIRE, PowerUp.Type.ACID, PowerUp.Type.HEAVY,
		PowerUp.Type.LIGHTNING, PowerUp.Type.STICKY, PowerUp.Type.GHOST,
		PowerUp.Type.SONIC, PowerUp.Type.SLOW,
	]
	return pool.pick_random()


func activate_power_up(type: PowerUp.Type) -> void:
	var names: Dictionary = {
		PowerUp.Type.MULTI_BALL: "¡MULTIBOLA (x3)!",
		PowerUp.Type.FIRE: "¡BOLA DE FUEGO!",
		PowerUp.Type.ACID: "¡BOLA ÁCIDA (2x DAÑO)!",
		PowerUp.Type.HEAVY: "¡BOLA PESADA!",
		PowerUp.Type.LIGHTNING: "¡BOLA RAYO!",
		PowerUp.Type.STICKY: "¡BOLA PEGAJOSA!",
		PowerUp.Type.GHOST: "¡BOLA FANTASMA!",
		PowerUp.Type.SONIC: "¡BOLA SÓNICA (3x PTS)!",
		PowerUp.Type.SLOW: "¡BOLA LENTA!",
		PowerUp.Type.EXTRA_LIFE: "¡+1 VIDA!",
		PowerUp.Type.SHIELD: "¡ESCUDO DEFENSIVO!"
	}

	var label_text: String = names.get(type, "POWER-UP")
	vfx.popup(label_text, paddle.global_position + Vector2(0.0, -44.0), Color(0.65, 1.0, 1.0), 22)
	Sfx.play("power", -4.0)
	_powerups_recogidos += 1
	Leaderboard.registrar_evento("powerup", label_text, 1, level_index + 1)

	match type:
		PowerUp.Type.MULTI_BALL:
			_spawn_multi_ball()
			Leaderboard.registrar_evento("multibola", label_text, 3, level_index + 1)
		PowerUp.Type.EXTRA_LIFE:
			lives += 1
			Sfx.play("extra_life", -3.0)
			_update_hud()
		PowerUp.Type.SHIELD:
			_activate_shield(SHIELD_TIME)
			Leaderboard.registrar_evento("escudo", label_text, int(SHIELD_TIME), level_index + 1)
		_:
			var b_type: Ball.BallType = _power_type_to_ball_type(type)
			power_name = label_text.trim_prefix("¡").trim_suffix("!")
			power_time_left = 8.5
			for b in active_balls:
				if is_instance_valid(b):
					b.set_ball_type(b_type, 8.5)
			_update_power_label()


func _power_type_to_ball_type(p_type: PowerUp.Type) -> Ball.BallType:
	match p_type:
		PowerUp.Type.FIRE: return Ball.BallType.FIRE
		PowerUp.Type.ACID: return Ball.BallType.ACID
		PowerUp.Type.HEAVY: return Ball.BallType.HEAVY
		PowerUp.Type.LIGHTNING: return Ball.BallType.LIGHTNING
		PowerUp.Type.STICKY: return Ball.BallType.STICKY
		PowerUp.Type.GHOST: return Ball.BallType.GHOST
		PowerUp.Type.SONIC: return Ball.BallType.SONIC
		PowerUp.Type.SLOW: return Ball.BallType.SLOW
		_: return Ball.BallType.NORMAL


func _spawn_multi_ball() -> void:
	if active_balls.is_empty():
		return
	var reference_ball: Ball = active_balls[0]
	if reference_ball.stuck_to != null:
		return
	for angle_offset: float in [-0.42, 0.42]:
		var new_ball: Ball = BALL_SCENE.instantiate()
		add_child(new_ball)
		new_ball.global_position = reference_ball.global_position
		new_ball.speed = reference_ball.speed
		new_ball.apply_skin(SkinCatalog.by_id(SkinCatalog.BALLS, GameData.ball_skin))
		new_ball.set_ball_type(reference_ball.current_type, 8.5)
		new_ball.direction = reference_ball.direction.rotated(angle_offset).normalized()
		new_ball.running = true
		new_ball.stuck_to = null
		new_ball.ball_lost.connect(_on_ball_lost.bind(new_ball))
		new_ball.paddle_hit.connect(_on_paddle_hit)
		active_balls.append(new_ball)


func _activate_shield(duration: float = SHIELD_TIME) -> void:
	if shield_active and is_instance_valid(shield_node):
		shield_time_left = duration
		_update_shield_label()
		return
	shield_active = true
	shield_time_left = duration

	shield_node = StaticBody2D.new()
	shield_node.collision_layer = 1
	shield_node.collision_mask = 0

	var col: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(1280.0, 16.0)
	col.shape = rect
	shield_node.add_child(col)

	var visual: ColorRect = ColorRect.new()
	visual.color = Color(0.25, 0.85, 1.0, 0.55)
	visual.size = Vector2(1280.0, 10.0)
	visual.position = Vector2(-640.0, -5.0)
	shield_node.add_child(visual)

	shield_node.global_position = Vector2(640.0, 715.0)
	add_child(shield_node)
	Sfx.play("shield", -4.0)
	_update_shield_label()


func _remove_shield() -> void:
	if is_instance_valid(shield_node):
		shield_node.queue_free()
		shield_node = null
	shield_active = false
	shield_time_left = 0.0
	_update_shield_label()


func _clear_extra_balls() -> void:
	for b in active_balls:
		if b != ball and is_instance_valid(b):
			b.queue_free()
	active_balls.clear()
	if is_instance_valid(ball):
		active_balls.append(ball)


func _clear_power_ups() -> void:
	for child in get_children():
		if child is PowerUp:
			child.queue_free()


func _toggle_pause() -> void:
	if state == State.PLAYING or state == State.READY or state == State.LEVEL_CLEAR:
		state_before_pause = state
		state = State.PAUSED
		for b in active_balls:
			if is_instance_valid(b):
				b.running = false
		paddle.frozen = true
		pause_label.visible = true
		pause_panel.visible = true
		Sfx.play_ui()
		Leaderboard.registrar_evento("pausa", "", 0, level_index + 1)
	elif state == State.PAUSED:
		_resume()


func _restart_game() -> void:
	_cerrar_mapa("reinicio")
	Leaderboard.enviar_eventos()
	if state == State.GAME_OVER or state == State.WON:
		_go_to_menu()
		return
	if state == State.PAUSED:
		pause_label.visible = false
		pause_panel.visible = false
		paddle.frozen = false
	_bank_run()
	Leaderboard.iniciar_sesion()
	_mapa_prueba = false
	_run_banked = false
	score = 0
	lives = START_LIVES
	bricks_broken = 0
	combo_best = 0
	combo = 0
	run_seed = randi() if endless else 0
	_start_level(0)


func _update_hud() -> void:
	score_label.text = "PUNTOS   %d" % score
	lives_label.text = "VIDAS   %d" % maxi(lives, 0)
	if endless:
		level_label.text = "NIVEL %d   ·   INFINITO" % (level_index + 1)
	else:
		level_label.text = "NIVEL   %d / %d" % [level_index + 1, GameData.TOTAL_LEVELS]


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true


func _hide_message() -> void:
	message_label.visible = false


func _update_combo_label() -> void:
	if combo >= 3:
		combo_label.text = "RACHA x%d   ·   BONUS x%d" % [combo, _final_multiplier()]
		combo_label.modulate = Color(1.0, 0.92, 0.45, 1.0)
	else:
		combo_label.text = ""


func _update_power_label() -> void:
	if power_time_left > 0.0:
		power_label.text = "%s    %.1fs" % [power_name, maxf(power_time_left, 0.0)]
	else:
		power_label.text = ""


func _update_shield_label() -> void:
	if shield_time_left > 0.0:
		shield_label.text = "ESCUDO ACTIVO    %.1fs" % maxf(shield_time_left, 0.0)
	else:
		shield_label.text = ""


func _style_pause_panel() -> void:
	pause_panel.visible = false
	var resume_button: Button = pause_panel.get_node_or_null("Box/ResumeButton") as Button
	var menu_button: Button = pause_panel.get_node_or_null("Box/MenuButton") as Button
	if resume_button != null:
		resume_button.pressed.connect(_resume)
	if menu_button != null:
		menu_button.pressed.connect(_go_to_menu)


func _resume() -> void:
	if state != State.PAUSED:
		return
	state = state_before_pause
	for b in active_balls:
		if is_instance_valid(b) and b.stuck_to == null:
			b.running = true
	paddle.frozen = false
	pause_label.visible = false
	pause_panel.visible = false
	Sfx.play_ui()


func _go_to_menu() -> void:
	_cerrar_mapa("salida")
	_bank_run()
	_enviar_partida_si_pendiente()
	Leaderboard.enviar_eventos()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _bank_run() -> void:
	if _run_banked:
		return
	_run_banked = true
	GameData.add_results(score, score, bricks_broken, combo_best)


func _style_name_panel() -> void:
	name_panel.visible = false
	name_send.pressed.connect(_on_nombre_guardado)
	name_skip.pressed.connect(_on_nombre_omitido)
	name_edit.text_submitted.connect(_on_nombre_escrito)


func _terminar_partida(titulo: String, evento: String) -> void:
	_cerrar_mapa("derrota" if evento == "juego_terminado" else "victoria")
	_partida_terminada = true
	Leaderboard.registrar_evento(evento, "", score, level_index + 1)
	Leaderboard.enviar_eventos()
	_preguntar_nombre(titulo)


func _preguntar_nombre(titulo: String) -> void:
	name_title.text = titulo
	name_points.text = "PUNTOS: %d" % score
	name_edit.text = GameData.player_name
	name_panel.visible = true
	name_edit.grab_focus()
	name_edit.select_all()


func _on_nombre_escrito(_texto: String) -> void:
	_on_nombre_guardado()


func _on_nombre_guardado() -> void:
	var nombre: String = name_edit.text.strip_edges()
	if nombre == "":
		nombre = "Anónimo"
	GameData.player_name = nombre
	GameData.save_data()
	name_panel.visible = false
	name_edit.release_focus()
	_enviar_partida(nombre)


func _on_nombre_omitido() -> void:
	name_panel.visible = false
	name_edit.release_focus()
	_enviar_partida("Anónimo")


func _enviar_partida(nombre: String) -> void:
	if _partida_enviada:
		return
	_partida_enviada = true
	Leaderboard.enviar_partida({
		"jugador": nombre,
		"puntos": score,
		"nivel": level_index + 1,
		"racha": combo_best,
		"ladrillos": bricks_broken,
		"powerups": _powerups_recogidos,
		"vidas": maxi(lives, 0),
		"modo": "infinito" if endless else "normal",
		"duracion_s": float(Time.get_ticks_msec() - _inicio_partida) / 1000.0,
		"skin_bola": GameData.ball_skin,
		"skin_pala": GameData.paddle_skin,
	})


func _enviar_partida_si_pendiente() -> void:
	if _partida_terminada and not _partida_enviada:
		_enviar_partida(Leaderboard.nombre_jugador())


func _mostrar_mensaje_final(extra: String = "") -> void:
	var texto: String = _mensaje_final
	if extra != "":
		texto += "\n\n" + extra
	_show_message(texto + "\n\nENTER PARA VOLVER AL MENÚ")


func _on_partida_guardada(ok: bool, puesto: int, mensaje: String) -> void:
	if state != State.GAME_OVER and state != State.WON:
		return
	if ok and puesto > 0:
		Sfx.play("power", -4.0)
		_mostrar_mensaje_final("¡PUESTO #%d EN LA CLASIFICACIÓN!" % puesto)
	else:
		_mostrar_mensaje_final("(%s)" % mensaje)


func _cerrar_mapa(resultado: String) -> void:
	if not _mapa_abierto:
		return
	_mapa_abierto = false
	Leaderboard.registrar_mapa({"clase": "fin", "nivel": level_index + 1,
		"intento": level_token, "t": snappedf(_mapa_tiempo, 0.01),
		"resultado": resultado, "prueba": _mapa_prueba})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cerrar_mapa("salida")
		Leaderboard.enviar_eventos()
