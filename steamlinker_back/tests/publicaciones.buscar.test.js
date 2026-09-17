// Cubre el filtro multi-tipo de GET /publicaciones/buscar, necesario para
// el conmutador Familia (busco_familia+busco_miembros) dentro de
// Publicaciones (ver HANDOFF.md).
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { app, pool, usernameUnico, limpiarUsuario } = require('./helpers');

let token;
let username;

before(async () => {
    username = usernameUnico('test_buscar');
    const res = await request(app).post('/auth/registro').send({
        username,
        email: `${username}@example.com`,
        password: 'Passw0rd123',
    });
    token = res.body.token;

    await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'busco_companero', titulo: 'Companero de prueba' });

    await request(app)
        .post('/publicaciones/crear')
        .set('Authorization', `Bearer ${token}`)
        .send({ tipo: 'otro', titulo: 'Comunidad de prueba' });
});

after(async () => {
    await limpiarUsuario(username);
    await pool.end();
});

test('filtro con un solo tipo devuelve solo ese tipo', async () => {
    const res = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    assert.equal(res.status, 200);
    assert.ok(res.body.publicaciones.every((p) => p.tipo_publi === 'otro'));
    assert.ok(res.body.publicaciones.some((p) => p.titulo_publi === 'Comunidad de prueba'));
});

test('filtro con varios tipos separados por coma devuelve la union', async () => {
    const res = await request(app)
        .get('/publicaciones/buscar')
        .query({ tipo: 'busco_companero,otro' });

    assert.equal(res.status, 200);
    const tipos = res.body.publicaciones.map((p) => p.tipo_publi);
    assert.ok(tipos.includes('busco_companero'));
    assert.ok(tipos.includes('otro'));
});

test('sin filtro de tipo no excluye nada por tipo', async () => {
    const res = await request(app).get('/publicaciones/buscar');
    assert.equal(res.status, 200);
    assert.ok(res.body.total >= 2);
});

test('cada publicacion trae cupos_ocupados', async () => {
    const res = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    assert.equal(res.status, 200);
    assert.ok(res.body.publicaciones.every((p) => typeof p.cupos_ocupados === 'number'));
});
