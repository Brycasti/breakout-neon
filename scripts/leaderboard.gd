extends Node
## Conexión del juego con la base de datos (autoload "Leaderboard").
##
## Habla con el servidor local (res://servidor/servidor.py) por HTTP + JSON:
##   - enviar_partida(): guarda el resultado de una partida terminada.
##   - registrar_evento(): apunta lo que hace el jugador (power-ups, ladrillos
##     especiales, bolas perdidas...) y los envía agrupados cada pocos segundos.
##   - pedir_ranking(): lee la clasificación para la pantalla de récords.
##
## Si el servidor está apagado el juego NO se bloquea: las partidas que no se
## pudieron enviar se guardan en user://envios_pendientes.json y se reintentan
## la próxima vez que se arranca el juego.

const BASE_URL: String = "http://127.0.0.1:8000"
const RUTA_PENDIENTES: String = "user://envios_pendientes.json"
const TIEMPO_LIMITE: float = 5.0
const MAX_LOTE: int = 20
const INTERVALO_LOTE: float = 3.0

signal partida_guardada(ok: bool, puesto: int, mensaje: String)
signal ranking_listo(filas: Array)
signal conexion_cambiada(conectado: bool)

var conectado: bool = true

## Identificador de esta ejecución del juego. Sirve para que el servidor
## atribuya al nombre correcto los eventos que se registraron durante la
## partida (cuando el jugador todavía no había escrito su nombre).
var sesion: String = ""

var _eventos: Array = []
var _tiempo_lote: float = 0.0
var _pendientes: Array = []


func _ready() -> void:
	# El autoload debe seguir funcionando aunque el juego esté en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	sesion = "%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	_pendientes = _leer_pendientes()
	if not _pendientes.is_empty():
		_reintentar_pendientes()


func _process(delta: float) -> void:
	if _eventos.is_empty():
		return
	_tiempo_lote += delta
	if _tiempo_lote >= INTERVALO_LOTE:
		_tiempo_lote = 0.0
		enviar_eventos()


func _notification(que: int) -> void:
	# Último intento de enviar lo que quede en cola al cerrar la ventana.
	if que == NOTIFICATION_WM_CLOSE_REQUEST and not _eventos.is_empty():
		enviar_eventos()


# --- Partidas ------------------------------------------------------------

## Guarda una partida terminada en la base de datos.
## `datos` admite: jugador, puntos, nivel, racha, ladrillos, powerups, vidas,
## modo, duracion_s, skin_bola, skin_pala.
func enviar_partida(datos: Dictionary) -> void:
	if not datos.has("jugador"):
		datos["jugador"] = nombre_jugador()
	if not datos.has("sesion"):
		datos["sesion"] = sesion
	var cuerpo: String = JSON.stringify(datos)

	var http: HTTPRequest = _crear_peticion()
	http.request_completed.connect(_al_recibir_partida.bind(http, cuerpo))
	var error: int = http.request(BASE_URL + "/api/partidas",
		["Content-Type: application/json"], HTTPClient.METHOD_POST, cuerpo)
	if error != OK:
		http.queue_free()
		_guardar_pendiente(cuerpo)
		_cambiar_conexion(false)
		partida_guardada.emit(false, 0, "Sin conexión con el servidor")


func _al_recibir_partida(resultado: int, codigo: int, _cabeceras: PackedStringArray,
		cuerpo: PackedByteArray, http: HTTPRequest, enviado: String) -> void:
	http.queue_free()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo < 200 or codigo >= 300:
		# Se guarda para reintentarlo en otro momento; el juego sigue igual.
		_guardar_pendiente(enviado)
		_cambiar_conexion(false)
		partida_guardada.emit(false, 0, "El servidor no respondió (se reintentará)")
		return

	_cambiar_conexion(true)
	var puesto: int = 0
	var datos: Variant = JSON.parse_string(cuerpo.get_string_from_utf8())
	if datos is Dictionary:
		puesto = int(datos.get("puesto", 0))
	partida_guardada.emit(true, puesto, "¡PARTIDA GUARDADA!")


# --- Eventos (todo lo que hace el jugador) -------------------------------

