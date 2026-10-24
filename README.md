# 🕹️ BREAKOUT NEON

Juego tipo *Breakout* en **Godot 4** conectado a una **base de datos SQLite**, con
**clasificación (leaderboard)** y una **interfaz web local** para consultar todo lo
que hace el jugador.

> **Práctica 4 — Conexión a una base de datos**
> Alumno: *José Luis David Bonilla Carranza*

---

## 🎯 Qué hace el proyecto

| Requisito de la práctica | Cómo se cumple |
|---|---|
| **Conectar el juego con una base de datos** | El juego (Godot) envía cada partida y cada evento del jugador por **HTTP + JSON** a un servidor local en Python, que los guarda en una base de datos **SQLite** (`servidor/ranking.db`). |
| **Guardar todo lo que hace el jugador** | Tabla `partidas` con el resultado completo (puntos, nivel, racha, ladrillos, coleccionables, vidas, modo, **duración/tiempo**, skins) y tabla `eventos` con el detalle momento a momento (nivel iniciado/superado, power-up recogido, ladrillo especial, bola perdida, pausa…). |
| **Crear un leaderboard** | Pantalla **RÉCORDS** dentro del juego (lee del servidor) y pestaña **Clasificación** en la web. |
| **Interfaz para consultar la información en un sistema web local** | Panel web servido en `http://127.0.0.1:8000` con 5 pestañas: Clasificación, Jugadores, Partidas, Actividad y Estadísticas. |

---

## 🚀 Cómo se arranca

### 1. El servidor (necesario para guardar datos)

```bash
cd servidor
python servidor.py
```

No hay que instalar **nada**: usa solo la librería estándar de Python 3.8+.
Al arrancar crea la base de datos `servidor/ranking.db` si no existe.

### 2. El juego

Abre el proyecto con **Godot 4** y pulsa **F5** (la escena principal es
`scenes/menu.tscn`). Jugar una partida y, al terminar, escribir el nombre:
la partida se guarda en la base de datos.

> Si el servidor está apagado el juego funciona igual: los resultados se
> guardan en `user://envios_pendientes.json` y se envían solos la próxima vez.

### 3. La interfaz web

Con el servidor corriendo, abre en el navegador:

```
http://127.0.0.1:8000
```

También puedes verlo desde el móvil (misma red WiFi) usando la IP de tu PC,
por ejemplo `http://192.168.1.50:8000`.

---

## 🧱 Arquitectura

```
┌──────────────────┐   HTTP + JSON   ┌────────────────────┐   SQL   ┌──────────────┐
│  GODOT (el juego)│ ──────────────► │  servidor.py       │ ──────► │  SQLite      │
│  autoload        │                 │  API REST +        │         │  ranking.db  │
│  "Leaderboard"   │ ◄────────────── │  sirve la web      │ ◄────── └──────────────┘
└──────────────────┘   clasificación └─────────┬──────────┘
                                               │ HTML/CSS/JS
                                               ▼
                                     ┌────────────────────┐
                                     │ navegador          │
                                     │ localhost:8000     │
                                     └────────────────────┘
```

El juego **nunca** toca la base de datos directamente: habla con el servidor.
Así la web y el juego leen y escriben lo mismo sin pelearse por el archivo.

---

## 🗂️ Estructura del proyecto

```
├── project.godot
├── scenes/
│   ├── menu.tscn          # portada: JUGAR, MODO INFINITO, NIVELES, ARMARIO, RÉCORDS
│   ├── main.tscn          # la partida (incluye el panel de nombre al terminar)
│   └── ...
├── scripts/
│   ├── leaderboard.gd     # ★ autoload: cliente HTTP de la base de datos
│   ├── main.gd            # ★ registra eventos y envía la partida
│   ├── menu.gd            # ★ pantalla RÉCORDS (lee del servidor)
│   ├── game_data.gd       # progreso local + nombre del jugador
│   └── ...
└── servidor/
    ├── servidor.py        # ★ API REST + base de datos + sirve la web
    ├── ranking.db         # base de datos SQLite (se crea sola)
    └── web/
        ├── index.html     # ★ interfaz web
        └── static/
            ├── style.css
            └── app.js
```

---

## 🗄️ Base de datos

Dos tablas en `ranking.db`:

**`partidas`** — una fila por partida terminada

