# Estadísticas de jugadores

## Uso

1. Abre una terminal en `servidor` y ejecuta `python servidor.py`.
2. Importa `project.godot` en Godot 4.7 y ejecuta el juego.
3. Abre http://127.0.0.1:8000 y entra en **Estadísticas**.
4. Selecciona niveles o infinito, filtra por jugador y pulsa **Consultar** después de jugar.
5. Pulsa una barra para ver los intentos de ese nivel. El selector del visor permite elegir otro intento. Usa reproducir y la línea de tiempo para explorar sus muestras.

El servidor debe permanecer encendido durante el juego. El juego conserva su cola anterior de resultados pendientes; las muestras de recorrido no se recuperan si el servidor estaba apagado. Las partidas anteriores conservan sus tablas y estadísticas originales, pero no se inventan recorridos ni tiempos por nivel para ellas.

## Datos nuevos

- Intentos, victorias, derrotas, salidas/reinicios y sesiones sin cierre por nivel y modo.
- Tiempo activo acumulado y medio: solo cuenta mientras la bola está en juego; excluye pausa, espera de lanzamiento y transiciones.
- Vidas perdidas y habilidades recogidas por intento.
- Repetición: nombres identificados con al menos dos partidas medidas, como indicador exploratorio de interés. No equivale a retención diaria y los nombres no son identidades verificadas.
- Tablero inicial exacto, tema y semilla de cada intento. No se vuelve a generar el nivel en JavaScript: se guarda la matriz producida por Godot, también en infinito.
- Posición de hasta ocho bolas y de la pala cada 0.5 segundos activos. Trayectorias aproximadas, reproducción y mapa de densidad de muestras. El tablero dibujado conserva los ladrillos iniciales; no reproduce su destrucción.

Las habilidades activadas desde las teclas 0–9 marcan el intento como prueba. Se ocultan del laboratorio por defecto; **Incluir habilidades de prueba** permite inspeccionarlos. La clasificación original sigue mostrando los resultados enviados, incluyendo pruebas. La marca ayuda a depurar los análisis y no es un sistema antitrampas.

Los agregados cubren todos los intentos medidos que coinciden con los filtros. El visor ofrece los 100 más recientes y limita el muestreo a unas 2,000 posiciones por intento largo. No se interpreta una sesión sin cierre como derrota o abandono confirmado. Las partidas iniciadas desde un nivel superior no se cuentan como visitas a niveles anteriores.

## Score de Nayeli

En la base de datos entregada, el registro de Nayeli (id 5) pasó de 19,880 puntos a 0. Se conservaron eventos y otras estadísticas. `servidor/ranking_antes_reset_nayeli.db` es el respaldo previo y `servidor/reset_nayeli.json` documenta el cambio. El ZIP original permanece intacto. El récord local guardado por Godot en `user://` no se modificó.

## Verificación

Godot 4.7.2: importación del proyecto y arranque de la escena principal en modo headless sin errores. Sintaxis de JavaScript y Python comprobada. Pruebas: `cd servidor` y `python -m unittest test_analitica -v` (tres casos). La vista previa del navegador no se pudo comprobar por un fallo de conexión local del entorno de trabajo.
