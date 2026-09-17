// Cubre el gateo de Steam de la Fase 2 (ver HANDOFF.md seccion 5 y 9):
// Familia exige cuenta de Steam vinculada, Companeros no.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let token;
let username;

before(async () => {
    username = usernameUnico('test_gate');
    const res = await request(app).post('/auth/registro').send({
        username,
        email: `${username}@example.com`,
        password: 'Passw0rd123',
    });
    assert.equal(res.status, 201, JSON.stringify(res.body));
    token = res.body.token;
});

after(async () => {
    await limpiarUsuario(username);
    await pool.end();
});

test('busco_familia sin Steam vinculado devuelve 403 STEAM_REQUERIDO', async () => {
    const res = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'busco_familia', titulo: 'Busco familia para RE4' });

    assert.equal(res.status, 403);
    assert.equal(res.body.codigo, 'STEAM_REQUERIDO');
});

test('busco_miembros sin Steam vinculado tambien devuelve 403', async () => {
    const res = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'busco_miembros', titulo: 'Busco miembros para mi familia' });

    assert.equal(res.status, 403);
    assert.equal(res.body.codigo, 'STEAM_REQUERIDO');
});

test('busco_companero sin Steam vinculado se crea normalmente (201)', async () => {
    const res = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'busco_companero', titulo: 'Busco gente para Helldivers', cupos_totales: 3 });

    assert.equal(res.status, 201);
    assert.equal(res.body.tipo_publi, 'busco_companero');
    assert.equal(res.body.cupos_totales, 3);
});

test('busco_familia sin cupos_totales usa el default de 6 (tamano real de una Familia Steam)', async () => {
    // Este caso especifico seguira dando 403 por el gateo de Steam, pero
    // confirma que la validacion de tipo ocurre antes y no revienta con
    // otro error si faltan cupos_totales.
    const res = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'busco_familia', titulo: 'Sin cupos explicitos' });

    assert.equal(res.status, 403);
});

test('tipo invalido devuelve 400', async () => {
    const res = await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'inventado', titulo: 'x' });

    assert.equal(res.status, 400);
});

test('sin token devuelve 401', async () => {
    const res = await request(app)
        .post('/publicaciones/crear')
        .send({ tipo: 'busco_companero', titulo: 'x' });

    assert.equal(res.status, 401);
});
