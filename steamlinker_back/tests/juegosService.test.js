// Cubre el helper compartido guardarJuego() (ver HANDOFF.md, tags de
// genero) -- el enriquecimiento real con la Steam Store API es
// best-effort/en segundo plano y depende de red externa, asi que no se
// prueba en vivo aqui (mismo criterio que el resto de la suite: nada de
// llamadas reales a Steam en los tests). Lo que si se cubre es que el
// helper guarda el juego y que la columna nueva existe con el shape
// esperado.
const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { pool } = require('./helpers');
const { guardarJuego } = require('../src/services/juegosService');

after(async () => {
    await pool.end();
});

test('guardarJuego inserta el juego si no existia, generos_jg arranca en null', async () => {
    const appid = 100000 + Math.floor(Math.random() * 100000);
    await guardarJuego({ appid, nombre: 'Juego de prueba juegosService', headerimg: null, capsuleimg: null });

    const fila = await pool.query('SELECT nom_jg, generos_jg FROM juegos WHERE appid = $1', [appid]);
    assert.equal(fila.rows.length, 1);
    assert.equal(fila.rows[0].nom_jg, 'Juego de prueba juegosService');
    assert.equal(fila.rows[0].generos_jg, null);

    await pool.query('DELETE FROM juegos WHERE appid = $1', [appid]);
});

test('guardarJuego no pisa un juego que ya existe', async () => {
    const appid = 200000 + Math.floor(Math.random() * 100000);
    await guardarJuego({ appid, nombre: 'Nombre original', headerimg: null, capsuleimg: null });
    await guardarJuego({ appid, nombre: 'Nombre que no deberia guardarse', headerimg: null, capsuleimg: null });

    const fila = await pool.query('SELECT nom_jg FROM juegos WHERE appid = $1', [appid]);
    assert.equal(fila.rows[0].nom_jg, 'Nombre original');

    await pool.query('DELETE FROM juegos WHERE appid = $1', [appid]);
});
