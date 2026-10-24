/* =======================================================================
   BREAKOUT NEON · panel de consulta de la base de datos
   -----------------------------------------------------------------------
   Consume la API REST del servidor (servidor.py) y pinta las tablas.
   Sin librerías externas: solo fetch + DOM (funciona 100% en local).
   ======================================================================= */

'use strict';

const REFRESCO_MS = 5000;          // auto-actualización
let vistaActual = 'ranking';
let detalleAbierto = null;         // nombre del jugador en la ficha, si la hay
let temporizador = null;

/* ----------------------------------------------------------------------
   Utilidades
   ---------------------------------------------------------------------- */

/** Pide una ruta de la API y devuelve el JSON (lanza si falla). */
async function pedir(ruta) {
	const respuesta = await fetch(ruta);
	if (!respuesta.ok) throw new Error('HTTP ' + respuesta.status);
	return respuesta.json();
}

/** Actualiza el indicador de conexión de la cabecera. */
function marcarEstado(ok, mensaje) {
	const punto = document.getElementById('punto-estado');
	punto.className = 'punto ' + (ok ? 'ok' : 'malo');
	document.getElementById('texto-estado').textContent = mensaje;
	if (ok) {
		document.getElementById('hora-actualizacion').textContent =
			'· ' + new Date().toLocaleTimeString('es-MX');
	}
}

const numero = (n) => Number(n || 0).toLocaleString('es-MX');

function duracion(segundos) {
	const s = Math.round(Number(segundos) || 0);
	if (s < 60) return s + ' s';
	const m = Math.floor(s / 60);
	if (m < 60) return m + ' min ' + (s % 60) + ' s';
	return Math.floor(m / 60) + ' h ' + (m % 60) + ' min';
}

/** Crea una celda <td> con texto seguro (textContent evita inyección HTML). */
function celda(texto, clase) {
	const td = document.createElement('td');
	td.textContent = texto;
	if (clase) td.className = clase;
	return td;
}

/** Fila de "no hay datos" que ocupa toda la tabla. */
function filaVacia(tabla, mensaje, columnas) {
	const tr = document.createElement('tr');
	const td = document.createElement('td');
	td.textContent = mensaje;
	td.className = 'vacio';
	td.colSpan = columnas || 12;
	tr.appendChild(td);
	const tbody = tabla.querySelector('tbody');
	tbody.replaceChildren(tr);
}

/** Reemplaza el contenido de un tbody conservando la posición de scroll. */
function pintarFilas(tabla, filas) {
	const envoltura = tabla.closest('.tabla-envoltura');
	const scroll = envoltura ? envoltura.scrollTop : 0;
	const tbody = tabla.querySelector('tbody');
	tbody.replaceChildren(...filas);
	if (envoltura) envoltura.scrollTop = scroll;
}

function escuchar(tabla, manejadorFila) {
	tabla.querySelector('tbody').addEventListener('click', (evento) => {
		const fila = evento.target.closest('tr');
		if (!fila || fila.dataset.jugador === undefined) return;
		manejadorFila(fila.dataset.jugador);
	});
}

/* ----------------------------------------------------------------------
   Vistas
   ---------------------------------------------------------------------- */

async function cargarRanking() {
	const modo = document.getElementById('ranking-modo').value;
	const limite = document.getElementById('ranking-limite').value;
	const filas = await pedir(`/api/ranking?limite=${limite}&modo=${modo}`);
	const tabla = document.getElementById('tabla-ranking');

	if (!filas.length) {
		document.getElementById('podio').replaceChildren();
		return filaVacia(tabla, 'Todavía no hay partidas guardadas. ¡Juega una!', 8);
	}

	// --- podio con los tres primeros ---
	const medallas = ['🥇', '🥈', '🥉'];
	const podio = document.getElementById('podio');
	podio.replaceChildren(...filas.slice(0, 3).map((f, i) => {
		const div = document.createElement('div');
		div.className = 'puesto' + (i === 0 ? ' top1' : '');
		const medalla = document.createElement('div');
		medalla.className = 'medalla';
		medalla.textContent = medallas[i];
		const quien = document.createElement('div');
		quien.className = 'quien';
		quien.textContent = f.jugador;
		const cuanto = document.createElement('div');
		cuanto.className = 'cuanto';
		cuanto.textContent = numero(f.puntos) + ' pts';
		const extra = document.createElement('div');
		extra.className = 'extra';
		extra.textContent = `nivel ${f.nivel} · racha ${f.racha} · ${f.partidas} partida(s)`;
		div.append(medalla, quien, cuanto, extra);
		return div;
	}));

	// --- tabla completa ---
	pintarFilas(tabla, filas.map((f, i) => {
		const tr = document.createElement('tr');
		tr.className = 'clicable';
		tr.dataset.jugador = f.jugador;
		tr.append(
			celda(i + 1, 'numero'),
			celda(f.jugador, 'nombre'),
			celda(numero(f.puntos), 'numero'),
			celda(f.nivel),
			celda(f.racha),
			celda(f.partidas),
			celda(numero(Math.round(f.media * 10) / 10)),
			celda(f.ultima, 'apagado'),
		);
		return tr;
	}));
}

