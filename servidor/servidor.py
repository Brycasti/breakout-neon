"""
=========================================================================
 BREAKOUT NEON - Servidor local + base de datos + interfaz web
=========================================================================
 Práctica 4: Conexión a una base de datos.

 Este programa hace TRES cosas:
   1. Guarda en una base de datos SQLite todo lo que hace el jugador
      (partidas terminadas y eventos sueltos durante el juego).
   2. Sirve una API REST (JSON) que el juego de Godot consume.
   3. Sirve la interfaz web para consultar los datos guardados.

 Cómo arrancarlo:
     python servidor.py
 y luego abrir en el navegador:  http://127.0.0.1:8000

 No necesita instalar NADA: usa solo la librería estándar de Python
 (http.server + sqlite3). Probado con Python 3.8 o superior.
"""

import json
import os
import sqlite3
import sys
import urllib.parse
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn

# --- Configuración -------------------------------------------------------

PUERTO = 8000
CARPETA = os.path.dirname(os.path.abspath(__file__))
RUTA_BD = os.path.join(CARPETA, "ranking.db")
CARPETA_WEB = os.path.join(CARPETA, "web")

# Límites de seguridad: el servidor NO se fía de lo que manda el cliente.
MAX_NOMBRE = 16
MAX_PUNTOS = 10_000_000
TIPOS_EVENTO = {
    "nivel_iniciado", "nivel_superado", "powerup", "brick_especial",
    "bola_perdida", "multibola", "escudo", "pausa", "juego_terminado",
    "juego_completado", "skin_equipada", "telemetria", "habilidad_debug",
}

SQL_TABLAS = """
CREATE TABLE IF NOT EXISTS partidas (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    jugador          TEXT    NOT NULL,
    puntos           INTEGER NOT NULL,
    nivel            INTEGER NOT NULL,
    racha            INTEGER NOT NULL DEFAULT 0,
    ladrillos        INTEGER NOT NULL DEFAULT 0,
    powerups         INTEGER NOT NULL DEFAULT 0,
    vidas            INTEGER NOT NULL DEFAULT 0,
    modo             TEXT    NOT NULL DEFAULT 'normal',
    duracion_s       REAL    NOT NULL DEFAULT 0,
    skin_bola        TEXT    NOT NULL DEFAULT '',
    skin_pala        TEXT    NOT NULL DEFAULT '',
    sesion           TEXT    NOT NULL DEFAULT '',
    fecha            TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS eventos (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    jugador   TEXT    NOT NULL,
    tipo      TEXT    NOT NULL,
    detalle   TEXT    NOT NULL DEFAULT '',
    valor     INTEGER NOT NULL DEFAULT 0,
    nivel     INTEGER NOT NULL DEFAULT 0,
    sesion    TEXT    NOT NULL DEFAULT '',
    fecha     TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_partidas_puntos ON partidas (puntos DESC);
CREATE INDEX IF NOT EXISTS idx_partidas_jugador ON partidas (jugador);
CREATE INDEX IF NOT EXISTS idx_eventos_fecha ON eventos (fecha DESC);
"""


# --- Base de datos -------------------------------------------------------

def abrir_bd():
    """Devuelve una conexión nueva. Se usa una por petición (sqlite3 no es
    seguro entre hilos compartiendo la misma conexión)."""
    con = sqlite3.connect(RUTA_BD, timeout=10)
    con.row_factory = sqlite3.Row
    con.executescript(SQL_TABLAS)
    if "payload" not in {r[1] for r in con.execute("PRAGMA table_info(eventos)")}:
        con.execute("ALTER TABLE eventos ADD COLUMN payload TEXT NOT NULL DEFAULT '{}'")
        con.commit()
    return con


def filas_a_diccionarios(filas):
    return [dict(f) for f in filas]


def limpiar_nombre(nombre):
    """Recorta el nombre y evita que se cuelen caracteres de control."""
    nombre = str(nombre or "").strip()
    nombre = "".join(c for c in nombre if c.isprintable())
    if not nombre:
        return "Anónimo"
    return nombre[:MAX_NOMBRE]


