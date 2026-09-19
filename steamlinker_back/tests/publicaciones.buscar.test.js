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

test('sin token, juegos_en_comun y su muestra vienen null (no hay con quien comparar)', async () => {
    const res = await request(app).get('/publicaciones/buscar').query({ tipo: 'otro' });
    assert.equal(res.status, 200);
    const publi = res.body.publicaciones.find((p) => p.titulo_publi === 'Comunidad de prueba');
    assert.equal(publi.juegos_en_comun, null);
    assert.equal(publi.juegos_comunes_muestra, null);
});

test('con token, juegos_en_comun solo cuenta biblioteca verificada del autor vs quien mira', async () => {
    const viewer = usernameUnico('test_buscar_viewer');
    const resViewer = await request(app).post('/auth/registro').send({
        username: viewer,
        email: `${viewer}@example.com`,
        password: 'Passw0rd123',
    });
    const tokenViewer = resViewer.body.token;

    // Juego agregado a mano por ambos -- no debe contar como en comun.
    for (const t of [token, tokenViewer]) {
        await request(app)
            .post('/perfil/juegos/agregar')
            .set('Authorization', `Bearer ${t}`)
            .send({ appid: 991100, nombre: 'Juego manual compartido' });
    }
    // Juego "verificado" (origen steam) por ambos -- este si debe contar.
    for (const t of [token, tokenViewer]) {
        await request(app)
            .post('/perfil/juegos/agregar')
            .set('Authorization', `Bearer ${t}`)
            .send({ appid: 991101, nombre: 'Juego verificado compartido' });
    }
    await pool.query(`UPDATE usuarios_juegos SET origen_usujg = 'steam' WHERE appid = 991101`);

    const res = await request(app)
        .get('/publicaciones/buscar')
        .query({ tipo: 'otro' })
        .set('Authorization', `Bearer ${tokenViewer}`);

    assert.equal(res.status, 200);
    const publi = res.body.publicaciones.find((p) => p.titulo_publi === 'Comunidad de prueba');
    assert.equal(publi.juegos_en_comun, 1);
    assert.equal(publi.juegos_comunes_muestra.length, 1);
    assert.equal(publi.juegos_comunes_muestra[0].appid, 991101);

    await limpiarUsuario(viewer);
});