async function cargarJugadores() {
	const filas = await pedir('/api/jugadores');
	const tabla = document.getElementById('tabla-jugadores');
	const filtro = document.getElementById('buscar-jugador').value.trim().toLowerCase();
	const visibles = filas.filter((f) => f.jugador.toLowerCase().includes(filtro));

	if (!visibles.length) return filaVacia(tabla, 'Sin jugadores que mostrar.', 10);

	pintarFilas(tabla, visibles.map((f) => {
		const tr = document.createElement('tr');
		tr.className = 'clicable';
		tr.dataset.jugador = f.jugador;
		tr.append(
			celda(f.jugador, 'nombre'),
			celda(numero(f.puntos), 'numero'),
			celda(f.nivel),
			celda(f.racha),
			celda(f.partidas),
			celda(numero(f.ladrillos)),
			celda(numero(f.powerups)),
			celda(duracion(f.tiempo_s)),
			celda(numero(f.eventos)),
			celda(f.ultima, 'apagado'),
		);
		return tr;
	}));
}

async function cargarPartidas() {
	const jugador = document.getElementById('buscar-partida').value.trim();
	const modo = document.getElementById('partidas-modo').value;
	const filas = await pedir(`/api/partidas?limite=200&jugador=${encodeURIComponent(jugador)}&modo=${modo}`);
	const tabla = document.getElementById('tabla-partidas');

	if (!filas.length) return filaVacia(tabla, 'Sin partidas guardadas todavía.', 12);

	pintarFilas(tabla, filas.map((p) => {
		const tr = document.createElement('tr');
		tr.dataset.jugador = p.jugador;
		const modoCelda = document.createElement('td');
		const etiqueta = document.createElement('span');
		etiqueta.className = 'etiqueta' + (p.modo === 'infinito' ? ' infinito' : '');
		etiqueta.textContent = p.modo;
		modoCelda.appendChild(etiqueta);
		tr.append(
			celda(p.id, 'numero'),
			celda(p.jugador, 'nombre'),
			celda(numero(p.puntos), 'numero'),
			celda(p.nivel),
			modoCelda,
			celda(duracion(p.duracion_s)),
			celda(p.vidas),
			celda(numero(p.ladrillos)),
			celda(numero(p.powerups)),
			celda(p.skin_bola, 'apagado'),
			celda(p.skin_pala, 'apagado'),
			celda(p.fecha, 'apagado'),
		);
		return tr;
	}));
}

async function cargarEventos() {
	const jugador = document.getElementById('buscar-evento').value.trim();
	const tipo = document.getElementById('eventos-tipo').value;
	const filas = await pedir(`/api/eventos?limite=200&jugador=${encodeURIComponent(jugador)}&tipo=${tipo}`);
	const tabla = document.getElementById('tabla-eventos');

	if (!filas.length) return filaVacia(tabla, 'Sin actividad registrada todavía.', 7);

	pintarFilas(tabla, filas.map((e) => {
		const tr = document.createElement('tr');
		tr.dataset.jugador = e.jugador;
		const tipoCelda = document.createElement('td');
		const etiqueta = document.createElement('span');
		etiqueta.className = 'etiqueta';
		etiqueta.textContent = e.tipo;
		tipoCelda.appendChild(etiqueta);
		tr.append(
			celda(e.id, 'numero'),
			celda(e.jugador, 'nombre'),
			tipoCelda,
			celda(e.detalle),
			celda(e.valor),
			celda(e.nivel),
			celda(e.fecha, 'apagado'),
		);
		return tr;
	}));
}