| Columna | Significado |
|---|---|
| `jugador` | Nombre que escribe el jugador al terminar |
| `puntos` | Puntuación final |
| `nivel` | Nivel máximo alcanzado |
| `racha` | Mejor racha (ladrillos seguidos) |
| `ladrillos` | Ladrillos rotos |
| `powerups` | **Coleccionables** recogidos |
| `vidas` | Vidas restantes |
| `modo` | `normal` o `infinito` |
| `duracion_s` | **Tiempo** jugado (segundos) |
| `skin_bola`, `skin_pala` | Skins equipadas |
| `sesion` | Identificador de la partida (sirve para atribuir los eventos) |
| `fecha` | Fecha y hora local |

**`eventos`** — el registro de lo que hace el jugador

| Columna | Significado |
|---|---|
| `tipo` | `nivel_iniciado`, `nivel_superado`, `powerup`, `brick_especial`, `bola_perdida`, `multibola`, `escudo`, `pausa`, `juego_terminado`, `juego_completado`, `skin_equipada` |
| `detalle` | Texto libre (por ejemplo el power-up concreto) |
| `valor` | Número asociado (puntos, segundos, vidas…) |
| `nivel` | Nivel en el que ocurrió |

---

## 🔌 API REST

| Método | Ruta | Qué hace |
|---|---|---|
| `POST` | `/api/partidas` | Guarda una partida. Devuelve el **puesto** en la clasificación |
| `POST` | `/api/eventos` | Guarda uno o varios eventos (acepta lista) |
| `GET` | `/api/ranking?limite=10&modo=` | Mejor puntuación de cada jugador |
| `GET` | `/api/jugadores` | Todos los jugadores con sus totales |
| `GET` | `/api/jugadores/<nombre>` | Ficha completa de un jugador |
| `GET` | `/api/partidas?limite=50&jugador=&modo=` | Partidas guardadas |
| `GET` | `/api/eventos?limite=100&jugador=&tipo=` | Actividad registrada |
| `GET` | `/api/estadisticas` | Totales, eventos por tipo, partidas por día |
| `GET` | `/api/export.csv` | Exporta todas las partidas a CSV |
| `POST` | `/api/limpiar` | Vacía la base de datos (para pruebas) |

Prueba rápida sin abrir el juego:

```bash
curl "http://127.0.0.1:8000/api/estadisticas"
curl -X POST http://127.0.0.1:8000/api/partidas -H "Content-Type: application/json" ^
     -d "{\"jugador\":\"Prueba\",\"puntos\":9000,\"nivel\":10,\"racha\":25,\"ladrillos\":90,\"powerups\":6,\"duracion_s\":180,\"modo\":\"normal\"}"
```

---

## 🖥️ La interfaz web

Cinco pestañas que se actualizan solas cada 5 segundos:

1. **🏆 Clasificación** — podio + tabla con el mejor resultado de cada jugador.
2. **👤 Jugadores** — todo lo acumulado por persona (puntos, ladrillos, coleccionables, tiempo…). Se puede buscar y pinchar para ver su ficha.
3. **🕹️ Partidas** — cada partida con duración, vidas, skins y fecha. Filtros + **exportar CSV**.
4. **📋 Actividad** — el registro de eventos, filtrable por jugador y tipo.
5. **📊 Estadísticas** — tarjetas de totales, gráficos de barras (partidas por día, eventos por tipo) y rendimiento por nivel.

---

## 🔒 Notas de diseño

- **Validación en el servidor:** el juego no es de fiar (cualquiera puede modificarlo), así que el servidor recorta y valida todo: nombre de 16 caracteres máximo, puntos dentro de rango, tipos de evento permitidos, modo `normal`/`infinito`…
- **Sin inyección de HTML:** la web pinta los nombres con `textContent`, nunca `innerHTML`.
- **Sin pantallas bloqueadas:** si el servidor no responde, las peticiones tienen *timeout* de 5 segundos, el juego sigue y los envíos se reintentan después.
- **Sin librerías externas:** ni en Python (solo la librería estándar) ni en la web (nada de CDN).

> ⚠️ Al ser un sistema **local**, la clasificación no es a prueba de trampas: quien
> quiera podría enviar una puntuación falsa con `curl`. Para una práctica local es
> aceptable; blindarlo requeriría validar la partida en el servidor o firmar los
> resultados.

---

## 📦 Subir a GitHub (entrega)

```bash
git init
git add .
git commit -m "Práctica 4: Breakout Neon con base de datos, leaderboard y panel web"
git branch -M main
git remote add origin https://github.com/TU-USUARIO/breakout-neon-practica4.git
git push -u origin main
```

Antes de entregar, juega **un par de partidas** con el servidor encendido para que
`servidor/ranking.db` tenga datos y el profesor los vea al instante en la web.

El archivo `.gitignore` ya excluye la carpeta `.godot/` (caché del editor) y los
`.exe` exportados, que no hacen falta en el repositorio.