## Apunta algo que ha hecho el jugador. Se acumula y se envía en lote.
func registrar_evento(tipo: String, detalle: String = "", valor: int = 0, nivel: int = 0) -> void:
	_eventos.append({
		"jugador": nombre_jugador(),
		"tipo": tipo,
		"detalle": detalle,
		"valor": valor,
		"nivel": nivel,
		"sesion": sesion,
	})
	if _eventos.size() >= MAX_LOTE:
		enviar_eventos()


## Envía ya los eventos acumulados (lote de uno o varios).
func enviar_eventos() -> void:
	if _eventos.is_empty():
		return
	var cuerpo: String = JSON.stringify(_eventos)
	_eventos = []
	_tiempo_lote = 0.0

	var http: HTTPRequest = _crear_peticion()
	http.request_completed.connect(_al_recibir_eventos.bind(http))
	var error: int = http.request(BASE_URL + "/api/eventos",
		["Content-Type: application/json"], HTTPClient.METHOD_POST, cuerpo)
	if error != OK:
		http.queue_free()
		_cambiar_conexion(false)


func _al_recibir_eventos(resultado: int, codigo: int, _cabeceras: PackedStringArray,
		_cuerpo: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	# Un evento perdido no es grave: no se reencola para no llenar el disco.
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo < 200 or codigo >= 300:
		_cambiar_conexion(false)
	else:
		_cambiar_conexion(true)


# --- Clasificación -------------------------------------------------------

## Pide la clasificación al servidor; responde con la señal `ranking_listo`.
func pedir_ranking(limite: int = 10, modo: String = "") -> void:
	var url: String = "%s/api/ranking?limite=%d&modo=%s" % [BASE_URL, limite, modo]

	var http: HTTPRequest = _crear_peticion()
	http.request_completed.connect(_al_recibir_ranking.bind(http))
	var error: int = http.request(url)
	if error != OK:
		http.queue_free()
		_cambiar_conexion(false)
		ranking_listo.emit([])


func _al_recibir_ranking(resultado: int, codigo: int, _cabeceras: PackedStringArray,
		cuerpo: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_cambiar_conexion(false)
		ranking_listo.emit([])
		return

	_cambiar_conexion(true)
	var datos: Variant = JSON.parse_string(cuerpo.get_string_from_utf8())
	ranking_listo.emit(datos if datos is Array else [])


# --- Utilidades ----------------------------------------------------------

func nombre_jugador() -> String:
	var nombre: String = GameData.player_name.strip_edges()
	return nombre if nombre != "" else "Anónimo"


func _crear_peticion() -> HTTPRequest:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIEMPO_LIMITE
	add_child(http)
	return http


func _cambiar_conexion(valor: bool) -> void:
	if valor == conectado:
		return
	conectado = valor
	conexion_cambiada.emit(conectado)


# --- Cola de envíos pendientes (servidor apagado) ------------------------

func _guardar_pendiente(cuerpo: String) -> void:
	if _pendientes.size() >= 50:      # límite para no crecer sin control
		_pendientes.pop_front()
	_pendientes.append(cuerpo)
	_escribir_pendientes()


func _reintentar_pendientes() -> void:
	var cola: Array = _pendientes
	_pendientes = []
	_escribir_pendientes()
	for cuerpo: String in cola:
		var datos: Variant = JSON.parse_string(cuerpo)
		if datos is Dictionary:
			enviar_partida(datos)


func _leer_pendientes() -> Array:
	if not FileAccess.file_exists(RUTA_PENDIENTES):
		return []
	var archivo: FileAccess = FileAccess.open(RUTA_PENDIENTES, FileAccess.READ)
	if archivo == null:
		return []
	var texto: String = archivo.get_as_text()
	archivo.close()
	var datos: Variant = JSON.parse_string(texto)
	return datos if datos is Array else []


func _escribir_pendientes() -> void:
	var archivo: FileAccess = FileAccess.open(RUTA_PENDIENTES, FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_string(JSON.stringify(_pendientes))
	archivo.close()

func iniciar_sesion() -> void:
	enviar_eventos()
	sesion = "%d-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec(), randi() % 100000]


func registrar_mapa(datos: Dictionary) -> void:
	_eventos.append({"jugador": nombre_jugador(), "tipo": "telemetria",
		"nivel": datos.get("nivel", 1), "sesion": sesion, "payload": datos})
	if _eventos.size() >= MAX_LOTE:
		enviar_eventos()