async function cargarEstadisticas() {
	const datos = await pedir('/api/estadisticas');
	const p = datos.partidas || {};

	const tarjetas = [
		['Partidas jugadas', numero(p.partidas)],
		['Jugadores distintos', numero(p.jugadores)],
		['Mejor puntuación', numero(p.mejor), 'récord absoluto'],
		['Puntuación media', numero(Math.round(p.media * 10) / 10)],
		['Mejor racha', numero(p.mejor_racha), 'ladrillos seguidos'],
		['Ladrillos rotos', numero(p.ladrillos), 'entre todos'],
		['Coleccionables', numero(p.powerups), 'power-ups recogidos'],
		['Tiempo total jugado', duracion(p.tiempo_s), 'suma de partidas'],
		['Eventos registrados', numero(datos.eventos_totales)],
	];

	document.getElementById('tarjetas-estadisticas').replaceChildren(
		...tarjetas.map(([titulo, valor, pista]) => {
			const div = document.createElement('div');
			div.className = 'tarjeta';
			const t = document.createElement('div');
			t.className = 'titulo';
			t.textContent = titulo;
			const v = document.createElement('div');
			v.className = 'valor';
			v.textContent = valor;
			div.append(t, v);
			if (pista) {
				const pi = document.createElement('div');
				pi.className = 'pista';
				pi.textContent = pista;
				div.appendChild(pi);
			}
			return div;
		}),
	);

	// Barras por día
	const dias = (datos.por_dia || []).slice(-10);
	const maxDia = Math.max(1, ...dias.map((d) => d.partidas));
	const graficoDias = document.getElementById('grafico-dias');
	if (!dias.length) {
		graficoDias.textContent = 'Sin datos.';
	} else {
		graficoDias.replaceChildren(...dias.map((d) => barra(d.dia, d.partidas, maxDia)));
	}

	// Barras por tipo de evento
	const tipos = datos.eventos_por_tipo || [];
	const maxTipo = Math.max(1, ...tipos.map((t) => t.veces));
	const graficoTipos = document.getElementById('grafico-eventos');
	if (!tipos.length) {
		graficoTipos.textContent = 'Sin eventos registrados.';
	} else {
		graficoTipos.replaceChildren(...tipos.map((t) => barra(t.tipo, t.veces, maxTipo)));
	}

	// Tabla por nivel alcanzado
	const tabla = document.getElementById('tabla-niveles');
	const niveles = datos.niveles || [];
	if (!niveles.length) {
		filaVacia(tabla, 'Sin partidas.', 3);
	} else {
		pintarFilas(tabla, niveles.map((n) => {
			const tr = document.createElement('tr');
			tr.append(celda(n.nivel, 'numero'), celda(n.veces), celda(numero(n.mejor), 'numero'));
			return tr;
		}));
	}
}

/** Una fila del gráfico de barras (hecha con CSS, sin librerías). */
function barra(etiqueta, valor, maximo) {
	const fila = document.createElement('div');
	fila.className = 'barra-fila';
	const texto = document.createElement('span');
	texto.textContent = etiqueta;
	const fondo = document.createElement('div');
	fondo.className = 'barra-fondo';
	const relleno = document.createElement('div');
	relleno.className = 'barra-relleno';
	relleno.style.width = Math.max(3, (valor / maximo) * 100) + '%';
	fondo.appendChild(relleno);
	const cifra = document.createElement('span');
	cifra.textContent = valor;
	fila.append(texto, fondo, cifra);
	return fila;
}

/* ----------------------------------------------------------------------
   Ficha detallada de un jugador
   ---------------------------------------------------------------------- */

