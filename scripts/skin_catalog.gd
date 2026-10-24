class_name SkinCatalog
extends RefCounted

const BALLS: Array = [
	{
		"id": "plasma",
		"name": "Orbe de Plasma",
		"desc": "Energía azul girando sin parar.\n⚡ Electrocuta a 2 ladrillos vecinos en cada impacto.",
		"path": "res://assets/generated/skin_ball_plasma.png",
		"glow": Color(0.35, 0.85, 1.0),
		"price": 0,
	},
	{
		"id": "meteor",
		"name": "Meteorito",
		"desc": "Roca con venas de magma.\n🔥 Quema en área (DoT sostenido) a ladrillos y metales vecinos.",
		"path": "res://assets/generated/skin_ball_meteor.png",
		"glow": Color(1.0, 0.48, 0.12),
		"price": 600,
	},
	{
		"id": "gem",
		"name": "Gema Rúnica",
		"desc": "Cristal facetado giratorio.\n💎 Puntos dobles (2x) y dispara esquirlas a otro ladrillo al azar.",
		"path": "res://assets/generated/skin_ball_gem.png",
		"glow": Color(0.72, 0.42, 1.0),
		"price": 1200,
	},
	{
		"id": "star",
		"name": "Estrella",
		"desc": "Punta cósmica dorada.\n⭐ Lluvia de estrellas fugaces que barre ladrillos superiores.",
		"path": "res://assets/generated/skin_ball_star.png",
		"glow": Color(1.0, 0.85, 0.25),
		"price": 2000,
	},
	{
		"id": "eye",
		"name": "Ojo Alienígena",
		"desc": "Mirada vigilante en vuelo.\n👁 Rayo láser vertical que perfora toda la columna del ladrillo.",
		"path": "res://assets/generated/skin_ball_eye.png",
		"glow": Color(0.45, 0.95, 0.35),
		"price": 3000,
	},
	{
		"id": "bomb",
		"name": "Bomba",
		"desc": "Carga negra con mecha activa.\n💣 Cuenta regresiva (3 golpes) para detonar una explosión nuclear.",
		"path": "res://assets/generated/skin_ball_bomb.png",
		"glow": Color(1.0, 0.62, 0.2),
		"price": 4200,
	},
]

const PADDLES: Array = [
	{
		"id": "neon",
		"name": "Barra Neón",
		"desc": "Núcleo lumínico con laterales de energía.\n⚡ Combo dura el doble de tiempo (5.2s) y da +25% de puntuación.",
		"path": "res://assets/generated/skin_paddle_neon.png",
		"glow": Color(0.3, 0.9, 1.0),
		"price": 0,
	},
	{
		"id": "wood",
		"name": "Tabla de Roble",
		"desc": "Madera con refuerzo metálico.\n🛡 Amortigua la bola rápida y salva 1 bola por nivel con una red.",
		"path": "res://assets/generated/skin_paddle_wood.png",
		"glow": Color(0.85, 0.6, 0.3),
		"price": 600,
	},
	{
		"id": "metal",
		"name": "Viga de Acero",
		"desc": "Industria pesada con remaches.\n⚙ +20% más ancha y otorga 2x daño al siguiente impacto de bola.",
		"path": "res://assets/generated/skin_paddle_metal.png",
		"glow": Color(0.8, 0.82, 0.9),
		"price": 1400,
	},
	{
		"id": "ice",
		"name": "Bloque de Hielo",
		"desc": "Cristal congelado translúcido.\n❄ Campo magnético que atrae todos los power-ups hacia la pala.",
		"path": "res://assets/generated/skin_paddle_ice.png",
		"glow": Color(0.6, 0.9, 1.0),
		"price": 2400,
	},
	{
		"id": "lava",
		"name": "Roca Volcánica",
		"desc": "Basalto con grietas de magma.\n🔥 Carga térmica que prende fuego prolongado a los ladrillos.",
		"path": "res://assets/generated/skin_paddle_lava.png",
		"glow": Color(1.0, 0.45, 0.15),
		"price": 3600,
	},
	{
		"id": "candy",
		"name": "Barra de Caramelo",
		"desc": "Dulce, rayada y con glaseado.\n🍭 Aumenta la probabilidad de que caigan cápsulas de regalo.",
		"path": "res://assets/generated/skin_paddle_candy.png",
		"glow": Color(1.0, 0.5, 0.8),
		"price": 5000,
	},
]

static var _texture_cache: Dictionary = {}


# Carga la textura solicitada utilizando caché en memoria
static func texture_for(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		tex = _load_from_disk(path)
	_texture_cache[path] = tex
	return tex


# Carga directa de imagen desde disco como respaldo
static func _load_from_disk(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


# Búsqueda de entrada por identificador
static func by_id(list: Array, id: String) -> Dictionary:
	for entry: Dictionary in list:
		if entry["id"] == id:
			return entry
	return list[0] if not list.is_empty() else {}


# Filtra elementos desbloqueados según el puntaje acumulado
static func unlocked(list: Array, total_points: int) -> Array:
	var result: Array = []
	for entry: Dictionary in list:
		if int(entry["price"]) <= total_points:
			result.append(entry)
	return result


# Verifica si un elemento individual cumple con el requisito de desbloqueo
static func is_unlocked(entry: Dictionary, total_points: int) -> bool:
	return int(entry["price"]) <= total_points
