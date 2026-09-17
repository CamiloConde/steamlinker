// Cubre el enriquecimiento de GET /perfil/descubrir con juegos en comun,
// total de juegos y steam_vinculado, necesario para la tabla de personas de
// Descubrir (ver HANDOFF.md).
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let tokenYo, tokenOtro;
let yo, otro;

before(async () => {
    yo = usernameUnico('test_descubrir_yo');
    const resYo = await request(app).post('/auth/registro').send({
        username: yo,
        email: `${yo}@example.com`,
        password: 'Passw0rd123',
    });
    tokenYo = resYo.body.token;

    otro = usernameUnico('test_descubrir_otro');
    const resOtro = await request(app).post('/auth/registro').send({
        username: otro,
        email: `${otro}@example.com`,
        password: 'Passw0rd123',
    });
    tokenOtro = resOtro.body.token;

    // Un juego en comun entre ambos.
    for (const token of [tokenYo, tokenOtro]) {
        await request(app)
            .post('/perfil/juegos/agregar')
            .set('Authorization', `Bearer ${token}`)
            .send({ appid: 990990, nombre: 'Juego de prueba comun' });
    }

    // El otro usuario necesita una publicacion activa para aparecer en
    // /perfil/descubrir (solo lista gente con publicaciones abiertas).
    // Le asociamos el mismo juego para poder probar juego_reciente.
    await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${tokenOtro}`)
        .send({
            tipo: 'busco_companero',
            titulo: 'Publicacion de prueba descubrir',
            juegos: [{ appid: 990990, nombre: 'Juego de prueba comun' }],
        });
});

after(async () => {
    await limpiarUsuario(yo);
    await limpiarUsuario(otro);
    await pool.end();
});

test('descubrir incluye juegos_en_comun, total_juegos y steam_vinculado', async () => {
    const res = await request(app)
        .get('/perfil/descubrir')
        .set('Authorization', `Bearer ${tokenYo}`);

    assert.equal(res.status, 200);
    const fila = res.body.usuarios.find((u) => u.username_usu === otro);
    assert.ok(fila, 'el otro usuario debe aparecer en el listado');
    assert.equal(fila.juegos_en_comun, 1);
    assert.equal(fila.total_juegos, 1);
    assert.equal(fila.steam_vinculado, false);
    assert.equal(fila.tipo_publi_reciente, 'busco_companero');
    assert.equal(fila.juegos_comunes_muestra.length, 1);
    assert.equal(fila.juegos_comunes_muestra[0].appid, 990990);
    assert.equal(fila.juego_reciente.appid, 990990);
});
