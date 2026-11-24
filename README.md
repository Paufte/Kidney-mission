# KIDNEY MISSION

Una decisió pot salvar una vida · Una decisión puede salvar una vida.

Videojuego educativo y divulgativo sobre la donación y el trasplante renal, pensado para móviles, en catalán y castellano. Casos y personajes ficticios; el contenido no sustituye el consejo de profesionales sanitarios.

- Inicio (QR maestro): https://paufte.github.io/Kidney-mission/
- Juego: `joc.html` (`#ca` o `#es` para fijar idioma)
- Ranking en directo (pantalla del stand): `ranking.html`
- Configuración de Supabase: `config.js`
- Tarjeta y PDF: carpeta `media/`

## Registro de jugadores (concurso)

Antes de jugar se pide nombre, dos apellidos, correo y consentimiento. Cada partida guarda hora de inicio, hora de fin y puntuación en la tabla privada `registros` de Supabase (la clave pública solo puede llamar a `km_registrar` y `km_finalizar`, no leer datos). El ranking público (`scores`) solo muestra "Nombre I." y la puntuación.

- SQL: `supabase-registro.sql` (pegar en Supabase > SQL Editor y ejecutar).
- Ver los datos: Supabase > Table Editor > vista `registros_clasificacion` (ganador: mejor partida por correo) o `registros_partidas` (todas). Botón "Export > CSV" para descargarlo.
