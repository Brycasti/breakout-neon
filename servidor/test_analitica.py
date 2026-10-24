import json
from pathlib import Path
import tempfile
import unittest
import servidor as s


class AnaliticaTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.original = s.RUTA_BD
        s.RUTA_BD = str(Path(self.tmp.name) / 'test.db')

    def tearDown(self):
        s.RUTA_BD = self.original
        self.tmp.cleanup()

    def evento(self, clase, **kwargs):
        return {'tipo': 'telemetria', 'sesion': 'test', 'nivel': 3,
                'payload': dict(clase=clase, intento=1, nivel=3, **kwargs)}

    def test_layout_time_mode_and_debug(self):
        s.guardar_eventos([
            self.evento('inicio', modo='infinito', layout=['1.GM'], tema='DESIERTO CRISTAL', semilla=42),
            self.evento('muestra', t=12, bolas=[[400, 300]], pala=500),
            self.evento('fin', t=18, resultado='victoria'),
        ])
        self.assertEqual(s.consultar_analitica('normal')['total_intentos'], 0)
        a = s.consultar_analitica('infinito')
        self.assertEqual(a['niveles'][0]['tiempo'], 18)
        self.assertEqual(a['niveles'][0]['victorias'], 1)
        self.assertEqual(a['intentos'][0]['layout'], ['1.GM'])
        s.guardar_eventos([self.evento('muestra', t=18, prueba=True)])
        self.assertEqual(s.consultar_analitica('infinito')['total_intentos'], 0)
        self.assertEqual(s.consultar_analitica('infinito', pruebas=True)['total_intentos'], 1)

    def test_late_player_attribution_and_missing_end(self):
        s.guardar_eventos([self.evento('inicio', modo='normal'), self.evento('muestra', t=8)])
        s.guardar_partida({'jugador': 'Test', 'sesion': 'test', 'puntos': 10})
        a = s.consultar_analitica('normal', jugador='test')
        self.assertEqual(a['total_intentos'], 1)
        self.assertEqual(a['intentos'][0]['jugador'], 'Test')
        self.assertEqual(a['niveles'][0]['sin_cierre'], 1)
        self.assertEqual(a['niveles'][0]['derrotas'], 0)

    def test_old_database_migration(self):
        con = s.sqlite3.connect(s.RUTA_BD)
        con.executescript(s.SQL_TABLAS)
        con.close()
        con = s.abrir_bd()
        self.assertIn('payload', [r[1] for r in con.execute('PRAGMA table_info(eventos)')])
        con.close()


if __name__ == '__main__':
    unittest.main()
