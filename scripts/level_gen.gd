class_name LevelGen
extends RefCounted

@warning_ignore_start("integer_division")

const COLUMNS: int = 16
const MAX_ROWS: int = 9
const MIN_BRICKS: int = 28

const CHAR_BY_CODE: Array[String] = [".", "1", "2", "3", "4", "5", "X", "G", "M"]
const PREVIEW_COLORS: Array[Color] = [
	Color(0.08, 0.08, 0.12, 0.3),
	Color(0.31, 0.84, 1.0),
	Color(0.42, 0.95, 0.47),
	Color(1.0, 0.88, 0.40),
	Color(1.0, 0.62, 0.26),
	Color(1.0, 0.37, 0.77),
	Color(1.0, 0.15, 0.10),
	Color(1.0, 0.95, 0.10),
	Color(0.70, 0.75, 0.80)
]


# Calcula la cantidad de filas en función del nivel
static func row_count_for(level_number: int) -> int:
	return clampi(4 + int(level_number * 0.45), 5, MAX_ROWS)


# Genera la matriz de caracteres para la distribución del nivel
static func layout_for(level_number: int, seed_value: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	var rows: int = row_count_for(level_number)
	var grid: Array = []
	for r: int in range(rows):
		var row_chars: Array = []
		for c: int in range(COLUMNS):
			row_chars.append(".")
		grid.append(row_chars)

	# Selección aleatoria de plantilla geométrica
	var pattern: int = rng.randi_range(0, 8)
	match pattern:
		0: _pattern_arch(grid, rows, rng)
		1: _pattern_checker(grid, rows, rng)
		2: _pattern_pyramid(grid, rows, rng)
		3: _pattern_fortress(grid, rows, rng)
		4: _pattern_diamond(grid, rows, rng)
		5: _pattern_stripes(grid, rows, rng)
		6: _pattern_noise(grid, rows, rng)
		7: _pattern_zigzag(grid, rows, rng)
		_: _pattern_towers(grid, rows, rng)

	_ensure_density(grid, rows, rng)
	_assign_kinds(grid, rows, level_number, rng)
	_place_specials(grid, rows, level_number, rng)

	var result: Array = []
	for r: int in range(rows):
		var line: String = ""
		for c: int in range(COLUMNS):
			line += grid[r][c]
		result.append(line)
	return result


# Coloca una celda de forma simétrica en el tablero
static func put_cell(grid: Array, r: int, c: int, val: String) -> void:
	if r >= 0 and r < grid.size() and c >= 0 and c < COLUMNS:
		grid[r][c] = val
		grid[r][COLUMNS - 1 - c] = val


# Asigna el tipo y resistencia de los bloques según la progresión del nivel
static func _assign_kinds(grid: Array, rows: int, level_number: int, rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS):
			if grid[r][c] == ".":
				continue

			if level_number == 1:
				grid[r][c] = "1" if rng.randf() < 0.55 else "2"
				continue

			if level_number == 2:
				var roll_l2: float = rng.randf()
				if r < 2 and roll_l2 < 0.40:
					grid[r][c] = "3"
				else:
					grid[r][c] = "1" if roll_l2 < 0.70 else "2"
				continue

			var depth_ratio: float = float(rows - 1 - r) / maxf(float(rows - 1), 1.0)
			var roll: float = rng.randf() + depth_ratio * 0.30 + float(level_number) * 0.04

			if level_number <= 4:
				if roll < 0.35:
					grid[r][c] = "1"
				elif roll < 0.65:
					grid[r][c] = "2"
				elif roll < 0.90:
					grid[r][c] = "3"
				else:
					grid[r][c] = "4"
			else:
				if roll < 0.15:
					grid[r][c] = "1"
				elif roll < 0.35:
					grid[r][c] = "2"
				elif roll < 0.60:
					grid[r][c] = "3"
				elif roll < 0.85:
					grid[r][c] = "4"
				else:
					grid[r][c] = "5"


# Distribuye bloques especiales según el nivel
static func _place_specials(grid: Array, rows: int, level_number: int, rng: RandomNumberGenerator) -> void:
	if level_number < 3:
		return

	var occupied_cells: Array[Vector2i] = []
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if grid[r][c] != ".":
				occupied_cells.append(Vector2i(c, r))

	if occupied_cells.is_empty():
		return

	for i: int in range(occupied_cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp = occupied_cells[i]
		occupied_cells[i] = occupied_cells[j]
		occupied_cells[j] = temp

	# Bloques de regalo
	if level_number >= 3 and not occupied_cells.is_empty():
		var gift_count: int = clampi(int((level_number - 1) * 0.25), 1, 3)
		for i: int in range(mini(gift_count, occupied_cells.size())):
			var cell: Vector2i = occupied_cells.pop_back()
			put_cell(grid, cell.y, cell.x, "G")

	# Bloques bomba
	if level_number >= 4 and not occupied_cells.is_empty():
		var bomb_count: int = clampi(int((level_number - 2) * 0.25), 1, 3)
		for i: int in range(mini(bomb_count, occupied_cells.size())):
			var cell: Vector2i = occupied_cells.pop_back()
			put_cell(grid, cell.y, cell.x, "X")

	# Bloques de metal
	if level_number >= 5 and not occupied_cells.is_empty():
		var metal_count: int = clampi(int((level_number - 3) * 0.30), 1, 4)
		for i: int in range(mini(metal_count, occupied_cells.size())):
			var cell: Vector2i = occupied_cells.pop_back()
			put_cell(grid, cell.y, cell.x, "M")


# Garantiza un mínimo de ladrillos para evitar tableros vacíos
static func _ensure_density(grid: Array, rows: int, rng: RandomNumberGenerator) -> void:
	var count: int = 0
	for r: int in range(rows):
		for c: int in range(COLUMNS):
			if grid[r][c] != ".":
				count += 1
	if count < MIN_BRICKS:
		for r: int in range(rows):
			for c: int in range(COLUMNS / 2):
				if grid[r][c] == "." and rng.randf() < 0.45:
					put_cell(grid, r, c, "1")


# Patrones geométricos base
static func _pattern_arch(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if c >= r:
				put_cell(grid, r, c, "1")

static func _pattern_checker(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if (r + c) % 2 == 0:
				put_cell(grid, r, c, "1")

static func _pattern_pyramid(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if c >= (rows - 1 - r):
				put_cell(grid, r, c, "1")

static func _pattern_fortress(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if r == 0 or r == rows - 1 or c == 0 or c == (COLUMNS / 2 - 1):
				put_cell(grid, r, c, "1")

static func _pattern_diamond(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	var mid: int = rows / 2
	for r: int in range(rows):
		var dist: int = absi(r - mid)
		for c: int in range(COLUMNS / 2):
			if c >= dist:
				put_cell(grid, r, c, "1")

static func _pattern_stripes(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if c % 2 == 0:
				put_cell(grid, r, c, "1")

static func _pattern_noise(grid: Array, rows: int, rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if rng.randf() < 0.65:
				put_cell(grid, r, c, "1")

static func _pattern_zigzag(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if (r + c) % 3 != 0:
				put_cell(grid, r, c, "1")

static func _pattern_towers(grid: Array, rows: int, _rng: RandomNumberGenerator) -> void:
	for r: int in range(rows):
		for c: int in range(COLUMNS / 2):
			if c in [1, 2, 5, 6]:
				put_cell(grid, r, c, "1")


# Paleta de colores temáticos por nivel
static func theme_color(level_number: int, _seed: int) -> Color:
	var colors: Array[Color] = [
		Color(0.2, 0.4, 0.9), Color(0.1, 0.8, 0.5), Color(0.9, 0.5, 0.1),
		Color(0.8, 0.2, 0.4), Color(0.6, 0.1, 0.8), Color(0.2, 0.7, 0.8)
	]
	return colors[(level_number - 1) % colors.size()]


# Nombre del entorno temático por nivel
static func theme_name(level_number: int) -> String:
	var names: Array[String] = [
		"CIUDAD NEÓN", "BAHÍA DIGITAL", "DESIERTO CRISTAL",
		"NÚCLEO MAGMA", "ABISMO CÍBER", "ORBITAL ALTO"
	]
	return names[(level_number - 1) % names.size()]
