\# 🕹️ BREAKOUT NEON



Juego tipo Breakout en Godot 4 con mejoras de Game Feel / Juice, conectado a una base de datos SQLite, con clasificación (leaderboard) y una interfaz web local para consultar el rendimiento del jugador.



> \*\*Prácticas 4 y 5 — Base de Datos, Game Feel y Juice\*\*  

> Profesor: \*José Luis David Bonilla Carranza\*



\---



\## 🎯 Qué hace el proyecto



| Requisito | Cómo se cumple |

|---|---|

| \*\*Game Feel y Juice\*\* | Input buffering (0.15s), Coyote time en la paleta (16px Y / 18px X), screenshake dinámico por eventos y feedback audiovisual completo (squash \& stretch, textos flotantes, partículas y sonido procedural). |

| \*\*Conectar con base de datos\*\* | El juego envía cada partida y evento por HTTP + JSON a un servidor local en Python, que los almacena en SQLite (servidor/ranking.db). |

| \*\*Registro de actividad\*\* | Tabla partidas con resultados acumulados (puntos, nivel, racha, tiempo, skins) y tabla eventos con bitácora en tiempo real. |

| \*\*Leaderboard integrado\*\* | Pantalla RÉCORDS en el juego y pestaña Clasificación en la interfaz web. |

| \*\*Interfaz web local\*\* | Panel servido en http://127.0.0.1:8000 con pestañas de Clasificación, Jugadores, Partidas, Actividad y Estadísticas. |



\---



\## ✨ Práctica 5: Game Feel y Juice



Se implementaron y calibraron técnicas de respuesta táctil y retroalimentación para maximizar la satisfacción del jugador:



1\. \*\*Input Buffering (0.15 s):\*\*

&#x20;  - Registra de forma anticipada la pulsación de la tecla de lanzamiento (ESPACIO). Si el jugador presiona durante una transición de nivel o reinicio de bola, el juego retiene la acción y la ejecuta inmediatamente en cuanto entra en estado READY.

2\. \*\*Coyote Time (16 px en Y / 18 px en X):\*\*

&#x20;  - Ventana de tolerancia física en los bordes de la paleta. Si la pelota supera levemente la altura de impacto mientras va cayendo, el sistema valida un rebote límite si la paleta la alcanza en esa fracción de segundo, activando el aviso ¡RESCATE LÍMITE!.

3\. \*\*Screenshake Dinámico:\*\*

&#x20;  - Detonación de bloques bomba / habilidades de área: Amplitud 12.0 - 14.0, duración 0.40 s.

&#x20;  - Pérdida de bola / impacto de daño: Amplitud 9.0, duración 0.35 s.

&#x20;  - Hitos de combo (cada 5 impactos consecutivos): Micro-sacudida de amplitud 3.5, duración 0.15 s.

4\. \*\*Feedback Audiovisual (Juice):\*\*

&#x20;  - Animación elástica de compresión y estiramiento (squash \& stretch) en la paleta tras cada rebote.

&#x20;  - Textos flotantes dinámicos (popup) con desvanecimiento para combos, puntajes y estados especiales.

&#x20;  - Partículas explosivas mediante CPUParticles2D con gravedad y dispersión angular al fracturar bloques.

&#x20;  - Efectos sonoros completamente procedurales sintetizados en tiempo real por software (AudioStreamWAV), con modulación aleatoria de tono (pitch).



\---



\## 🚀 Cómo se arranca



\### 1. El servidor (necesario para guardar datos)



Comando en terminal:

cd servidor

python servidor.py



No requiere librerías externas: funciona con la librería estándar de Python 3.8+. Al iniciar crea automáticamente la base de datos servidor/ranking.db si no existe.



\### 2. El juego



Abre el proyecto con Godot 4 y presiona F5 (la escena principal es scenes/menu.tscn).



Si el servidor está apagado el juego funciona con normalidad: los resultados se almacenan en user://envios\_pendientes.json y se sincronizan solos al reanudar la conexión.



\### 3. La interfaz web



Con el servidor corriendo, entra desde tu navegador a:

http://127.0.0.1:8000



\---



\## 🗂️ Estructura del proyecto



\- project.godot

\- scenes/

&#x20; - menu.tscn (Portada: JUGAR, MODO INFINITO, ARMARIO, RÉCORDS)

&#x20; - main.tscn (Partida y juego principal)

&#x20; - ball.tscn (Bola con físicas y coyote time)

&#x20; - paddle.tscn (Paleta reactiva con deformación)

\- scripts/

&#x20; - ball.gd (Físicas, skins y rescate límite)

&#x20; - paddle.gd (Movimiento, amortiguación y squash)

&#x20; - main.gd (Ciclo de juego, combos e input buffering)

&#x20; - vfx.gd (Screenshake, partículas y textos flotantes)

&#x20; - sfx.gd (Generador procedural de sonido)

&#x20; - leaderboard.gd (Cliente HTTP para la base de datos)

&#x20; - skin\_catalog.gd (Configuración y catálogo de skins)

\- servidor/

&#x20; - servidor.py (API REST + SQLite + servidor web local)

&#x20; - ranking.db (Base de datos SQLite)

&#x20; - web/ (Archivos del tablero web: HTML, CSS y JS)



\---



\## 🗄️ Base de datos



Dos tablas en ranking.db:



\- \*\*partidas\*\*: Almacena jugador, puntos, nivel, racha, ladrillos, powerups, vidas, modo, duracion\_s, skin\_bola, skin\_pala, sesion, fecha.

\- \*\*eventos\*\*: Bitácora de acciones con tipo, detalle, valor, nivel.

