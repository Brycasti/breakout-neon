'use strict';
(() => {
 const root = document.createElement('div');
 root.innerHTML = `<div class="barra"><h2>Laboratorio de jugadores</h2><div class="controles"><label>Modo <select id="a-modo"><option value="normal">Niveles seleccionables</option><option value="infinito">Infinito</option></select></label><label>Jugador <input id="a-jugador" type="search" placeholder="Todos"></label><label><input id="a-pruebas" type="checkbox"> Incluir habilidades de prueba</label><button id="a-cargar" class="boton-mini">Consultar</button></div></div>
 <p class="nota">Tiempo activo: solo mientras la bola está en juego. Las partidas anteriores no tienen recorrido. Las sesiones sin cierre pueden seguir en juego o haberse interrumpido. «Vuelven a jugar» cuenta nombres con dos o más partidas medidas; no representa retención diaria. Se muestran los 100 intentos más recientes en el visor.</p>
 <div id="a-resumen" class="tarjetas"></div><article class="caja"><h3>Actividad por nivel</h3><p class="nota">Tiempo acumulado por escenario. Selecciona una barra para explorar sus intentos.</p><div id="a-barras"></div></article>
 <article class="caja"><h3>Curva de dificultad</h3><div class="tabla-envoltura"><table><thead><tr><th>Nivel</th><th>Intentos</th><th>Victoria</th><th>Derrotas</th><th>Salidas / reinicios</th><th>Sin cierre</th><th>Tiempo activo medio</th><th>Vidas perdidas / intento</th><th>Habilidades / intento</th></tr></thead><tbody id="a-tabla"></tbody></table></div></article>
 <article class="caja"><div class="barra"><div><h3>Cartografía de la partida</h3><p id="a-info" class="nota"></p></div><label>Intento <select id="a-intento"></select></label></div><div class="controles"><label><input id="a-ruta" type="checkbox" checked> Trayectoria de la bola principal</label><label><input id="a-calor" type="checkbox"> Densidad de muestras</label><button id="a-play" class="boton-mini">▶ Reproducir</button></div><canvas id="a-mapa" width="1280" height="720" aria-label="Distribución real de ladrillos y trayectoria de bolas" role="img"></canvas><div class="a-timeline"><span id="a-tiempo">0 s</span><input id="a-slider" type="range" min="0" max="0" value="0" aria-label="Momento de la partida"></div><p class="nota">Tablero inicial exacto guardado por Godot · Cian: bola principal · Blanco: bolas adicionales · Verde: pala · La muestra cada 0.5 s aproxima el recorrido; los ladrillos muestran su estado inicial.</p></article><p id="a-error" role="status"></p>`;
 document.getElementById('vista-estadisticas').prepend(root);
 const $ = id => document.getElementById('a-' + id);
 const themes=['#3366e6','#1acc80','#e6801a','#cc3366','#991acc','#33b3cc'];
 const colors={1:'#4fd6ff',2:'#6bf279',3:'#ffe066',4:'#ff9e42',5:'#ff5ec4',X:'#ff271a',G:'#fff21a',M:'#b3bfc9'};
 let data={intentos:[]}, selected=null, timer=null;
 const fmt=s=>`${Math.round(s || 0)} s`;
 function node(tag,text,cls){const n=document.createElement(tag); n.textContent=text;if(cls)n.className=cls;return n;}
 async function load(){
  try {
   const q=new URLSearchParams({modo:$('modo').value,jugador:$('jugador').value,pruebas:$('pruebas').checked?'1':'0'});
   data=await pedir('/api/analitica?'+q); $('error').textContent='';
   $('resumen').replaceChildren(...[
    ['Intentos medidos',data.total_intentos],['Sesiones',data.sesiones],['Jugadores',data.jugadores],
    ['Vuelven a jugar',`${data.recurrentes} / ${data.identificados} identificados`]
   ].map(([k,v])=>{const n=node('div','','tarjeta');n.append(node('div',k,'titulo'),node('div',v,'valor'));return n;}));
   const max=Math.max(1,...data.niveles.map(n=>n.tiempo));
   $('barras').replaceChildren(...data.niveles.map(n=>{
    const b=node('button','','a-columna');b.style.setProperty('--tema',themes[(n.nivel-1)%6]);
    b.append(node('span',`N${n.nivel.toString().padStart(2,'0')}`));
    const bar=node('i','');bar.style.height=`${n.tiempo/max*130}px`;b.append(bar,node('strong',n.tema),node('span',fmt(n.tiempo)));
    b.title=`${n.intentos} intentos · ${n.victorias} victorias`;b.onclick=()=>options(n.nivel);return b;
   }));
   if(!data.niveles.length)$('barras').textContent='Aún no hay intentos medidos con estos filtros. Juega con esta versión de Godot para registrar datos.';
   $('tabla').replaceChildren(...data.niveles.map(n=>{const tr=document.createElement('tr');
    [`${n.nivel} · ${n.tema}`,n.intentos,`${(n.victorias/n.intentos*100).toFixed(0)}% (${n.victorias})`,n.derrotas,n.salidas,n.sin_cierre,fmt(n.tiempo/n.intentos),(n.perdidas/n.intentos).toFixed(1),(n.habilidades/n.intentos).toFixed(1)].forEach(v=>tr.append(node('td',v)));return tr;}));
   options();
  }catch(e){$('error').textContent='No se pudo consultar la analítica: '+e.message;}
 }
 function options(level){
  stop();const list=data.intentos.filter(a=>!level || a.nivel===level).slice().reverse();
  $('intento').replaceChildren(...list.map(a=>{const n=node('option',`${a.jugador} · N${a.nivel} · intento ${a.intento} · ${a.resultado} · ${a.fecha}${a.prueba?' · PRUEBA':''}`);n.value=data.intentos.indexOf(a);return n;}));
  choose();
 }
 function choose(){stop();selected=$('intento').value===''?null:data.intentos[Number($('intento').value)];
  $('slider').max=Math.max(0,(selected?.muestras.length || 0)-1);$('slider').value='0';
  $('info').textContent=selected?`${selected.tema} · semilla ${selected.semilla} · ${selected.muestras.length} muestras · ${fmt(selected.tiempo)} activos`:'Selecciona un intento con telemetría para ver su tablero real.';draw();}
 function stop(){clearInterval(timer);timer=null;$('play').textContent='▶ Reproducir';}
 function draw(){
  const c=$('mapa').getContext('2d');c.fillStyle='#080e20';c.fillRect(0,0,1280,720);
  c.strokeStyle='#17233e';c.lineWidth=1;for(let x=0;x<=1280;x+=64){c.beginPath();c.moveTo(x,0);c.lineTo(x,720);c.stroke();}for(let y=0;y<=720;y+=32){c.beginPath();c.moveTo(0,y);c.lineTo(1280,y);c.stroke();}
  if(!selected){c.fillStyle='#a9b8d5';c.font='24px sans-serif';c.fillText('Sin telemetría para estos filtros',420,360);return;}
  c.strokeStyle=themes[(selected.nivel-1)%6];c.lineWidth=4;c.strokeRect(16,16,1248,688);
  (selected.layout || []).forEach((row,r)=>[...row].forEach((ch,col)=>{if(ch==='.')return;c.fillStyle=colors[ch]||'#fff';c.fillRect(128+col*64+2,96+r*32+2,60,28);if('XGM'.includes(ch)){c.fillStyle='#111827';c.font='bold 15px sans-serif';c.fillText(ch,151+col*64,117+r*32);}}));
  const samples=selected.muestras.slice(0,Number($('slider').value)+1), last=samples.at(-1);
  if($('calor').checked){const bins=new Map();for(const s of samples)for(const b of s.bolas || []){const key=`${Math.floor(b[0]/32)},${Math.floor(b[1]/32)}`;bins.set(key,(bins.get(key)||0)+1);}const max=Math.max(1,...bins.values());for(const [key,v]of bins){const [x,y]=key.split(',').map(Number);c.fillStyle=`rgba(255,130,60,${0.15+v/max*0.6})`;c.fillRect(x*32,y*32,32,32);}}
  if($('ruta').checked){c.strokeStyle='#65dfff';c.lineWidth=2;c.beginPath();let started=false;for(const s of samples){const b=s.bolas?.[0];if(!b)continue;if(started)c.lineTo(...b);else{c.moveTo(...b);started=true;}}c.stroke();}
  if(last){(last.bolas || []).forEach((b,i)=>{c.beginPath();c.fillStyle=i?'#ffffff':'#65dfff';c.arc(b[0],b[1],7,0,Math.PI*2);c.fill();});c.fillStyle='#7af5b1';const w=last.ancho || 120;c.fillRect(last.pala-w/2,(last.pala_y || 660)-12,w,24);}
  $('tiempo').textContent=fmt(last?.t);
 }
 $('cargar').onclick=load;$('modo').onchange=load;$('pruebas').onchange=load;$('intento').onchange=choose;
 $('slider').oninput=()=>{stop();draw();};$('ruta').onchange=draw;$('calor').onchange=draw;
 $('play').onclick=()=>{if(timer){stop();return;}if(!selected?.muestras.length)return;if(Number($('slider').value)>=Number($('slider').max))$('slider').value='0';$('play').textContent='Ⅱ Pausar';timer=setInterval(()=>{if(Number($('slider').value)>=Number($('slider').max)){stop();return;}$('slider').value=Number($('slider').value)+1;draw();},100);};
 document.querySelector('[data-vista="estadisticas"]').addEventListener('click',load);
 $('mapa').style.width='100%';load();
})();
