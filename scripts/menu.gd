extends Control

const GAME_SCENE: String = "res://scenes/main.tscn"

const ACCENT: Color = Color(0.35, 0.86, 1.0)
const ACCENT_GOLD: Color = Color(1.0, 0.84, 0.3)
const ACCENT_GREEN: Color = Color(0.45, 0.95, 0.55)

@onready var home_page: Control = $Home
@onready var levels_page: Control = $Levels
@onready var wardrobe_page: Control = $Wardrobe
@onready var scores_page: Control = $Scores
@onready var scores_status: Label = $Scores/StatusLabel
@onready var scores_rows: VBoxContainer = $Scores/Panel/Rows

@onready var hint_label: Label = $Home/HintLabel
@onready var best_score_label: Label = $Home/InfoPanel/Box/BestScoreLabel
@onready var total_points_label: Label = $Home/InfoPanel/Box/TotalPointsLabel
@onready var progress_label: Label = $Home/InfoPanel/Box/ProgressLabel
@onready var showcase_ball: TextureRect = $Home/Showcase/Box/BallPreview
@onready var showcase_paddle: TextureRect = $Home/Showcase/Box/PaddlePreview
@onready var showcase_names: Label = $Home/Showcase/Box/SkinNamesLabel

@onready var level_grid: GridContainer = $Levels/LevelGrid
@onready var level_preview: GridContainer = $Levels/PreviewPanel/Box/LayoutPreview
@onready var level_info: Label = $Levels/PreviewPanel/Box/PreviewInfoLabel
@onready var levels_play_button: Button = $Levels/PlayButton

@onready var wardrobe_points: Label = $Wardrobe/PointsLabel
@onready var wardrobe_preview: TextureRect = $Wardrobe/PreviewPanel/Box/BigPreview
@onready var wardrobe_name: Label = $Wardrobe/PreviewPanel/Box/Info/PreviewName
@onready var wardrobe_desc: Label = $Wardrobe/PreviewPanel/Box/Info/PreviewDesc
@onready var wardrobe_cards: HBoxContainer = $Wardrobe/Cards
@onready var balls_tab: Button = $Wardrobe/Tabs/BallsTab
@onready var paddles_tab: Button = $Wardrobe/Tabs/PaddlesTab

var wardrobe_tab: String = "balls"
var highlighted_skin: String = ""
var _selected_level: int = 1


func _ready() -> void:
	randomize()
	Sfx.enabled = GameData.sfx_on
	Leaderboard.ranking_listo.connect(_on_ranking_listo)
	_style_buttons()
	_setup_wardrobe_layout()
	_connect_static_buttons()
	_build_level_grid()
	_select_level(GameData.selected_level)
	_show_page("home")
	_refresh_home()
	_refresh_wardrobe()


# Ajuste horizontal del panel informativo del armario
func _setup_wardrobe_layout() -> void:
	var info_box: Control = get_node_or_null("Wardrobe/PreviewPanel/Box/Info") as Control
	if info_box != null:
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.custom_minimum_size.x = 420.0
	
	if wardrobe_desc != null:
		wardrobe_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wardrobe_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wardrobe_desc.custom_minimum_size.x = 420.0
		wardrobe_desc.add_theme_font_size_override("font_size", 13)
		wardrobe_desc.add_theme_constant_override("line_spacing", 2)


# Creación de estilos visuales para paneles y botones
func _panel_style(bg: Color, border: Color, border_width: int, radius: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10.0)
	return style


