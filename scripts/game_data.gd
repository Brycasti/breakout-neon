extends Node
## Datos persistentes del jugador, configuración y control de estado.

const SAVE_PATH: String = "user://breakout_neon.cfg"
const TOTAL_LEVELS: int = 10

var ball_skin: String = "plasma"
var paddle_skin: String = "neon"
var selected_level: int = 1
var endless: bool = false

var total_points: int = 0
var best_score: int = 0
var best_combo: int = 0
var total_bricks: int = 0
var runs_played: int = 0
var cleared: Dictionary = {}

var sfx_on: bool = true
var player_name: String = ""

var session_seed: int = 0
var current_level_seed: int = 0


func _ready() -> void:
	randomize()
	session_seed = randi()
	load_data()


# Gestión de selección y desbloqueo de skins
func ball_entry() -> Dictionary:
	return SkinCatalog.by_id(SkinCatalog.BALLS, ball_skin)


func paddle_entry() -> Dictionary:
	return SkinCatalog.by_id(SkinCatalog.PADDLES, paddle_skin)


func is_unlocked(entry: Dictionary) -> bool:
	return int(entry["price"]) <= total_points


func select_ball(id: String) -> void:
	var entry: Dictionary = SkinCatalog.by_id(SkinCatalog.BALLS, id)
	if not is_unlocked(entry):
		return
	ball_skin = id
	save_data()


func select_paddle(id: String) -> void:
	var entry: Dictionary = SkinCatalog.by_id(SkinCatalog.PADDLES, id)
	if not is_unlocked(entry):
		return
	paddle_skin = id
	save_data()


# Generación y control de semillas para los niveles
func seed_for(level_number: int, endless_seed: int = 0) -> int:
	if endless_seed != 0:
		return endless_seed
	if current_level_seed != 0:
		var s: int = current_level_seed
		current_level_seed = 0
		return s
	return hash("breakout_seed_%d_%d_%d" % [level_number, session_seed, randi()])


func roll_new_level_seed(level_number: int) -> int:
	current_level_seed = hash("breakout_seed_%d_%d_%d" % [level_number, session_seed, randi()])
	return current_level_seed


# Progreso de niveles superados
func is_cleared(level_number: int) -> bool:
	return cleared.has(str(level_number))


func mark_level_cleared(level_number: int) -> void:
	if level_number <= 0:
		return
	cleared[str(level_number)] = true
	save_data()


func cleared_count() -> int:
	return cleared.size()


# Actualización de estadísticas al finalizar partida
func add_results(run_score: int, run_points: int, run_bricks: int, run_combo: int,
		cleared_level: int = 0) -> void:
	total_points += run_points
	total_bricks += run_bricks
	best_score = maxi(best_score, run_score)
	best_combo = maxi(best_combo, run_combo)
	runs_played += 1
	if cleared_level > 0:
		cleared[str(cleared_level)] = true
	save_data()


# Guardado en archivo de configuración local
func save_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("skins", "ball", ball_skin)
	cfg.set_value("skins", "paddle", paddle_skin)
	cfg.set_value("progress", "selected_level", selected_level)
	cfg.set_value("progress", "total_points", total_points)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "best_combo", best_combo)
	cfg.set_value("progress", "total_bricks", total_bricks)
	cfg.set_value("progress", "runs_played", runs_played)
	cfg.set_value("progress", "cleared", cleared)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("jugador", "nombre", player_name)
	cfg.save(SAVE_PATH)


# Carga de datos persistentes
func load_data() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	ball_skin = str(cfg.get_value("skins", "ball", ball_skin))
	paddle_skin = str(cfg.get_value("skins", "paddle", paddle_skin))
	selected_level = int(cfg.get_value("progress", "selected_level", selected_level))
	total_points = int(cfg.get_value("progress", "total_points", total_points))
	best_score = int(cfg.get_value("progress", "best_score", best_score))
	best_combo = int(cfg.get_value("progress", "best_combo", best_combo))
	total_bricks = int(cfg.get_value("progress", "total_bricks", total_bricks))
	runs_played = int(cfg.get_value("progress", "runs_played", runs_played))
	cleared = cfg.get_value("progress", "cleared", {})
	sfx_on = bool(cfg.get_value("audio", "sfx_on", sfx_on))
	player_name = str(cfg.get_value("jugador", "nombre", player_name))
	if not _exists(SkinCatalog.BALLS, ball_skin):
		ball_skin = "plasma"
	if not _exists(SkinCatalog.PADDLES, paddle_skin):
		paddle_skin = "neon"


func _exists(list: Array, id: String) -> bool:
	for entry: Dictionary in list:
		if entry["id"] == id:
			return true
	return false
