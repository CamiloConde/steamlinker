// Cubre la reimportación periódica de bibliotecas de Steam (ver
// HANDOFF.md, "importación automática de biblioteca") -- pedido
// explícito del usuario: antes, comprar un juego nuevo no se reflejaba
// en la app hasta tocar "Importar biblioteca" a mano.
const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');
const perfilRoutes = require('../src/routes/perfil');

let username;

after(async () => {
    if (username) await limpiarUsuario(username);
    await pool.end();
});

test('reimportarTodasLasBibliotecas no revienta con una cuenta Steam invalida, y no la marca como reimportada', async () => {
    username = usernameUnico('test_reimport');
    const reg = await request(app).post('/auth/registro').send({
        username,
        email: `${username}@example.com`,
        password: 'Passw0rd123',
    });
    const idUsu = reg.body.usuario.id;

    // steamid con formato válido (17 dígitos) pero que no corresponde a
    // ninguna cuenta real -- getUserProfile debe fallar con "Usuario no
    // encontrado" para esta, sin tumbar el resto del lote.
    const steamidFalso = '76561190000000001';
    await pool.query(
        `INSERT INTO perfiles_steam (id_usu, steam_id, username_steperfil, avatar_url, perfil_url)
         VALUES ($1, $2, 'Test Reimport', null, null)`,
        [idUsu, steamidFalso]
    );

    const resultado = await perfilRoutes.reimportarTodasLasBibliotecas();

    assert.equal(typeof resultado.total, 'number');
    assert.equal(typeof resultado.ok, 'number');
    assert.equal(typeof resultado.fallidas, 'number');
    assert.equal(resultado.ok + resultado.fallidas, resultado.total);

    // La cuenta invalida no debe haber quedado marcada como reimportada
    // -- solo se estampa la fecha si la importacion realmente funciono.
    const fila = await pool.query(
        `SELECT ultima_importacion_steperfil FROM perfiles_steam WHERE id_usu = $1`,
        [idUsu]
    );
    assert.equal(fila.rows[0].ultima_importacion_steperfil, null);
});