async function cargarDetalle(nombre) {
	detalleAbierto = nombre;
	const datos = await pedir('/api/jugadores/' + encodeURIComponent(nombre));
	const r = datos.resumen || {};

	document.getElementById('detalle-titulo').textContent = '👤 ' + datos.jugador;
	document.getElementById('detalle-resumen').replaceChildren(
		...[
			['Partidas', numero(r.partidas)],
			['Mejor puntuación', numero(r.puntos)],
			['Nivel máximo', numero(r.nivel)],
			['Mejor racha', numero(r.racha)],
			['Puntuación media', numero(Math.round(r.media * 10) / 10)],
			['Ladrillos rotos', numero(r.ladrillos)],
			['Coleccionables', numero(r.powerups)],
			['Tiempo jugado', duracion(r.tiempo_s)],
		].map(([titulo, valor]) => {
			const div = document.createElement('div');
			div.className = 'tarjeta';
			const t = document.createElement('div');
			t.className = 'titulo';
			t.textContent = titulo;
			const v = document.createElement('div');
			v.className = 'valor';
			v.textContent = valor;
			div.append(t, v);
			return div;
		}),
	);

	const tablaPartidas = document.getElementById('detalle-partidas');
	if (!datos.partidas.length) {
		filaVacia(tablaPartidas, 'Sin partidas.', 5);
	} else {
		pintarFilas(tablaPartidas, datos.partidas.map((p) => {
			const tr = document.createElement('tr');
			tr.append(
				celda(numero(p.puntos), 'numero'),
				celda(p.nivel),
				celda(p.modo),
				celda(duracion(p.duracion_s)),
				celda(p.fecha, 'apagado'),
			);
			return tr;
		}));
	}

	const tablaEventos = document.getElementById('detalle-eventos');
	if (!datos.eventos.length) {
		filaVacia(tablaEventos, 'Sin eventos.', 2);
	} else {
		pintarFilas(tablaEventos, datos.eventos.map((e) => {
			const tr = document.createElement('tr');
			tr.append(celda(e.tipo), celda(e.veces, 'numero'));
			return tr;
		}));
	}

	document.querySelectorAll('.vista').forEach((v) => v.classList.remove('activa'));
	document.getElementById('detalle-jugador').classList.add('activa');
	window.scrollTo({ top: 0, behavior: 'smooth' });
}

/* ----------------------------------------------------------------------
   Navegación, filtros y auto-actualización
   ---------------------------------------------------------------------- */

const CARGADORES = {
	'ranking': cargarRanking,
	'jugadores': cargarJugadores,
	'partidas': cargarPartidas,
	'eventos': cargarEventos,
	'estadisticas': cargarEstadisticas,
};

async function refrescarVista(nombre) {
	try {
		const datos = await CARGADORES[nombre]();
		marcarEstado(true, 'conectado a la base de datos');
		return datos;
	} catch (error) {
		marcarEstado(false, 'sin conexión con el servidor (' + error.message + ')');
	}
}

function mostrarVista(nombre) {
	detalleAbierto = null;
	vistaActual = nombre;
	document.querySelectorAll('.vista').forEach((v) => v.classList.remove('activa'));
	document.getElementById('vista-' + nombre).classList.add('activa');
	document.querySelectorAll('.pestana').forEach((p) =>
		p.classList.toggle('activa', p.dataset.vista === nombre));
	refrescarVista(nombre);
}

function refrescarTodo() {
	if (detalleAbierto) cargarDetalle(detalleAbierto).catch(() => {});
	refrescarVista(vistaActual);
}

function conectarEventos() {
	document.querySelectorAll('.pestana').forEach((pestana) =>
		pestana.addEventListener('click', () => mostrarVista(pestana.dataset.vista)));

	document.getElementById('boton-actualizar').addEventListener('click', refrescarTodo);
	document.getElementById('ranking-modo').addEventListener('change', cargarRanking);
	document.getElementById('ranking-limite').addEventListener('change', cargarRanking);
	document.getElementById('partidas-modo').addEventListener('change', cargarPartidas);
	document.getElementById('eventos-tipo').addEventListener('change', cargarEventos);
	document.getElementById('buscar-jugador').addEventListener('input', cargarJugadores);
	document.getElementById('buscar-partida').addEventListener('input', cargarPartidas);
	document.getElementById('buscar-evento').addEventListener('input', cargarEventos);
	document.getElementById('cerrar-detalle').addEventListener('click', () => mostrarVista(vistaActual));

	escuchar(document.getElementById('tabla-ranking'), cargarDetalle);
	escuchar(document.getElementById('tabla-jugadores'), cargarDetalle);
	escuchar(document.getElementById('tabla-partidas'), cargarDetalle);
	escuchar(document.getElementById('tabla-eventos'), cargarDetalle);
}

window.addEventListener('DOMContentLoaded', () => {
	conectarEventos();
	mostrarVista('ranking');
	// Auto-actualización: así ves en directo las partidas que van llegando.
	temporizador = setInterval(refrescarTodo, REFRESCO_MS);
	// Si la pestaña deja de verse, no gastamos peticiones.
	document.addEventListener('visibilitychange', () => {
		if (document.hidden) {
			clearInterval(temporizador);
		} else {
			refrescarTodo();
			temporizador = setInterval(refrescarTodo, REFRESCO_MS);
		}
	});
});