def entero(valor, minimo, maximo, defecto=0):
    try:
        n = int(float(valor))
    except (TypeError, ValueError):
        return defecto
    return max(minimo, min(n, maximo))


def recortar(valor, maximo=60):
    """Texto corto y sin recortes raros (para detalles y nombres de skin)."""
    return str(valor or "").strip()[:maximo]


def decimal(valor, minimo, maximo, defecto=0.0):
    try:
        n = float(valor)
    except (TypeError, ValueError):
        return defecto
    return max(minimo, min(n, maximo))


def guardar_partida(datos):
    jugador = limpiar_nombre(datos.get("jugador"))
    puntos = entero(datos.get("puntos"), 0, MAX_PUNTOS)
    modo = str(datos.get("modo", "normal")).lower()
    modo = modo if modo in ("normal", "infinito") else "normal"

    con = abrir_bd()
    sesion = recortar(datos.get("sesion", ""), 40)
    cur = con.execute(
        """INSERT INTO partidas
           (jugador, puntos, nivel, racha, ladrillos, powerups, vidas, modo,
            duracion_s, skin_bola, skin_pala, sesion)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
        (
            jugador,
            puntos,
            entero(datos.get("nivel"), 1, 999, 1),
            entero(datos.get("racha"), 0, 99999),
            entero(datos.get("ladrillos"), 0, 99999),
            entero(datos.get("powerups"), 0, 99999),
            entero(datos.get("vidas"), 0, 99),
            modo,
            round(decimal(datos.get("duracion_s"), 0.0, 86400.0), 1),
            recortar(datos.get("skin_bola", ""), 20),
            recortar(datos.get("skin_pala", ""), 20),
            sesion,
        ),
    )
    id_partida = cur.lastrowid

    # Los eventos de esta sesión se registraron durante la partida, cuando el
    # nombre todavía no se conocía (jugador = "Anónimo"). Aquí se corrigen.
    actividades_atribuidas = 0
    if sesion and jugador != "Anónimo":
        cambio = con.execute(
            "UPDATE eventos SET jugador = ? WHERE sesion = ? AND (jugador = 'Anónimo' OR tipo = 'telemetria')",
            (jugador, sesion),
        )
        actividades_atribuidas = max(0, cambio.rowcount)
    # ¿En qué puesto queda? (todas las partidas con más puntos, +1)
    puesto = con.execute(
        "SELECT COUNT(*) + 1 FROM partidas WHERE puntos > ?", (puntos,)
    ).fetchone()[0]
    mejor = con.execute(
        "SELECT MAX(puntos) FROM partidas WHERE jugador = ?", (jugador,)
    ).fetchone()[0]
    total_partidas = con.execute("SELECT COUNT(*) FROM partidas").fetchone()[0]
    con.commit()
    con.close()

    return {
        "id": id_partida,
        "jugador": jugador,
        "puntos": puntos,
        "puesto": puesto,
        "mejor_del_jugador": mejor,
        "total_partidas": total_partidas,
        "eventos_atribuidos": actividades_atribuidas,
    }


def guardar_eventos(lista, jugador_por_defecto="Anónimo"):
    if isinstance(lista, dict):
        lista = [lista]
    if not isinstance(lista, list):
        return 0

    con = abrir_bd()
    guardados = 0
    for ev in lista[:200]:  # como máximo 200 eventos por petición
        if not isinstance(ev, dict):
            continue
        tipo = str(ev.get("tipo", "")).strip().lower()
        if tipo not in TIPOS_EVENTO:
            continue  # se ignora cualquier tipo desconocido
        con.execute(
            """INSERT INTO eventos (jugador, tipo, detalle, valor, nivel, sesion, payload)
               VALUES (?,?,?,?,?,?,?)""",
            (
                limpiar_nombre(ev.get("jugador", jugador_por_defecto)),
                tipo,
                recortar(ev.get("detalle", "")),
                entero(ev.get("valor"), -99999, 99999),
                entero(ev.get("nivel"), 0, 999),
                recortar(ev.get("sesion", ""), 40),
                json.dumps(ev.get("payload", {}) if isinstance(ev.get("payload", {}), dict) else {}, ensure_ascii=False)[:50000],
            ),
        )
        guardados += 1
    con.commit()
    con.close()
    return guardados


# --- Consultas -----------------------------------------------------------

def consultar_ranking(limite=10, modo=""):
    con = abrir_bd()
    sql = """SELECT jugador,
                    MAX(puntos)      AS puntos,
                    MAX(nivel)       AS nivel,
                    MAX(racha)       AS racha,
                    COUNT(*)         AS partidas,
                    ROUND(AVG(puntos), 1) AS media,
                    MAX(fecha)       AS ultima
             FROM partidas
             WHERE (? = '' OR modo = ?)
             GROUP BY jugador
             ORDER BY puntos DESC, partidas DESC
             LIMIT ?"""
    filas = con.execute(sql, (modo, modo, limite)).fetchall()
    con.close()
    return filas_a_diccionarios(filas)


def consultar_partidas(limite=50, jugador="", modo=""):
    con = abrir_bd()
    filas = con.execute(
        """SELECT * FROM partidas
           WHERE (? = '' OR jugador LIKE ?) AND (? = '' OR modo = ?)
           ORDER BY id DESC LIMIT ?""",
        (jugador, "%" + jugador + "%", modo, modo, limite),
    ).fetchall()
    con.close()
    return filas_a_diccionarios(filas)


def consultar_eventos(limite=100, jugador="", tipo=""):
    con = abrir_bd()
    filas = con.execute(
        """SELECT * FROM eventos
           WHERE (? = '' OR jugador LIKE ?) AND (? = '' OR tipo = ?)
           ORDER BY id DESC LIMIT ?""",
        (jugador, "%" + jugador + "%", tipo, tipo, limite),
    ).fetchall()
    con.close()
    return filas_a_diccionarios(filas)


def consultar_jugadores():
    con = abrir_bd()
    filas = con.execute(
        """SELECT p.jugador,
                  MAX(p.puntos)        AS puntos,
                  MAX(p.nivel)         AS nivel,
                  MAX(p.racha)         AS racha,
                  COUNT(*)             AS partidas,
                  SUM(p.ladrillos)     AS ladrillos,
                  SUM(p.powerups)      AS powerups,
                  ROUND(SUM(p.duracion_s),1) AS tiempo_s,
                  MAX(p.fecha)         AS ultima,
                  (SELECT COUNT(*) FROM eventos e WHERE e.jugador = p.jugador) AS eventos
           FROM partidas p
           GROUP BY p.jugador
           ORDER BY puntos DESC"""
    ).fetchall()
    con.close()
    return filas_a_diccionarios(filas)


def consultar_jugador(nombre):
    """Ficha completa de un jugador: estadísticas, últimas partidas y eventos."""
    con = abrir_bd()
    resumen = con.execute(
        """SELECT COUNT(*) AS partidas, MAX(puntos) AS puntos,
                  MAX(nivel) AS nivel, MAX(racha) AS racha,
                  SUM(ladrillos) AS ladrillos, SUM(powerups) AS powerups,
                  ROUND(SUM(duracion_s),1) AS tiempo_s,
                  ROUND(AVG(puntos),1) AS media
           FROM partidas WHERE jugador = ?""",
        (nombre,),
    ).fetchone()
    ultimas = con.execute(
        "SELECT * FROM partidas WHERE jugador = ? ORDER BY id DESC LIMIT 10",
        (nombre,),
    ).fetchall()
    eventos = con.execute(
        """SELECT tipo, COUNT(*) AS veces, SUM(valor) AS valor
           FROM eventos WHERE jugador = ? GROUP BY tipo ORDER BY veces DESC""",
        (nombre,),
    ).fetchall()
    con.close()
    return {
        "jugador": nombre,
        "resumen": dict(resumen) if resumen else {},
        "partidas": filas_a_diccionarios(ultimas),
        "eventos": filas_a_diccionarios(eventos),
    }


def consultar_estadisticas():
    con = abrir_bd()
    p = con.execute(
        """SELECT COUNT(*) AS partidas, COUNT(DISTINCT jugador) AS jugadores,
                  MAX(puntos) AS mejor, ROUND(AVG(puntos),1) AS media,
                  MAX(racha) AS mejor_racha, SUM(ladrillos) AS ladrillos,
                  SUM(powerups) AS powerups,
                  ROUND(SUM(duracion_s),1) AS tiempo_s
           FROM partidas"""
    ).fetchone()
    eventos = con.execute(
        "SELECT COUNT(*) AS total FROM eventos"
    ).fetchone()
    tipos = con.execute(
        """SELECT tipo, COUNT(*) AS veces FROM eventos
           GROUP BY tipo ORDER BY veces DESC"""
    ).fetchall()
    por_nivel = con.execute(
        """SELECT nivel, COUNT(*) AS veces, MAX(puntos) AS mejor
           FROM partidas GROUP BY nivel ORDER BY nivel"""
    ).fetchall()
    por_dia = con.execute(
        """SELECT substr(fecha, 1, 10) AS dia, COUNT(*) AS partidas,
                  MAX(puntos) AS mejor
           FROM partidas GROUP BY dia ORDER BY dia"""
    ).fetchall()
    con.close()
    return {
        "partidas": dict(p) if p else {},
        "eventos_totales": eventos["total"] if eventos else 0,
        "eventos_por_tipo": filas_a_diccionarios(tipos),
        "niveles": filas_a_diccionarios(por_nivel),
        "por_dia": filas_a_diccionarios(por_dia),
    }


def consultar_analitica(modo="normal", jugador="", pruebas=False):
    con = abrir_bd()
    filas = con.execute("SELECT * FROM eventos WHERE tipo = 'telemetria' ORDER BY id").fetchall()
    intentos = {}
    for e in filas:
        try:
            d = json.loads(e["payload"])
            key = (e["sesion"], int(d.get("intento", 0)))
            if d.get("clase") == "inicio":
                intentos[key] = dict(d, sesion=e["sesion"], jugador=e["jugador"], fecha=e["fecha"], muestras=[], resultado="sin_cierre", tiempo=0)
            elif key in intentos:
                a = intentos[key]
                a["prueba"] = a.get("prueba", False) or bool(d.get("prueba"))
                a["tiempo"] = max(a["tiempo"], decimal(d.get("t"), 0, 86400))
                if d.get("clase") == "muestra":
                    a["muestras"].append(d)
                elif d.get("clase") == "fin":
                    a["resultado"] = d.get("resultado", "sin_cierre")
        except (ValueError, TypeError):
            continue
    seleccion = [a for a in intentos.values() if a.get("modo") == modo and jugador.casefold() in a["jugador"].casefold() and (pruebas or not a.get("prueba"))]
    niveles = {}
    for a in seleccion:
        n = int(a["nivel"])
        b = niveles.setdefault(n, dict(nivel=n, tema=a.get("tema", ""), intentos=0, victorias=0, derrotas=0, salidas=0, sin_cierre=0, tiempo=0, perdidas=0, habilidades=0))
        b["intentos"] += 1
        b["tiempo"] += a["tiempo"]
        b["victorias"] += a["resultado"] == "victoria"
        b["derrotas"] += a["resultado"] == "derrota"
        b["salidas"] += a["resultado"] in ("salida", "reinicio")
        b["sin_cierre"] += a["resultado"] == "sin_cierre"
        # Session + level identify event counters; currently each level is visited once per run.
        contadores = con.execute("SELECT tipo, COUNT(*) AS n FROM eventos WHERE sesion=? AND nivel=? GROUP BY tipo", (a["sesion"], n)).fetchall()
        for c in contadores:
            if c["tipo"] == "bola_perdida": b["perdidas"] += c["n"]
            if c["tipo"] == "powerup": b["habilidades"] += c["n"]
    con.close()
    jugadores = {}
    for a in seleccion:
        jugadores.setdefault(a["jugador"], set()).add(a["sesion"])
    recurrentes = sum(len(s) > 1 for nombre, s in jugadores.items() if nombre != "Anónimo")
    identificados = sum(nombre != "Anónimo" for nombre in jugadores)
    return {"niveles": sorted(niveles.values(), key=lambda n: n["nivel"]),
            "intentos": [{**a, "muestras": a["muestras"][::max(1, len(a["muestras"]) // 2000)]} for a in seleccion[-100:]],
            "total_intentos": len(seleccion), "jugadores": len(jugadores), "recurrentes": recurrentes,
            "identificados": identificados, "sesiones": len({a["sesion"] for a in seleccion})}


def exportar_csv():
    con = abrir_bd()
    filas = con.execute("SELECT * FROM partidas ORDER BY id DESC").fetchall()
    con.close()
    columnas = ("id", "jugador", "puntos", "nivel", "racha", "ladrillos",
                "powerups", "vidas", "modo", "duracion_s", "skin_bola",
                "skin_pala", "fecha")
    lineas = [";".join(columnas)]
    for f in filas:
        lineas.append(";".join(str(f[c]) for c in columnas))
    return "\n".join(lineas) + "\n"


def borrar_todo():
    con = abrir_bd()
    con.execute("DELETE FROM partidas")
    con.execute("DELETE FROM eventos")
    con.commit()
    con.close()


# --- Servidor HTTP -------------------------------------------------------

class Manejador(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "BreakoutNeon/1.0"

    # ---- utilidades de respuesta ----
    def _cabeceras(self, tipo, largo):
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(largo))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def responder_json(self, datos, codigo=200):
        cuerpo = json.dumps(datos, ensure_ascii=False).encode("utf-8")
        self.send_response(codigo)
        self._cabeceras("application/json; charset=utf-8", len(cuerpo))
        self.end_headers()
        self.wfile.write(cuerpo)

    def responder_texto(self, texto, tipo="text/plain; charset=utf-8", codigo=200):
        cuerpo = texto.encode("utf-8")
        self.send_response(codigo)
        self._cabeceras(tipo, len(cuerpo))
        self.end_headers()
        self.wfile.write(cuerpo)

    def responder_archivo(self, ruta_relativa):
        ruta = os.path.normpath(os.path.join(CARPETA_WEB, ruta_relativa))
        if not ruta.startswith(CARPETA_WEB) or not os.path.isfile(ruta):
            return self.responder_json({"error": "archivo no encontrado"}, 404)
        extension = os.path.splitext(ruta)[1].lower()
        tipos = {
            ".html": "text/html; charset=utf-8",
            ".css": "text/css; charset=utf-8",
            ".js": "application/javascript; charset=utf-8",
            ".svg": "image/svg+xml",
            ".png": "image/png",
            ".ico": "image/x-icon",
        }
        with open(ruta, "rb") as f:
            cuerpo = f.read()
        self.send_response(200)
        self._cabeceras(tipos.get(extension, "application/octet-stream"), len(cuerpo))
        self.end_headers()
        self.wfile.write(cuerpo)

    def leer_cuerpo(self):
        try:
            largo = int(self.headers.get("Content-Length", 0))
        except ValueError:
            return None
        if largo <= 0 or largo > 1_000_000:
            return None
        crudo = self.rfile.read(largo)
        try:
            return json.loads(crudo.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None

    def log_message(self, formato, *args):
        # Log corto y legible en la consola del servidor
        print("  %s -> %s" % (self.address_string(), formato % args))

    # ---- rutas ----
    def do_OPTIONS(self):
        self.send_response(204)
        self._cabeceras("text/plain", 0)
        self.end_headers()

    def do_GET(self):
        partes = urllib.parse.urlparse(self.path)
        ruta = partes.path
        q = urllib.parse.parse_qs(partes.query)

        def arg(nombre, defecto=""):
            return q.get(nombre, [defecto])[0]

        try:
            if ruta in ("/", "/index.html"):
                return self.responder_archivo("index.html")
            if ruta.startswith("/static/"):
                # se conserva "static/..." porque la carpeta se llama así
                return self.responder_archivo(ruta[len("/"):])

            if ruta == "/api/ranking":
                limite = entero(arg("limite", "10"), 1, 100, 10)
                modo = arg("modo")
                modo = modo if modo in ("normal", "infinito") else ""
                return self.responder_json(consultar_ranking(limite, modo))

            if ruta == "/api/partidas":
                return self.responder_json(consultar_partidas(
                    entero(arg("limite", "50"), 1, 500, 50),
                    arg("jugador"),
                    arg("modo") if arg("modo") in ("normal", "infinito") else "",
                ))

            if ruta == "/api/eventos":
                return self.responder_json(consultar_eventos(
                    entero(arg("limite", "100"), 1, 500, 100),
                    arg("jugador"), arg("tipo"),
                ))

            if ruta == "/api/jugadores":
                return self.responder_json(consultar_jugadores())

            if ruta.startswith("/api/jugadores/"):
                nombre = urllib.parse.unquote(ruta[len("/api/jugadores/"):])
                return self.responder_json(consultar_jugador(limpiar_nombre(nombre)))

            if ruta == "/api/analitica":
                return self.responder_json(consultar_analitica(arg("modo", "normal"), arg("jugador"), arg("pruebas") == "1"))

            if ruta == "/api/estadisticas":
                return self.responder_json(consultar_estadisticas())

            if ruta == "/api/export.csv":
                return self.responder_texto(
                    exportar_csv(), "text/csv; charset=utf-8")

            return self.responder_json({"error": "ruta desconocida"}, 404)
        except Exception as error:  # ninguna petición debe tumbar el servidor
            print("  ! ERROR:", error)
            return self.responder_json({"error": str(error)}, 500)

    def do_POST(self):
        ruta = urllib.parse.urlparse(self.path).path
        try:
            if ruta == "/api/partidas":
                datos = self.leer_cuerpo()
                if datos is None:
                    return self.responder_json({"error": "JSON inválido"}, 400)
                resultado = guardar_partida(datos)
                print("  + partida de %s: %s puntos (puesto %d, %d eventos atribuidos)"
                      % (resultado["jugador"], resultado["puntos"],
                         resultado["puesto"], resultado["eventos_atribuidos"]))
                return self.responder_json(resultado, 201)

            if ruta == "/api/eventos":
                datos = self.leer_cuerpo()
                if datos is None:
                    return self.responder_json({"error": "JSON inválido"}, 400)
                n = guardar_eventos(datos)
                return self.responder_json({"guardados": n}, 201)

            if ruta == "/api/limpiar":
                borrar_todo()
                print("  * base de datos vaciada")
                return self.responder_json({"ok": True})

            return self.responder_json({"error": "ruta desconocida"}, 404)
        except Exception as error:
            print("  ! ERROR:", error)
            return self.responder_json({"error": str(error)}, 500)


class ServidorConHilos(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    if not os.path.isdir(CARPETA_WEB):
        print("AVISO: no existe la carpeta web/, la interfaz no se servirá.")
    con = abrir_bd()          # crea las tablas la primera vez
    con.close()
    print("=" * 68)
    print(" BREAKOUT NEON · servidor local")
    print("=" * 68)
    print(" Base de datos : %s" % RUTA_BD)
    print(" Interfaz web  : http://127.0.0.1:%d" % PUERTO)
    print(" API           : http://127.0.0.1:%d/api/estadisticas" % PUERTO)
    print(" Detener       : Ctrl + C")
    print("=" * 68)
    servidor = ServidorConHilos(("0.0.0.0", PUERTO), Manejador)
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido. ¡Hasta la próxima!")
    finally:
        servidor.server_close()


if __name__ == "__main__":
    if sys.version_info < (3, 7):
        print("Se necesita Python 3.7 o superior.")
        sys.exit(1)
    main()