func _fancy_button(button: Button, font_size: int, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", accent.lightened(0.3))
	button.add_theme_stylebox_override("normal",
		_panel_style(Color(0.05, 0.08, 0.18, 0.82), accent.darkened(0.3), 2))
	button.add_theme_stylebox_override("hover",
		_panel_style(Color(0.10, 0.18, 0.34, 0.94), accent, 2))
	button.add_theme_stylebox_override("pressed",
		_panel_style(accent.darkened(0.45), accent.lightened(0.2), 2))
	button.add_theme_stylebox_override("focus",
		_panel_style(Color(0, 0, 0, 0), accent, 2))
	button.add_theme_stylebox_override("disabled",
		_panel_style(Color(0.04, 0.05, 0.10, 0.7), Color(0.28, 0.30, 0.36), 2))
	button.mouse_entered.connect(_play_hover)


func _style_buttons() -> void:
	_fancy_button($Home/PlayButton, 34, ACCENT_GREEN)
	_fancy_button($Home/EndlessButton, 26, ACCENT_GOLD)
	_fancy_button($Home/LevelsButton, 26, ACCENT)
	_fancy_button($Home/WardrobeButton, 26, Color(0.85, 0.6, 1.0))
	_fancy_button($Home/ScoresButton, 26, ACCENT_GOLD)
	_fancy_button($Scores/BackButton, 26, ACCENT)
	_fancy_button($Levels/PlayButton, 26, ACCENT_GREEN)
	_fancy_button($Levels/BackButton, 26, ACCENT)
	_fancy_button($Wardrobe/BackButton, 26, ACCENT)
	_fancy_button(balls_tab, 24, ACCENT)
	_fancy_button(paddles_tab, 24, Color(0.85, 0.6, 1.0))


func _play_hover() -> void:
	Sfx.play("click", -16.0, 1.6)


func _connect_static_buttons() -> void:
	$Home/PlayButton.pressed.connect(_on_play)
	$Home/EndlessButton.pressed.connect(_on_endless)
	$Home/LevelsButton.pressed.connect(_on_open_levels)
	$Home/WardrobeButton.pressed.connect(_on_open_wardrobe)
	$Home/ScoresButton.pressed.connect(_on_open_scores)
	$Levels/BackButton.pressed.connect(_on_back_home)
	$Wardrobe/BackButton.pressed.connect(_on_back_home)
	$Scores/BackButton.pressed.connect(_on_back_home)
	levels_play_button.pressed.connect(_on_play)
	balls_tab.pressed.connect(_set_tab.bind("balls"))
	paddles_tab.pressed.connect(_set_tab.bind("paddles"))


# Control de vistas entre pantallas
func _show_page(page: String) -> void:
	home_page.visible = page == "home"
	levels_page.visible = page == "levels"
	wardrobe_page.visible = page == "wardrobe"
	scores_page.visible = page == "scores"
	if page == "home":
		_refresh_home()


func _on_back_home() -> void:
	Sfx.play_ui()
	_show_page("home")


func _on_open_levels() -> void:
	Sfx.play_ui()
	_refresh_level_preview()
	_show_page("levels")


func _on_open_wardrobe() -> void:
	Sfx.play_ui()
	_refresh_wardrobe()
	_show_page("wardrobe")


# Consulta y renderizado de la tabla de clasificación
func _on_open_scores() -> void:
	Sfx.play_ui()
	_show_page("scores")
	_pedir_ranking()


func _pedir_ranking() -> void:
	for child: Node in scores_rows.get_children():
		scores_rows.remove_child(child)
		child.queue_free()
	scores_status.text = "Conectando con el servidor…"
	Leaderboard.pedir_ranking(15)


func _on_ranking_listo(filas: Array) -> void:
	for child: Node in scores_rows.get_children():
		scores_rows.remove_child(child)
		child.queue_free()

	if filas.is_empty():
		scores_status.text = "Sin conexión con el servidor local"
		_fila_ranking(["—", "No se pudo leer la clasificación", "", "", ""], true)
		return

	scores_status.text = "%d mejores jugadores" % filas.size()
	_fila_ranking(["#", "JUGADOR", "PUNTOS", "NIVEL", "PARTIDAS"], true)
	var puesto: int = 0
	for fila: Dictionary in filas:
		puesto += 1
		_fila_ranking([
			str(puesto),
			str(fila.get("jugador", "?")),
			"%d" % int(fila.get("puntos", 0)),
			"%d" % int(fila.get("nivel", 0)),
			"%d" % int(fila.get("partidas", 0)),
		], false)


func _fila_ranking(valores: Array, es_cabecera: bool) -> void:
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var anchos: Array[int] = [60, 380, 200, 120, 140]
	for i: int in range(valores.size()):
		var etiqueta: Label = Label.new()
		etiqueta.text = str(valores[i])
		etiqueta.custom_minimum_size = Vector2(anchos[i], 0)
		etiqueta.add_theme_font_size_override("font_size", 22)
		if es_cabecera:
			etiqueta.add_theme_font_size_override("font_size", 18)
			etiqueta.add_theme_color_override("font_color", ACCENT_GOLD)
		elif i == 0:
			etiqueta.add_theme_font_size_override("font_size", 24)
			etiqueta.add_theme_color_override("font_color", ACCENT)
		elif i == 1:
			etiqueta.add_theme_color_override("font_color", Color.WHITE)
		else:
			etiqueta.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
		fila.add_child(etiqueta)
	scores_rows.add_child(fila)


func _start_game() -> void:
	Sfx.play("launch", -2.0)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_play() -> void:
	GameData.endless = false
	GameData.selected_level = _selected_level
	GameData.save_data()
	_start_game()


func _on_endless() -> void:
	GameData.endless = true
	GameData.save_data()
	_start_game()


# Actualización de datos en la pantalla principal
func _refresh_home() -> void:
	best_score_label.text = "MEJOR PUNTUACIÓN:  %d" % GameData.best_score
	total_points_label.text = "PUNTOS TOTALES:  %d" % GameData.total_points
	progress_label.text = "NIVELES SUPERADOS:  %d / %d" % [GameData.cleared_count(), GameData.TOTAL_LEVELS]
	var ball_entry: Dictionary = GameData.ball_entry()
	var paddle_entry: Dictionary = GameData.paddle_entry()
	showcase_ball.texture = SkinCatalog.texture_for(ball_entry["path"])
	showcase_paddle.texture = SkinCatalog.texture_for(paddle_entry["path"])
	showcase_names.text = "%s  +  %s" % [ball_entry["name"], paddle_entry["name"]]
	hint_label.text = "Flechas / A-D o el ratón para mover  ·  ESPACIO lanza  ·  P pausa  ·  R reinicia"


# Generación del selector y previsualización de niveles
func _build_level_grid() -> void:
	for child: Node in level_grid.get_children():
		level_grid.remove_child(child)
		child.queue_free()
	for i: int in range(1, GameData.TOTAL_LEVELS + 1):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(132, 58)
		button.text = "NIVEL %d" % i
		var accent: Color = ACCENT_GREEN if GameData.is_cleared(i) else ACCENT
		_fancy_button(button, 20, accent)
		if GameData.is_cleared(i):
			button.add_theme_color_override("font_color", ACCENT_GREEN)
		button.pressed.connect(_on_level_pressed.bind(i))
		level_grid.add_child(button)


func _on_level_pressed(level_number: int) -> void:
	Sfx.play_ui()
	_select_level(level_number)


func _select_level(level_number: int) -> void:
	_selected_level = clampi(level_number, 1, GameData.TOTAL_LEVELS)
	levels_play_button.text = "JUGAR NIVEL %d" % _selected_level
	_refresh_level_preview()


func _refresh_level_preview() -> void:
	for child: Node in level_preview.get_children():
		level_preview.remove_child(child)
		child.queue_free()

	var seed_to_use: int = GameData.roll_new_level_seed(_selected_level)
	var layout: Array = LevelGen.layout_for(_selected_level, seed_to_use)

	for row: String in layout:
		for c: int in range(LevelGen.COLUMNS):
			var code: String = row[c] if c < row.length() else "."
			var index: int = maxi(LevelGen.CHAR_BY_CODE.find(code), 0)
			var cell: ColorRect = ColorRect.new()
			cell.custom_minimum_size = Vector2(17, 11)
			cell.color = LevelGen.PREVIEW_COLORS[index]
			level_preview.add_child(cell)
	var bricks: int = 0
	for row: String in layout:
		for c: int in range(row.length()):
			if row[c] != ".":
				bricks += 1
	var state: String = "SUPERADO" if GameData.is_cleared(_selected_level) else "SIN SUPERAR"
	level_info.text = "Nivel %d  ·  %d ladrillos  ·  %d filas\n%s" % [
		_selected_level, bricks, layout.size(), state
	]


# Control y renderizado del armario de skins
func _set_tab(tab: String) -> void:
	wardrobe_tab = tab
	Sfx.play_ui()
	_refresh_wardrobe()


func _refresh_wardrobe() -> void:
	wardrobe_points.text = "PUNTOS TOTALES:  %d" % GameData.total_points
	balls_tab.disabled = wardrobe_tab == "balls"
	paddles_tab.disabled = wardrobe_tab == "paddles"
	var list: Array = SkinCatalog.BALLS if wardrobe_tab == "balls" else SkinCatalog.PADDLES
	var equipped: String = GameData.ball_skin if wardrobe_tab == "balls" else GameData.paddle_skin
	if highlighted_skin == "" or not _list_has(list, highlighted_skin):
		highlighted_skin = equipped
	_build_cards(list, equipped)
	_refresh_skin_preview(list, equipped)


func _list_has(list: Array, id: String) -> bool:
	for entry: Dictionary in list:
		if entry["id"] == id:
			return true
	return false


func _build_cards(list: Array, equipped: String) -> void:
	for child: Node in wardrobe_cards.get_children():
		wardrobe_cards.remove_child(child)
		child.queue_free()
	for entry: Dictionary in list:
		var unlocked: bool = GameData.is_unlocked(entry)
		var selected: bool = equipped == entry["id"]
		var accent: Color = ACCENT_GREEN if selected else (ACCENT if unlocked else Color(0.5, 0.5, 0.6))
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(170, 176)
		button.clip_contents = true
		_fancy_button(button, 18, accent)
		button.pressed.connect(_on_card_pressed.bind(entry))

		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 8.0
		box.offset_top = 8.0
		box.offset_right = -8.0
		box.offset_bottom = -8.0
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 4)
		button.add_child(box)

		var icon: TextureRect = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(140, 100)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = SkinCatalog.texture_for(entry["path"])
		if not unlocked:
			icon.modulate = Color(0.25, 0.25, 0.3, 0.85)
		box.add_child(icon)

		var name_label: Label = Label.new()
		name_label.text = str(entry["name"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color",
			Color.WHITE if unlocked else Color(0.6, 0.6, 0.68))
		box.add_child(name_label)

		var state_label: Label = Label.new()
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state_label.add_theme_font_size_override("font_size", 14)
		if selected:
			state_label.text = "EQUIPADA"
			state_label.add_theme_color_override("font_color", ACCENT_GREEN)
		elif unlocked:
			state_label.text = "lista para usar"
			state_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
		else:
			state_label.text = "%d pts" % int(entry["price"])
			state_label.add_theme_color_override("font_color", ACCENT_GOLD)
		box.add_child(state_label)

		button.mouse_entered.connect(_on_card_hover.bind(entry))
		wardrobe_cards.add_child(button)


func _on_card_hover(entry: Dictionary) -> void:
	highlighted_skin = str(entry["id"])
	var list: Array = SkinCatalog.BALLS if wardrobe_tab == "balls" else SkinCatalog.PADDLES
	var equipped: String = GameData.ball_skin if wardrobe_tab == "balls" else GameData.paddle_skin
	_refresh_skin_preview(list, equipped)


func _on_card_pressed(entry: Dictionary) -> void:
	highlighted_skin = str(entry["id"])
	if not GameData.is_unlocked(entry):
		Sfx.play("steel", -4.0)
		wardrobe_desc.text = "BLOQUEADA · Requiere %d pts (te faltan %d).\nAcumula puntos jugando partidas." % [
			int(entry["price"]), int(entry["price"]) - GameData.total_points
		]
		return
	if wardrobe_tab == "balls":
		GameData.select_ball(str(entry["id"]))
	else:
		GameData.select_paddle(str(entry["id"]))
	Sfx.play("power", -3.0)
	_refresh_wardrobe()
	_refresh_home()


func _refresh_skin_preview(list: Array, equipped: String) -> void:
	var entry: Dictionary = SkinCatalog.by_id(list, highlighted_skin)
	var unlocked: bool = GameData.is_unlocked(entry)
	wardrobe_preview.texture = SkinCatalog.texture_for(entry["path"])
	
	var name_text: String = str(entry["name"])
	if equipped == entry["id"]:
		name_text += "  ·  [EQUIPADA]"
	elif unlocked:
		name_text += "  ·  (Clic para equipar)"
	wardrobe_name.text = name_text

	var text_body: String = str(entry["desc"])
	if not unlocked:
		text_body += "\n🔒 Bloqueada · Desbloqueo a los %d pts" % int(entry["price"])

	wardrobe_desc.text = text_body
	wardrobe_points.text = "PUNTOS TOTALES:  %d" % GameData.total_points
